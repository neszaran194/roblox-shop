// backend/src/middleware/errorHandler.js
// Global error handling middleware

const logger = require('../utils/logger');

// Custom error class
class AppError extends Error {
    constructor(message, statusCode = 500, code = 'INTERNAL_ERROR') {
        super(message);
        this.statusCode = statusCode;
        this.code = code;
        this.isOperational = true;

        Error.captureStackTrace(this, this.constructor);
    }
}

// Database error handler
const handleDatabaseError = (error) => {
    logger.error('Database error:', {
        code: error.code,
        message: error.message,
        detail: error.detail,
        table: error.table,
        column: error.column,
        constraint: error.constraint
    });

    switch (error.code) {
        case '23505': // Unique violation
            if (error.constraint) {
                if (error.constraint.includes('username')) {
                    return new AppError('ชื่อผู้ใช้นี้ถูกใช้แล้ว', 400, 'USERNAME_EXISTS');
                }
                if (error.constraint.includes('email')) {
                    return new AppError('อีเมลนี้ถูกใช้แล้ว', 400, 'EMAIL_EXISTS');
                }
            }
            return new AppError('ข้อมูลซ้ำในระบบ', 400, 'DUPLICATE_DATA');

        case '23503': // Foreign key violation
            return new AppError('ข้อมูลที่อ้างอิงไม่ถูกต้อง', 400, 'INVALID_REFERENCE');

        case '23514': // Check violation
            return new AppError('ข้อมูลไม่ถูกต้องตามเงื่อนไข', 400, 'INVALID_DATA');

        case '42P01': // Table does not exist
            return new AppError('ตารางข้อมูลไม่พบ', 500, 'TABLE_NOT_FOUND');

        case '42703': // Column does not exist
            return new AppError('คอลัมน์ข้อมูลไม่พบ', 500, 'COLUMN_NOT_FOUND');

        case '08006': // Connection failure
        case '08001': // Connection unable to connect
            return new AppError('ไม่สามารถเชื่อมต่อฐานข้อมูลได้', 503, 'DATABASE_CONNECTION_ERROR');

        case '57P01': // Admin shutdown
        case '57P02': // Crash shutdown
        case '57P03': // Cannot connect now
            return new AppError('ฐานข้อมูลไม่พร้อมใช้งาน', 503, 'DATABASE_UNAVAILABLE');

        default:
            return new AppError('เกิดข้อผิดพลาดในฐานข้อมูล', 500, 'DATABASE_ERROR');
    }
};

// JWT error handler
const handleJWTError = (error) => {
    logger.warn('JWT error:', error.message);

    if (error.name === 'TokenExpiredError') {
        return new AppError('โทเค็นหมดอายุแล้ว กรุณาเข้าสู่ระบบใหม่', 401, 'TOKEN_EXPIRED');
    }

    if (error.name === 'JsonWebTokenError') {
        return new AppError('โทเค็นไม่ถูกต้อง', 401, 'INVALID_TOKEN');
    }

    if (error.name === 'NotBeforeError') {
        return new AppError('โทเค็นยังไม่สามารถใช้งานได้', 401, 'TOKEN_NOT_ACTIVE');
    }

    return new AppError('ปัญหาการยืนยันตัวตน', 401, 'AUTHENTICATION_ERROR');
};

// Validation error handler
const handleValidationError = (error) => {
    if (error.details && Array.isArray(error.details)) {
        // Joi validation error
        const messages = error.details.map(detail => detail.message);
        return new AppError(`ข้อมูลไม่ถูกต้อง: ${messages.join(', ')}`, 400, 'VALIDATION_ERROR');
    }

    return new AppError('ข้อมูลที่ส่งมาไม่ถูกต้อง', 400, 'VALIDATION_ERROR');
};

// Redis error handler
const handleRedisError = (error) => {
    logger.error('Redis error:', error);

    if (error.code === 'ECONNREFUSED') {
        return new AppError('ไม่สามารถเชื่อมต่อ Redis ได้', 503, 'REDIS_CONNECTION_ERROR');
    }

    return new AppError('เกิดข้อผิดพลาดในระบบแคช', 503, 'CACHE_ERROR');
};

// File upload error handler
const handleMulterError = (error) => {
    logger.warn('File upload error:', error);

    if (error.code === 'LIMIT_FILE_SIZE') {
        return new AppError('ไฟล์มีขนาดใหญ่เกินไป', 400, 'FILE_TOO_LARGE');
    }

    if (error.code === 'LIMIT_FILE_COUNT') {
        return new AppError('จำนวนไฟล์เกินจำนวนที่อนุญาต', 400, 'TOO_MANY_FILES');
    }

    if (error.code === 'LIMIT_UNEXPECTED_FILE') {
        return new AppError('ประเภทไฟล์ไม่ถูกต้อง', 400, 'INVALID_FILE_TYPE');
    }

    return new AppError('เกิดข้อผิดพลาดในการอัปโหลดไฟล์', 400, 'FILE_UPLOAD_ERROR');
};

// Send error response
const sendErrorResponse = (res, error, req) => {
    const { statusCode = 500, code = 'INTERNAL_ERROR', message } = error;

    // Log error details
    const errorLog = {
        code,
        message,
        statusCode,
        method: req?.method,
        url: req?.originalUrl,
        ip: req?.ip,
        userId: req?.user?.id,
        userAgent: req?.get('User-Agent'),
        stack: error.stack
    };

    if (statusCode >= 500) {
        logger.error('Server Error:', errorLog);
    } else {
        logger.warn('Client Error:', errorLog);
    }

    // Response format
    const response = {
        success: false,
        error: message,
        code,
        timestamp: new Date().toISOString()
    };

    // Add error details in development
    if (process.env.NODE_ENV === 'development') {
        response.stack = error.stack;
        response.details = error.details || null;
    }

    res.status(statusCode).json(response);
};

// Main error handling middleware
const errorHandler = (error, req, res, next) => {
    let handledError = error;

    // Handle known error types
    if (error.code && typeof error.code === 'string') {
        // Database errors (PostgreSQL error codes start with numbers)
        if (/^\d/.test(error.code)) {
            handledError = handleDatabaseError(error);
        }
        // Redis errors
        else if (error.code === 'ECONNREFUSED' || error.message.includes('Redis')) {
            handledError = handleRedisError(error);
        }
    }

    // JWT errors
    if (error.name && error.name.includes('Token')) {
        handledError = handleJWTError(error);
    }

    // Joi validation errors
    if (error.isJoi || (error.details && Array.isArray(error.details))) {
        handledError = handleValidationError(error);
    }

    // Multer errors
    if (error.code && error.code.startsWith('LIMIT_')) {
        handledError = handleMulterError(error);
    }

    // Ensure error is an AppError
    if (!handledError.isOperational) {
        handledError = new AppError(
            process.env.NODE_ENV === 'production' 
                ? 'เกิดข้อผิดพลาดภายในเซิร์ฟเวอร์' 
                : error.message,
            error.statusCode || 500,
            error.code || 'INTERNAL_ERROR'
        );
    }

    sendErrorResponse(res, handledError, req);
};

// 404 handler
const notFoundHandler = (req, res) => {
    const message = `ไม่พบ API endpoint: ${req.method} ${req.originalUrl}`;
    
    logger.warn('404 Not Found:', {
        method: req.method,
        url: req.originalUrl,
        ip: req.ip,
        userAgent: req.get('User-Agent')
    });

    res.status(404).json({
        success: false,
        error: message,
        code: 'NOT_FOUND',
        timestamp: new Date().toISOString()
    });
};

// Async error wrapper
const asyncHandler = (fn) => (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
};

// Error response helper
const createError = (message, statusCode = 500, code = 'INTERNAL_ERROR') => {
    return new AppError(message, statusCode, code);
};

module.exports = {
    AppError,
    errorHandler,
    notFoundHandler,
    asyncHandler,
    createError,
    handleDatabaseError,
    handleJWTError,
    handleValidationError
};