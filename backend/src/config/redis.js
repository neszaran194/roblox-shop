// backend/src/config/redis.js
// Redis configuration and connection

const { createClient } = require('redis');
const logger = require('../utils/logger');

// Redis configuration
const redisConfig = {
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT) || 6379,
    password: process.env.REDIS_PASSWORD || undefined,
    db: 0,
    retryDelayOnFailover: 100,
    maxRetriesPerRequest: 3,
    lazyConnect: true,
    connectTimeout: 10000,
    commandTimeout: 5000
};

// Create Redis client
const redisClient = createClient({
    socket: {
        host: redisConfig.host,
        port: redisConfig.port,
        connectTimeout: redisConfig.connectTimeout,
        commandTimeout: redisConfig.commandTimeout,
        reconnectStrategy: (retries) => {
            if (retries > 10) {
                logger.error('Redis: Too many reconnection attempts, giving up');
                return false;
            }
            const delay = Math.min(retries * 50, 2000);
            logger.warn(`Redis: Reconnecting in ${delay}ms (attempt ${retries})`);
            return delay;
        }
    },
    password: redisConfig.password,
    database: redisConfig.db
});

// Redis event handlers
redisClient.on('connect', () => {
    logger.info('Redis: Connecting...');
});

redisClient.on('ready', () => {
    logger.info('Redis: Connected and ready');
});

redisClient.on('error', (error) => {
    logger.error('Redis error:', error);
});

redisClient.on('end', () => {
    logger.warn('Redis: Connection closed');
});

redisClient.on('reconnecting', () => {
    logger.warn('Redis: Reconnecting...');
});

// Connect to Redis
async function connectRedis() {
    try {
        await redisClient.connect();
        
        // Test connection
        const pong = await redisClient.ping();
        if (pong === 'PONG') {
            logger.info('Redis connection details:', {
                host: redisConfig.host,
                port: redisConfig.port,
                database: redisConfig.db
            });
        }
        
        return redisClient;
    } catch (error) {
        logger.error('Failed to connect to Redis:', error);
        throw error;
    }
}

// Cache helper functions
class Cache {
    constructor(prefix = 'roblox-shop:') {
        this.prefix = prefix;
        this.defaultTTL = 3600; // 1 hour
    }

    // Generate cache key with prefix
    key(suffix) {
        return `${this.prefix}${suffix}`;
    }

    // Set cache with TTL
    async set(key, value, ttl = this.defaultTTL) {
        try {
            const serialized = typeof value === 'object' ? JSON.stringify(value) : value;
            await redisClient.setEx(this.key(key), ttl, serialized);
            logger.debug(`Cache SET: ${key} (TTL: ${ttl}s)`);
            return true;
        } catch (error) {
            logger.error(`Cache SET error for ${key}:`, error);
            return false;
        }
    }

    // Get from cache
    async get(key) {
        try {
            const value = await redisClient.get(this.key(key));
            if (value === null) {
                logger.debug(`Cache MISS: ${key}`);
                return null;
            }

            // Try to parse JSON, fallback to string
            try {
                const parsed = JSON.parse(value);
                logger.debug(`Cache HIT: ${key}`);
                return parsed;
            } catch {
                logger.debug(`Cache HIT (string): ${key}`);
                return value;
            }
        } catch (error) {
            logger.error(`Cache GET error for ${key}:`, error);
            return null;
        }
    }

    // Delete from cache
    async del(key) {
        try {
            const result = await redisClient.del(this.key(key));
            logger.debug(`Cache DEL: ${key} (deleted: ${result})`);
            return result > 0;
        } catch (error) {
            logger.error(`Cache DEL error for ${key}:`, error);
            return false;
        }
    }

    // Delete multiple keys by pattern
    async delPattern(pattern) {
        try {
            const keys = await redisClient.keys(this.key(pattern));
            if (keys.length > 0) {
                const result = await redisClient.del(keys);
                logger.debug(`Cache DEL pattern ${pattern}: ${result} keys deleted`);
                return result;
            }
            return 0;
        } catch (error) {
            logger.error(`Cache DEL pattern error for ${pattern}:`, error);
            return 0;
        }
    }

    // Check if key exists
    async exists(key) {
        try {
            const result = await redisClient.exists(this.key(key));
            return result === 1;
        } catch (error) {
            logger.error(`Cache EXISTS error for ${key}:`, error);
            return false;
        }
    }

    // Set TTL for existing key
    async expire(key, ttl) {
        try {
            const result = await redisClient.expire(this.key(key), ttl);
            logger.debug(`Cache EXPIRE: ${key} (TTL: ${ttl}s)`);
            return result === 1;
        } catch (error) {
            logger.error(`Cache EXPIRE error for ${key}:`, error);
            return false;
        }
    }

    // Increment counter
    async incr(key, ttl = this.defaultTTL) {
        try {
            const result = await redisClient.incr(this.key(key));
            if (result === 1) {
                // Set TTL only on first increment
                await redisClient.expire(this.key(key), ttl);
            }
            logger.debug(`Cache INCR: ${key} = ${result}`);
            return result;
        } catch (error) {
            logger.error(`Cache INCR error for ${key}:`, error);
            return 0;
        }
    }

    // Hash operations
    async hset(key, field, value, ttl = this.defaultTTL) {
        try {
            const serialized = typeof value === 'object' ? JSON.stringify(value) : value;
            const result = await redisClient.hSet(this.key(key), field, serialized);
            if (result === 1) {
                // Set TTL only on new hash
                await redisClient.expire(this.key(key), ttl);
            }
            logger.debug(`Cache HSET: ${key}.${field}`);
            return result;
        } catch (error) {
            logger.error(`Cache HSET error for ${key}.${field}:`, error);
            return 0;
        }
    }

    async hget(key, field) {
        try {
            const value = await redisClient.hGet(this.key(key), field);
            if (value === null) {
                return null;
            }

            try {
                return JSON.parse(value);
            } catch {
                return value;
            }
        } catch (error) {
            logger.error(`Cache HGET error for ${key}.${field}:`, error);
            return null;
        }
    }

    async hgetall(key) {
        try {
            const hash = await redisClient.hGetAll(this.key(key));
            const result = {};
            
            for (const [field, value] of Object.entries(hash)) {
                try {
                    result[field] = JSON.parse(value);
                } catch {
                    result[field] = value;
                }
            }
            
            return result;
        } catch (error) {
            logger.error(`Cache HGETALL error for ${key}:`, error);
            return {};
        }
    }

    // List operations
    async lpush(key, value, ttl = this.defaultTTL) {
        try {
            const serialized = typeof value === 'object' ? JSON.stringify(value) : value;
            const result = await redisClient.lPush(this.key(key), serialized);
            if (result === 1) {
                await redisClient.expire(this.key(key), ttl);
            }
            return result;
        } catch (error) {
            logger.error(`Cache LPUSH error for ${key}:`, error);
            return 0;
        }
    }

    async rpush(key, value, ttl = this.defaultTTL) {
        try {
            const serialized = typeof value === 'object' ? JSON.stringify(value) : value;
            const result = await redisClient.rPush(this.key(key), serialized);
            if (result === 1) {
                await redisClient.expire(this.key(key), ttl);
            }
            return result;
        } catch (error) {
            logger.error(`Cache RPUSH error for ${key}:`, error);
            return 0;
        }
    }

    async lrange(key, start = 0, stop = -1) {
        try {
            const values = await redisClient.lRange(this.key(key), start, stop);
            return values.map(value => {
                try {
                    return JSON.parse(value);
                } catch {
                    return value;
                }
            });
        } catch (error) {
            logger.error(`Cache LRANGE error for ${key}:`, error);
            return [];
        }
    }

    // Set operations
    async sadd(key, value, ttl = this.defaultTTL) {
        try {
            const serialized = typeof value === 'object' ? JSON.stringify(value) : value;
            const result = await redisClient.sAdd(this.key(key), serialized);
            if (result === 1) {
                await redisClient.expire(this.key(key), ttl);
            }
            return result;
        } catch (error) {
            logger.error(`Cache SADD error for ${key}:`, error);
            return 0;
        }
    }

    async smembers(key) {
        try {
            const values = await redisClient.sMembers(this.key(key));
            return values.map(value => {
                try {
                    return JSON.parse(value);
                } catch {
                    return value;
                }
            });
        } catch (error) {
            logger.error(`Cache SMEMBERS error for ${key}:`, error);
            return [];
        }
    }
}

// Session helper functions
class SessionManager {
    constructor() {
        this.cache = new Cache('session:');
        this.defaultTTL = 86400; // 24 hours
    }

    async createSession(userId, sessionData = {}) {
        try {
            const sessionId = require('uuid').v4();
            const sessionInfo = {
                userId,
                createdAt: new Date().toISOString(),
                lastActivity: new Date().toISOString(),
                ...sessionData
            };

            await this.cache.set(sessionId, sessionInfo, this.defaultTTL);
            logger.debug(`Session created for user ${userId}: ${sessionId}`);
            
            return sessionId;
        } catch (error) {
            logger.error('Failed to create session:', error);
            return null;
        }
    }

    async getSession(sessionId) {
        try {
            const session = await this.cache.get(sessionId);
            if (session) {
                // Update last activity
                session.lastActivity = new Date().toISOString();
                await this.cache.set(sessionId, session, this.defaultTTL);
            }
            return session;
        } catch (error) {
            logger.error(`Failed to get session ${sessionId}:`, error);
            return null;
        }
    }

    async updateSession(sessionId, data) {
        try {
            const session = await this.cache.get(sessionId);
            if (!session) {
                return false;
            }

            const updatedSession = {
                ...session,
                ...data,
                lastActivity: new Date().toISOString()
            };

            await this.cache.set(sessionId, updatedSession, this.defaultTTL);
            return true;
        } catch (error) {
            logger.error(`Failed to update session ${sessionId}:`, error);
            return false;
        }
    }

    async destroySession(sessionId) {
        try {
            const result = await this.cache.del(sessionId);
            logger.debug(`Session destroyed: ${sessionId}`);
            return result;
        } catch (error) {
            logger.error(`Failed to destroy session ${sessionId}:`, error);
            return false;
        }
    }

    async destroyUserSessions(userId) {
        try {
            const pattern = '*';
            const keys = await redisClient.keys(this.cache.key(pattern));
            let deletedCount = 0;

            for (const key of keys) {
                const session = await redisClient.get(key);
                if (session) {
                    try {
                        const sessionData = JSON.parse(session);
                        if (sessionData.userId === userId) {
                            await redisClient.del(key);
                            deletedCount++;
                        }
                    } catch {
                        // Skip invalid session data
                    }
                }
            }

            logger.debug(`Destroyed ${deletedCount} sessions for user ${userId}`);
            return deletedCount;
        } catch (error) {
            logger.error(`Failed to destroy sessions for user ${userId}:`, error);
            return 0;
        }
    }
}

// Rate limiting helper
class RateLimit {
    constructor() {
        this.cache = new Cache('rate-limit:');
    }

    async checkLimit(identifier, limit = 100, window = 900) { // 15 minutes default
        try {
            const key = `${identifier}:${Math.floor(Date.now() / (window * 1000))}`;
            const current = await this.cache.incr(key, window);
            
            return {
                allowed: current <= limit,
                current,
                limit,
                remaining: Math.max(0, limit - current),
                resetTime: Math.ceil(Date.now() / (window * 1000)) * (window * 1000)
            };
        } catch (error) {
            logger.error(`Rate limit check error for ${identifier}:`, error);
            // Allow request if Redis fails
            return {
                allowed: true,
                current: 0,
                limit,
                remaining: limit,
                resetTime: Date.now() + (window * 1000)
            };
        }
    }
}

// Shopping cart management
class CartManager {
    constructor() {
        this.cache = new Cache('cart:');
        this.defaultTTL = 7 * 24 * 60 * 60; // 7 days
    }

    async getCart(userId) {
        try {
            const cart = await this.cache.get(userId);
            return cart || { items: [], total: 0, updatedAt: new Date().toISOString() };
        } catch (error) {
            logger.error(`Failed to get cart for user ${userId}:`, error);
            return { items: [], total: 0, updatedAt: new Date().toISOString() };
        }
    }

    async setCart(userId, cart) {
        try {
            const cartData = {
                ...cart,
                updatedAt: new Date().toISOString()
            };
            await this.cache.set(userId, cartData, this.defaultTTL);
            return true;
        } catch (error) {
            logger.error(`Failed to set cart for user ${userId}:`, error);
            return false;
        }
    }

    async clearCart(userId) {
        try {
            const result = await this.cache.del(userId);
            logger.debug(`Cart cleared for user ${userId}`);
            return result;
        } catch (error) {
            logger.error(`Failed to clear cart for user ${userId}:`, error);
            return false;
        }
    }
}

// Redis health check
async function healthCheck() {
    try {
        const start = Date.now();
        const pong = await redisClient.ping();
        const duration = Date.now() - start;

        if (pong === 'PONG') {
            return {
                healthy: true,
                responseTime: `${duration}ms`,
                connected: redisClient.isReady
            };
        } else {
            return {
                healthy: false,
                error: 'Invalid ping response'
            };
        }
    } catch (error) {
        return {
            healthy: false,
            error: error.message,
            connected: redisClient.isReady
        };
    }
}

// Get Redis info
async function getInfo() {
    try {
        const info = await redisClient.info();
        const lines = info.split('\r\n');
        const result = {};

        for (const line of lines) {
            if (line.includes(':')) {
                const [key, value] = line.split(':');
                result[key] = value;
            }
        }

        return {
            version: result.redis_version,
            uptime: parseInt(result.uptime_in_seconds),
            connectedClients: parseInt(result.connected_clients),
            usedMemory: result.used_memory_human,
            totalCommands: parseInt(result.total_commands_processed)
        };
    } catch (error) {
        logger.error('Failed to get Redis info:', error);
        return null;
    }
}

// Initialize cache instances
const cache = new Cache();
const sessionManager = new SessionManager();
const rateLimit = new RateLimit();
const cartManager = new CartManager();

module.exports = {
    redisClient,
    connectRedis,
    cache,
    sessionManager,
    rateLimit,
    cartManager,
    healthCheck,
    getInfo,
    Cache,
    SessionManager,
    RateLimit,
    CartManager
};