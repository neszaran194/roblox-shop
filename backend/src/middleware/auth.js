// backend/src/middleware/auth.js
// Authentication and authorization middleware

const jwt = require('jsonwebtoken');
const { query } = require('../config/database');
const { cache } = require('../config/redis');
const logger = require('../utils/logger');
const { createError } = require('./errorHandler');

// Extract token from request
const extractToken = (req) => {
    // Check Authorization header
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
        return authHeader.substring(7);
    }

    // Check cookies
    if (req.cookies && req.cookies.token) {
        return req.cookies.token;
    }

    // Check query parameter (for limited cases)
    if (req.query && req.query.token) {
        return req.query.token;
    }

    return null;
};

// Verify JWT token
const verifyToken = async (token) => {
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        return { success: true, decoded };
    } catch (error) {
        return { success: false, error };
    }
};

// Get user from database with caching
const getUserById = async (userId, userType = 'user') => {
    try {
        // Try cache first
        const cacheKey = `user:${userType}:${userId}`;
        let user = await cache.get(cacheKey);

        if (!user) {
            // Get from database
            const table = userType === 'admin' ? 'admin_users' : 'users';
            const result = await query(
                `SELECT id, username, email, role, is_active, 
                 ${userType === 'user' ? 'credits, ' : ''}
                 created_at, updated_at 
                 FROM ${table} WHERE id = $1 AND is_active = true`,
                [userId]
            );

            if (result.rows.length === 0) {
                return null;
            }

            user = result.rows[0];
            
            // Cache user data for 15 minutes
            await cache.set(cacheKey, user, 900);
        }

        return user;
    } catch (error) {
        logger.error(`Failed to get ${userType} by ID:`, error);
        return null;
    }
};

// Main authentication middleware
const authenticate = (options = {}) => {
    const { required = true, userType = 'user' } = options;

    return async (req, res, next) => {
        try {
            const token = extractToken(req);

            // If token is not provided
            if (!token) {
                if (required) {
                    return next(createError('กรุณาเข้าสู่ระบบ', 401, 'TOKEN_MISSING'));
                }
                return next();
            }

            // Verify token
            const { success, decoded, error } = await verifyToken(token);
            if (!success) {
                logger.warn('Token verification failed:', {
                    error: error.message,
                    ip: req.ip,
                    userAgent: req.get('User-Agent')
                });
                return next(createError('โทเค็นไม่ถูกต้อง', 401, 'INVALID_TOKEN'));
            }

            // Check if token type matches
            if (decoded.type !== userType) {
                return next(createError('ประเภทโทเค็นไม่ถูกต้อง', 401, 'INVALID_TOKEN_TYPE'));
            }

            // Get user data
            const user = await getUserById(decoded.userId, userType);
            if (!user) {
                logger.warn('User not found for valid token:', {
                    userId: decoded.userId,
                    type: userType
                });
                return next(createError('ไม่พบผู้ใช้', 401, 'USER_NOT_FOUND'));
            }

            // Check if user is still active
            if (!user.is_active) {
                return next(createError('บัญชีถูกปิดการใช้งาน', 401, 'ACCOUNT_DISABLED'));
            }

            // Add user to request object
            req.user = user;
            req.token = token;

            logger.logAuth('Token verified', user.id, {
                username: user.username,
                role: user.role,
                ip: req.ip
            });

            next();
        } catch (error) {
            logger.error('Authentication middleware error:', error);
            next(createError('เกิดข้อผิดพลาดในการยืนยันตัวตน', 500, 'AUTH_ERROR'));
        }
    };
};

// Authorization middleware for user roles
const authorize = (...roles) => {
    return (req, res, next) => {
        if (!req.user) {
            return next(createError('กรุณาเข้าสู่ระบบ', 401, 'AUTHENTICATION_REQUIRED'));
        }

        if (!roles.includes(req.user.role)) {
            logger.logSecurity('Unauthorized access attempt', {
                userId: req.user.id,
                userRole: req.user.role,
                requiredRoles: roles,
                endpoint: req.originalUrl,
                ip: req.ip
            });
            
            return next(createError('ไม่มีสิทธิ์เข้าถึง', 403, 'INSUFFICIENT_PERMISSIONS'));
        }

        next();
    };
};

// Check specific admin permissions
const checkPermission = (permission) => {
    return async (req, res, next) => {
        try {
            if (!req.user) {
                return next(createError('กรุณาเข้าสู่ระบบ', 401, 'AUTHENTICATION_REQUIRED'));
            }

            // Super admin has all permissions
            if (req.user.role === 'super_admin') {
                return next();
            }

            // Check permission in database
            const result = await query(
                'SELECT check_admin_permission($1, $2) as has_permission',
                [req.user.id, permission]
            );

            if (!result.rows[0].has_permission) {
                logger.logSecurity('Permission denied', {
                    userId: req.user.id,
                    username: req.user.username,
                    permission,
                    endpoint: req.originalUrl,
                    ip: req.ip
                });

                return next(createError('ไม่มีสิทธิ์ดำเนินการนี้', 403, 'PERMISSION_DENIED'));
            }

            next();
        } catch (error) {
            logger.error('Permission check error:', error);
            next(createError('เกิดข้อผิดพลาดในการตรวจสอบสิทธิ์', 500, 'PERMISSION_CHECK_ERROR'));
        }
    };
};

// Rate limiting middleware
const rateLimit = (options = {}) => {
    const { 
        max = 100, 
        windowMs = 15 * 60 * 1000, // 15 minutes
        message = 'คำขอเกินจำนวนที่อนุญาต กรุณาลองใหม่ภายหลัง',
        keyGenerator = (req) => req.ip 
    } = options;

    const { rateLimit: rateLimiter } = require('../config/redis');

    return async (req, res, next) => {
        try {
            const key = keyGenerator(req);
            const window = Math.floor(windowMs / 1000);
            
            const result = await rateLimiter.checkLimit(key, max, window);

            // Add rate limit headers
            res.set({
                'X-RateLimit-Limit': max,
                'X-RateLimit-Remaining': result.remaining,
                'X-RateLimit-Reset': new Date(result.resetTime).toISOString()
            });

            if (!result.allowed) {
                logger.warn('Rate limit exceeded:', {
                    key,
                    current: result.current,
                    limit: max,
                    ip: req.ip,
                    endpoint: req.originalUrl
                });

                return next(createError(message, 429, 'RATE_LIMIT_EXCEEDED'));
            }

            next();
        } catch (error) {
            logger.error('Rate limiting error:', error);
            // Continue without rate limiting if Redis fails
            next();
        }
    };
};

// Session-based authentication (for admin panel)
const authenticateSession = (req, res, next) => {
    if (req.session && req.session.userId) {
        // Add user data to request
        req.user = {
            id: req.session.userId,
            username: req.session.username,
            role: req.session.role,
            sessionId: req.sessionID
        };
        return next();
    }

    next(createError('กรุณาเข้าสู่ระบบ', 401, 'SESSION_REQUIRED'));
};

// Middleware to ensure user owns resource
const ensureOwnership = (resourceIdParam = 'id', userIdField = 'user_id') => {
    return async (req, res, next) => {
        try {
            if (!req.user) {
                return next(createError('กรุณาเข้าสู่ระบบ', 401, 'AUTHENTICATION_REQUIRED'));
            }

            // Admin can access all resources
            if (req.user.role === 'admin' || req.user.role === 'super_admin') {
                return next();
            }

            const resourceId = req.params[resourceIdParam];
            if (!resourceId) {
                return next(createError('ไม่พบรหัสทรัพยากร', 400, 'RESOURCE_ID_MISSING'));
            }

            // This is a generic check - specific implementations should override
            req.resourceId = resourceId;
            req.userIdField = userIdField;
            
            next();
        } catch (error) {
            logger.error('Ownership check error:', error);
            next(createError('เกิดข้อผิดพลาดในการตรวจสอบสิทธิ์', 500, 'OWNERSHIP_CHECK_ERROR'));
        }
    };
};

// Generate JWT token
const generateToken = (payload, options = {}) => {
    const { 
        expiresIn = process.env.JWT_EXPIRES_IN || '7d',
        type = 'user'
    } = options;

    return jwt.sign(
        { 
            ...payload, 
            type,
            iat: Math.floor(Date.now() / 1000)
        }, 
        process.env.JWT_SECRET, 
        { expiresIn }
    );
};

// Generate refresh token
const generateRefreshToken = (payload) => {
    return jwt.sign(
        { 
            ...payload, 
            type: 'refresh',
            iat: Math.floor(Date.now() / 1000)
        }, 
        process.env.JWT_SECRET, 
        { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d' }
    );
};

// Invalidate user cache
const invalidateUserCache = async (userId, userType = 'user') => {
    try {
        const cacheKey = `user:${userType}:${userId}`;
        await cache.del(cacheKey);
        logger.debug(`User cache invalidated: ${cacheKey}`);
    } catch (error) {
        logger.error('Failed to invalidate user cache:', error);
    }
};

// Middleware to log user activity
const logActivity = (action) => {
    return (req, res, next) => {
        // Log after response
        res.on('finish', () => {
            if (req.user && res.statusCode < 400) {
                logger.logAuth('User activity', req.user.id, {
                    action,
                    username: req.user.username,
                    endpoint: req.originalUrl,
                    method: req.method,
                    statusCode: res.statusCode,
                    ip: req.ip,
                    userAgent: req.get('User-Agent')
                });
            }
        });
        next();
    };
};

// Middleware for API key authentication (for webhooks)
const authenticateApiKey = (req, res, next) => {
    const apiKey = req.headers['x-api-key'] || req.query.api_key;
    
    if (!apiKey) {
        return next(createError('ไม่พบ API Key', 401, 'API_KEY_MISSING'));
    }

    // Check if API key is valid (you should store this in database/env)
    const validApiKeys = process.env.API_KEYS ? process.env.API_KEYS.split(',') : [];
    
    if (!validApiKeys.includes(apiKey)) {
        logger.logSecurity('Invalid API key attempt', {
            apiKey: apiKey.substring(0, 8) + '***',
            ip: req.ip,
            endpoint: req.originalUrl
        });
        
        return next(createError('API Key ไม่ถูกต้อง', 401, 'INVALID_API_KEY'));
    }

    next();
};

// Export middleware functions
module.exports = {
    authenticate,
    authorize,
    checkPermission,
    rateLimit,
    authenticateSession,
    ensureOwnership,
    generateToken,
    generateRefreshToken,
    invalidateUserCache,
    logActivity,
    authenticateApiKey,
    extractToken,
    verifyToken,
    getUserById
};