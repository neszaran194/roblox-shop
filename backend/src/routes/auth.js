// backend/src/routes/auth.js
// Authentication routes

const express = require('express');
const bcrypt = require('bcryptjs');
const { body, validationResult } = require('express-validator');
const rateLimit = require('express-rate-limit');
const { v4: uuidv4 } = require('uuid');

const { query, transaction } = require('../config/database');
const { cache } = require('../config/redis');
const logger = require('../utils/logger');
const { asyncHandler, createError } = require('../middleware/errorHandler');
const { 
    authenticate, 
    generateToken, 
    generateRefreshToken,
    invalidateUserCache,
    rateLimit: customRateLimit
} = require('../middleware/auth');

const router = express.Router();

// Rate limiting for auth endpoints
const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 5, // 5 attempts per window
    message: {
        success: false,
        error: 'การเข้าสู่ระบบเกินจำนวนที่อนุญาต กรุณาลองใหม่ภายหลัง',
        code: 'TOO_MANY_LOGIN_ATTEMPTS'
    },
    standardHeaders: true,
    legacyHeaders: false
});

const registerLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, // 1 hour  
    max: 3, // 3 registrations per hour per IP
    message: {
        success: false,
        error: 'การสมัครสมาชิกเกินจำนวนที่อนุญาต กรุณาลองใหม่ภายหลัง',
        code: 'TOO_MANY_REGISTRATIONS'
    }
});

// Validation rules
const registerValidation = [
    body('username')
        .isLength({ min: 3, max: 50 })
        .withMessage('ชื่อผู้ใช้ต้องมีความยาว 3-50 ตัวอักษร')
        .matches(/^[a-zA-Z0-9_]+$/)
        .withMessage('ชื่อผู้ใช้สามารถใช้ได้เฉพาะตัวอักษร ตัวเลข และ _'),
    
    body('email')
        .isEmail()
        .withMessage('รูปแบบอีเมลไม่ถูกต้อง')
        .normalizeEmail(),
    
    body('password')
        .isLength({ min: 6 })
        .withMessage('รหัสผ่านต้องมีความยาวอย่างน้อย 6 ตัวอักษร')
        .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
        .withMessage('รหัสผ่านต้องมีตัวอักษรพิมพ์เล็ก พิมพ์ใหญ่ และตัวเลข')
];

const loginValidation = [
    body('username')
        .notEmpty()
        .withMessage('กรุณากรอกชื่อผู้ใช้')
        .trim(),
    
    body('password')
        .notEmpty()
        .withMessage('กรุณากรอกรหัสผ่าน')
];

const changePasswordValidation = [
    body('currentPassword')
        .notEmpty()
        .withMessage('กรุณากรอกรหัสผ่านปัจจุบัน'),
    
    body('newPassword')
        .isLength({ min: 6 })
        .withMessage('รหัสผ่านใหม่ต้องมีความยาวอย่างน้อย 6 ตัวอักษร')
        .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
        .withMessage('รหัสผ่านใหม่ต้องมีตัวอักษรพิมพ์เล็ก พิมพ์ใหญ่ และตัวเลข')
];

// Helper function to check validation errors
const checkValidation = (req) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        const errorMessages = errors.array().map(error => error.msg);
        throw createError(errorMessages.join(', '), 400, 'VALIDATION_ERROR');
    }
};

// POST /api/auth/register - User registration
router.post('/register', registerLimiter, registerValidation, asyncHandler(async (req, res) => {
    checkValidation(req);
    
    const { username, email, password } = req.body;

    await transaction(async (client) => {
        // Check if username or email already exists
        const existingUser = await client.query(
            'SELECT id FROM users WHERE username = $1 OR email = $2',
            [username.toLowerCase(), email.toLowerCase()]
        );

        if (existingUser.rows.length > 0) {
            throw createError('ชื่อผู้ใช้หรืออีเมลนี้ถูกใช้แล้ว', 400, 'USER_EXISTS');
        }

        // Hash password
        const saltRounds = parseInt(process.env.BCRYPT_ROUNDS) || 12;
        const passwordHash = await bcrypt.hash(password, saltRounds);

        // Create user
        const result = await client.query(
            `INSERT INTO users (username, email, password_hash, role, is_active) 
             VALUES ($1, $2, $3, 'user', true) 
             RETURNING id, username, email, credits, created_at`,
            [username.toLowerCase(), email.toLowerCase(), passwordHash]
        );

        const user = result.rows[0];

        // Generate tokens
        const token = generateToken({ userId: user.id }, { type: 'user' });
        const refreshToken = generateRefreshToken({ userId: user.id });

        logger.logAuth('User registered', user.id, {
            username: user.username,
            email: user.email,
            ip: req.ip
        });

        res.status(201).json({
            success: true,
            message: 'สมัครสมาชิกสำเร็จ',
            data: {
                user: {
                    id: user.id,
                    username: user.username,
                    email: user.email,
                    credits: user.credits,
                    createdAt: user.created_at
                },
                token,
                refreshToken
            }
        });
    });
}));

// POST /api/auth/login - User login
router.post('/login', authLimiter, loginValidation, asyncHandler(async (req, res) => {
    checkValidation(req);
    
    const { username, password } = req.body;

    // Get user from database
    const result = await query(
        `SELECT id, username, email, password_hash, role, is_active, credits, last_login
         FROM users WHERE username = $1`,
        [username.toLowerCase()]
    );

    if (result.rows.length === 0) {
        throw createError('ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง', 401, 'INVALID_CREDENTIALS');
    }

    const user = result.rows[0];

    // Check if user is active
    if (!user.is_active) {
        throw createError('บัญชีถูกปิดการใช้งาน', 401, 'ACCOUNT_DISABLED');
    }

    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password_hash);
    if (!isValidPassword) {
        throw createError('ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง', 401, 'INVALID_CREDENTIALS');
    }

    // Update last login
    await query(
        'UPDATE users SET last_login = NOW() WHERE id = $1',
        [user.id]
    );

    // Generate tokens
    const token = generateToken({ userId: user.id }, { type: 'user' });
    const refreshToken = generateRefreshToken({ userId: user.id });

    // Store refresh token in Redis
    await cache.set(`refresh_token:${user.id}`, refreshToken, 30 * 24 * 60 * 60); // 30 days

    logger.logAuth('User login', user.id, {
        username: user.username,
        ip: req.ip,
        userAgent: req.get('User-Agent')
    });

    res.json({
        success: true,
        message: 'เข้าสู่ระบบสำเร็จ',
        data: {
            user: {
                id: user.id,
                username: user.username,
                email: user.email,
                role: user.role,
                credits: user.credits,
                lastLogin: user.last_login
            },
            token,
            refreshToken
        }
    });
}));

// POST /api/auth/logout - User logout
router.post('/logout', authenticate({ required: true }), asyncHandler(async (req, res) => {
    // Invalidate user cache
    await invalidateUserCache(req.user.id);

    // Remove refresh token
    await cache.del(`refresh_token:${req.user.id}`);

    logger.logAuth('User logout', req.user.id, {
        username: req.user.username,
        ip: req.ip
    });

    res.json({
        success: true,
        message: 'ออกจากระบบสำเร็จ'
    });
}));

// POST /api/auth/refresh - Refresh access token
router.post('/refresh', asyncHandler(async (req, res) => {
    const { refreshToken } = req.body;

    if (!refreshToken) {
        throw createError('กรุณาส่ง refresh token', 400, 'REFRESH_TOKEN_REQUIRED');
    }

    try {
        const decoded = jwt.verify(refreshToken, process.env.JWT_SECRET);
        
        if (decoded.type !== 'refresh') {
            throw createError('Refresh token ไม่ถูกต้อง', 401, 'INVALID_REFRESH_TOKEN');
        }

        // Check if refresh token exists in Redis
        const storedToken = await cache.get(`refresh_token:${decoded.userId}`);
        if (!storedToken || storedToken !== refreshToken) {
            throw createError('Refresh token ไม่ถูกต้องหรือหมดอายุ', 401, 'INVALID_REFRESH_TOKEN');
        }

        // Get user data
        const result = await query(
            'SELECT id, username, email, role, is_active FROM users WHERE id = $1',
            [decoded.userId]
        );

        if (result.rows.length === 0 || !result.rows[0].is_active) {
            throw createError('ผู้ใช้ไม่พบหรือถูกปิดการใช้งาน', 401, 'USER_NOT_FOUND');
        }

        const user = result.rows[0];

        // Generate new tokens
        const newToken = generateToken({ userId: user.id }, { type: 'user' });
        const newRefreshToken = generateRefreshToken({ userId: user.id });

        // Update refresh token in Redis
        await cache.set(`refresh_token:${user.id}`, newRefreshToken, 30 * 24 * 60 * 60);

        logger.logAuth('Token refreshed', user.id, {
            username: user.username,
            ip: req.ip
        });

        res.json({
            success: true,
            message: 'รีเฟรชโทเค็นสำเร็จ',
            data: {
                token: newToken,
                refreshToken: newRefreshToken
            }
        });

    } catch (error) {
        if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
            throw createError('Refresh token ไม่ถูกต้องหรือหมดอายุ', 401, 'INVALID_REFRESH_TOKEN');
        }
        throw error;
    }
}));

// GET /api/auth/profile - Get user profile
router.get('/profile', authenticate({ required: true }), asyncHandler(async (req, res) => {
    res.json({
        success: true,
        data: {
            user: {
                id: req.user.id,
                username: req.user.username,
                email: req.user.email,
                role: req.user.role,
                credits: req.user.credits,
                createdAt: req.user.created_at,
                updatedAt: req.user.updated_at
            }
        }
    });
}));

// PUT /api/auth/profile - Update user profile
router.put('/profile', authenticate({ required: true }), [
    body('email').optional().isEmail().withMessage('รูปแบบอีเมลไม่ถูกต้อง').normalizeEmail()
], asyncHandler(async (req, res) => {
    checkValidation(req);
    
    const { email } = req.body;
    const updates = {};
    const values = [];
    let paramIndex = 1;

    if (email && email !== req.user.email) {
        // Check if email is already used
        const existingUser = await query(
            'SELECT id FROM users WHERE email = $1 AND id != $2',
            [email, req.user.id]
        );

        if (existingUser.rows.length > 0) {
            throw createError('อีเมลนี้ถูกใช้แล้ว', 400, 'EMAIL_EXISTS');
        }

        updates.email = `$${paramIndex++}`;
        values.push(email);
    }

    if (Object.keys(updates).length === 0) {
        throw createError('ไม่มีข้อมูลที่จะอัปเดต', 400, 'NO_DATA_TO_UPDATE');
    }

    // Add updated_at
    updates.updated_at = 'NOW()';

    const setClause = Object.entries(updates)
        .map(([key, value]) => `${key} = ${value}`)
        .join(', ');

    values.push(req.user.id);

    const result = await query(
        `UPDATE users SET ${setClause} WHERE id = $${paramIndex} 
         RETURNING id, username, email, credits, updated_at`,
        values
    );

    const updatedUser = result.rows[0];

    // Invalidate user cache
    await invalidateUserCache(req.user.id);

    logger.logAuth('Profile updated', req.user.id, {
        username: req.user.username,
        changes: Object.keys(updates),
        ip: req.ip
    });

    res.json({
        success: true,
        message: 'อัปเดตโปรไฟล์สำเร็จ',
        data: {
            user: updatedUser
        }
    });
}));

// POST /api/auth/change-password - Change password
router.post('/change-password', authenticate({ required: true }), changePasswordValidation, asyncHandler(async (req, res) => {
    checkValidation(req);
    
    const { currentPassword, newPassword } = req.body;

    // Get current password hash
    const result = await query(
        'SELECT password_hash FROM users WHERE id = $1',
        [req.user.id]
    );

    const user = result.rows[0];

    // Verify current password
    const isValidPassword = await bcrypt.compare(currentPassword, user.password_hash);
    if (!isValidPassword) {
        throw createError('รหัสผ่านปัจจุบันไม่ถูกต้อง', 400, 'INVALID_CURRENT_PASSWORD');
    }

    // Check if new password is different
    const isSamePassword = await bcrypt.compare(newPassword, user.password_hash);
    if (isSamePassword) {
        throw createError('รหัสผ่านใหม่ต้องแตกต่างจากรหัสผ่านปัจจุบัน', 400, 'SAME_PASSWORD');
    }

    // Hash new password
    const saltRounds = parseInt(process.env.BCRYPT_ROUNDS) || 12;
    const newPasswordHash = await bcrypt.hash(newPassword, saltRounds);

    // Update password
    await query(
        'UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2',
        [newPasswordHash, req.user.id]
    );

    // Invalidate all user sessions
    await cache.del(`refresh_token:${req.user.id}`);
    await invalidateUserCache(req.user.id);

    logger.logAuth('Password changed', req.user.id, {
        username: req.user.username,
        ip: req.ip
    });

    res.json({
        success: true,
        message: 'เปลี่ยนรหัสผ่านสำเร็จ กรุณาเข้าสู่ระบบใหม่'
    });
}));

// GET /api/auth/verify - Verify token
router.get('/verify', authenticate({ required: true }), asyncHandler(async (req, res) => {
    res.json({
        success: true,
        message: 'โทเค็นถูกต้อง',
        data: {
            user: {
                id: req.user.id,
                username: req.user.username,
                role: req.user.role
            }
        }
    });
}));

module.exports = router;