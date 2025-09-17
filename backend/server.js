// backend/server.js
// Main server entry point

require('dotenv').config();

const app = require('./src/app');
const { connectDatabase } = require('./src/config/database');
const { connectRedis } = require('./src/config/redis');
const logger = require('./src/utils/logger');

const PORT = process.env.PORT || 5000;

async function startServer() {
    try {
        // Connect to PostgreSQL
        logger.info('Connecting to PostgreSQL database...');
        await connectDatabase();
        logger.info('✅ PostgreSQL connected successfully');

        // Connect to Redis
        logger.info('Connecting to Redis...');
        await connectRedis();
        logger.info('✅ Redis connected successfully');

        // Start the server
        const server = app.listen(PORT, () => {
            logger.info(`🚀 Roblox Shop API Server running on port ${PORT}`);
            logger.info(`📖 Environment: ${process.env.NODE_ENV}`);
            logger.info(`🔗 Health check: http://localhost:${PORT}/health`);
            logger.info(`📋 API docs: http://localhost:${PORT}/api`);
        });

        // Handle server errors
        server.on('error', (error) => {
            if (error.code === 'EADDRINUSE') {
                logger.error(`❌ Port ${PORT} is already in use`);
            } else {
                logger.error('❌ Server error:', error);
            }
            process.exit(1);
        });

        // Graceful shutdown
        const gracefulShutdown = (signal) => {
            logger.info(`\n${signal} received. Starting graceful shutdown...`);
            
            server.close(async (error) => {
                if (error) {
                    logger.error('❌ Error during server close:', error);
                }
                
                try {
                    // Close database connections
                    const { pool } = require('./src/config/database');
                    await pool.end();
                    logger.info('✅ Database connection closed');

                    // Close Redis connection
                    const { redisClient } = require('./src/config/redis');
                    await redisClient.quit();
                    logger.info('✅ Redis connection closed');

                    logger.info('✅ Graceful shutdown completed');
                    process.exit(0);
                } catch (shutdownError) {
                    logger.error('❌ Error during shutdown:', shutdownError);
                    process.exit(1);
                }
            });

            // Force close after 10 seconds
            setTimeout(() => {
                logger.error('❌ Forced shutdown after timeout');
                process.exit(1);
            }, 10000);
        };

        // Listen for shutdown signals
        process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
        process.on('SIGINT', () => gracefulShutdown('SIGINT'));

    } catch (error) {
        logger.error('❌ Failed to start server:', error);
        process.exit(1);
    }
}

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
    logger.error('❌ Uncaught Exception:', error);
    process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
    logger.error('❌ Unhandled Promise Rejection:', reason);
    logger.error('Promise:', promise);
    process.exit(1);
});

// Start the server
startServer();