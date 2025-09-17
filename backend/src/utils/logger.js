// backend/src/utils/logger.js
// Winston logger configuration

const winston = require('winston');
const path = require('path');
const fs = require('fs');

// Ensure logs directory exists
const logsDir = path.join(__dirname, '../../logs');
if (!fs.existsSync(logsDir)) {
    fs.mkdirSync(logsDir, { recursive: true });
}

// Custom log format
const logFormat = winston.format.combine(
    winston.format.timestamp({
        format: 'YYYY-MM-DD HH:mm:ss'
    }),
    winston.format.errors({ stack: true }),
    winston.format.json(),
    winston.format.prettyPrint()
);

// Console format for development
const consoleFormat = winston.format.combine(
    winston.format.colorize(),
    winston.format.timestamp({
        format: 'HH:mm:ss'
    }),
    winston.format.printf(({ timestamp, level, message, ...meta }) => {
        let log = `${timestamp} [${level}] ${message}`;
        
        // Add metadata if present
        if (Object.keys(meta).length > 0) {
            log += ` ${JSON.stringify(meta, null, 2)}`;
        }
        
        return log;
    })
);

// Create logger instance
const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: logFormat,
    defaultMeta: {
        service: 'roblox-shop-api',
        environment: process.env.NODE_ENV || 'development'
    },
    transports: [
        // Error log file
        new winston.transports.File({
            filename: path.join(logsDir, 'error.log'),
            level: 'error',
            maxsize: 50 * 1024 * 1024, // 50MB
            maxFiles: 5,
            tailable: true
        }),
        
        // Combined log file
        new winston.transports.File({
            filename: path.join(logsDir, 'combined.log'),
            maxsize: 50 * 1024 * 1024, // 50MB
            maxFiles: 10,
            tailable: true
        }),
        
        // Daily rotating log file
        new winston.transports.File({
            filename: path.join(logsDir, `app-${new Date().toISOString().split('T')[0]}.log`),
            maxsize: 100 * 1024 * 1024, // 100MB
            maxFiles: 30
        })
    ],
    
    // Handle uncaught exceptions
    exceptionHandlers: [
        new winston.transports.File({
            filename: path.join(logsDir, 'exceptions.log')
        })
    ],
    
    // Handle unhandled rejections
    rejectionHandlers: [
        new winston.transports.File({
            filename: path.join(logsDir, 'rejections.log')
        })
    ]
});

// Add console transport for development
if (process.env.NODE_ENV !== 'production') {
    logger.add(new winston.transports.Console({
        format: consoleFormat
    }));
}

// Helper functions for structured logging
const helpers = {
    // Log API requests
    logRequest: (req, res, responseTime) => {
        const logData = {
            method: req.method,
            url: req.originalUrl || req.url,
            ip: req.ip || req.connection.remoteAddress,
            userAgent: req.get('User-Agent'),
            statusCode: res.statusCode,
            responseTime: `${responseTime}ms`,
            userId: req.user?.id || null,
            sessionId: req.sessionID || null
        };

        if (res.statusCode >= 400) {
            logger.warn('API Request Error', logData);
        } else {
            logger.info('API Request', logData);
        }
    },

    // Log authentication events
    logAuth: (event, userId, details = {}) => {
        logger.info(`Auth: ${event}`, {
            event,
            userId,
            timestamp: new Date().toISOString(),
            ...details
        });
    },

    // Log database operations
    logDatabase: (operation, table, details = {}) => {
        logger.debug(`Database: ${operation}`, {
            operation,
            table,
            ...details
        });
    },

    // Log payment transactions
    logPayment: (event, userId, amount, details = {}) => {
        logger.info(`Payment: ${event}`, {
            event,
            userId,
            amount,
            currency: 'THB',
            timestamp: new Date().toISOString(),
            ...details
        });
    },

    // Log security events
    logSecurity: (event, details = {}) => {
        logger.warn(`Security: ${event}`, {
            event,
            severity: 'HIGH',
            timestamp: new Date().toISOString(),
            ...details
        });
    },

    // Log system events
    logSystem: (event, details = {}) => {
        logger.info(`System: ${event}`, {
            event,
            timestamp: new Date().toISOString(),
            ...details
        });
    },

    // Log performance metrics
    logPerformance: (operation, duration, details = {}) => {
        const level = duration > 5000 ? 'warn' : duration > 1000 ? 'info' : 'debug';
        
        logger[level](`Performance: ${operation}`, {
            operation,
            duration: `${duration}ms`,
            slow: duration > 1000,
            ...details
        });
    },

    // Log business events
    logBusiness: (event, details = {}) => {
        logger.info(`Business: ${event}`, {
            event,
            timestamp: new Date().toISOString(),
            ...details
        });
    }
};

// Add helper functions to logger
Object.assign(logger, helpers);

// Log cleanup function
const cleanupLogs = () => {
    const maxAge = 30 * 24 * 60 * 60 * 1000; // 30 days
    const now = Date.now();

    try {
        const files = fs.readdirSync(logsDir);
        
        files.forEach(file => {
            const filePath = path.join(logsDir, file);
            const stats = fs.statSync(filePath);
            
            if (now - stats.mtime.getTime() > maxAge) {
                fs.unlinkSync(filePath);
                logger.info(`Cleaned up old log file: ${file}`);
            }
        });
    } catch (error) {
        logger.error('Failed to cleanup old logs:', error);
    }
};

// Cleanup logs on startup (in production)
if (process.env.NODE_ENV === 'production') {
    cleanupLogs();
    
    // Schedule log cleanup every 24 hours
    setInterval(cleanupLogs, 24 * 60 * 60 * 1000);
}

// Export logger with custom methods
module.exports = logger;