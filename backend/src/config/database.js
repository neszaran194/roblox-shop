// backend/src/config/database.js
// PostgreSQL database configuration and connection

const { Pool } = require('pg');
const logger = require('../utils/logger');

// Database configuration
const dbConfig = {
    user: process.env.POSTGRES_USER || 'roblox_user',
    host: process.env.POSTGRES_HOST || 'localhost',
    database: process.env.POSTGRES_DB || 'roblox_shop',
    password: process.env.POSTGRES_PASSWORD || 'secure_password',
    port: parseInt(process.env.POSTGRES_PORT) || 5432,
    max: 20, // Maximum number of connections
    idleTimeoutMillis: 30000, // Close idle connections after 30 seconds
    connectionTimeoutMillis: 10000, // Return error after 10 seconds if connection could not be established
    statement_timeout: 30000, // Timeout queries after 30 seconds
    query_timeout: 30000,
    application_name: 'roblox-shop-api'
};

// Create connection pool
const pool = new Pool(dbConfig);

// Handle pool events
pool.on('connect', (client) => {
    logger.debug(`New database connection established (PID: ${client.processID})`);
});

pool.on('acquire', (client) => {
    logger.debug(`Database connection acquired (PID: ${client.processID})`);
});

pool.on('error', (error, client) => {
    logger.error('Database pool error:', error);
    if (client) {
        logger.error(`Client PID: ${client.processID}`);
    }
});

pool.on('remove', (client) => {
    logger.debug(`Database connection removed (PID: ${client.processID})`);
});

// Connect to database
async function connectDatabase() {
    try {
        const client = await pool.connect();
        const result = await client.query('SELECT version(), current_database(), current_user');
        client.release();

        logger.info('Database connection details:', {
            version: result.rows[0].version.split(' ')[0] + ' ' + result.rows[0].version.split(' ')[1],
            database: result.rows[0].current_database,
            user: result.rows[0].current_user,
            host: dbConfig.host,
            port: dbConfig.port
        });

        return pool;
    } catch (error) {
        logger.error('Failed to connect to database:', error);
        throw error;
    }
}

// Test database connection
async function testConnection() {
    try {
        const start = Date.now();
        const result = await pool.query('SELECT NOW() as current_time, 1 as test');
        const duration = Date.now() - start;

        return {
            success: true,
            duration: `${duration}ms`,
            timestamp: result.rows[0].current_time,
            test: result.rows[0].test
        };
    } catch (error) {
        logger.error('Database connection test failed:', error);
        return {
            success: false,
            error: error.message
        };
    }
}

// Execute query with error handling and logging
async function query(text, params = [], options = {}) {
    const start = Date.now();
    const client = options.client || pool;
    
    try {
        logger.debug('Executing query:', {
            sql: text.substring(0, 100) + (text.length > 100 ? '...' : ''),
            params: params.length > 0 ? '[PARAMS]' : 'none'
        });

        const result = await client.query(text, params);
        const duration = Date.now() - start;

        logger.debug('Query completed:', {
            duration: `${duration}ms`,
            rows: result.rows?.length || 0
        });

        return result;
    } catch (error) {
        const duration = Date.now() - start;
        logger.error('Query failed:', {
            error: error.message,
            duration: `${duration}ms`,
            sql: text.substring(0, 200),
            code: error.code
        });
        throw error;
    }
}

// Execute transaction
async function transaction(callback) {
    const client = await pool.connect();
    
    try {
        await client.query('BEGIN');
        logger.debug('Transaction started');

        const result = await callback(client);

        await client.query('COMMIT');
        logger.debug('Transaction committed');

        return result;
    } catch (error) {
        await client.query('ROLLBACK');
        logger.error('Transaction rolled back:', error.message);
        throw error;
    } finally {
        client.release();
    }
}

// Get database statistics
async function getStats() {
    try {
        const stats = await query(`
            SELECT 
                (SELECT count(*) FROM users WHERE role = 'user') as total_users,
                (SELECT count(*) FROM products WHERE is_active = true) as active_products,
                (SELECT count(*) FROM orders) as total_orders,
                (SELECT count(*) FROM orders WHERE status = 'pending') as pending_orders,
                (SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE status = 'completed') as total_revenue
        `);

        return stats.rows[0];
    } catch (error) {
        logger.error('Failed to get database stats:', error);
        throw error;
    }
}

// Check database health
async function healthCheck() {
    try {
        const connectionTest = await testConnection();
        if (!connectionTest.success) {
            return { healthy: false, error: connectionTest.error };
        }

        // Check if essential tables exist
        const tableCheck = await query(`
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name IN ('users', 'products', 'orders')
        `);

        const expectedTables = ['users', 'products', 'orders'];
        const existingTables = tableCheck.rows.map(row => row.table_name);
        const missingTables = expectedTables.filter(table => !existingTables.includes(table));

        if (missingTables.length > 0) {
            return {
                healthy: false,
                error: `Missing tables: ${missingTables.join(', ')}`
            };
        }

        return {
            healthy: true,
            connectionTime: connectionTest.duration,
            timestamp: connectionTest.timestamp,
            tables: existingTables.length
        };
    } catch (error) {
        return {
            healthy: false,
            error: error.message
        };
    }
}

// Clean up expired data
async function cleanupExpiredData() {
    try {
        const result = await query('SELECT cleanup_all_expired_data() as result');
        logger.info('Cleanup completed:', result.rows[0].result);
        return result.rows[0].result;
    } catch (error) {
        logger.error('Cleanup failed:', error);
        throw error;
    }
}

module.exports = {
    pool,
    connectDatabase,
    testConnection,
    query,
    transaction,
    getStats,
    healthCheck,
    cleanupExpiredData
};