# 🎮 Roblox Code Shop

ระบบขายรหัสเกม Roblox ออนไลน์ที่ครบครัน พร้อมระบบการเงิน PromptPay และ TrueWallet

## 🚀 Features

- ✅ ระบบขายรหัสเกม Roblox
- ✅ การชำระเงินผ่าน PromptPay & TrueWallet
- ✅ ระบบจัดการสต็อกอัตโนมัติ
- ✅ Admin Dashboard ครบครัน
- ✅ ระบบแจ้งเตือน Real-time
- ✅ ระบบคูปองส่วนลด
- ✅ Responsive Design
- ✅ JWT Authentication System
- ✅ Role-based Authorization
- ✅ Redis Caching & Session Management

## 🏗️ Tech Stack

- **Frontend:** React 18, Tailwind CSS
- **Backend:** Node.js, Express.js
- **Database:** PostgreSQL with advanced indexing
- **Cache:** Redis (Caching, Sessions, Rate Limiting)
- **Authentication:** JWT + Refresh Tokens
- **Payment:** promptpay-truewallet-system integration
- **Security:** bcrypt, Helmet, CORS, Rate Limiting
- **Logging:** Winston with structured logging
- **Deployment:** Docker, Nginx

## 📊 Project Status

- [x] **Database Schema & Migrations** (100%) - Complete with 11 migrations
- [x] **Backend API Foundation** (40%) - Authentication system complete
  - [x] Express.js setup with comprehensive middleware
  - [x] PostgreSQL connection with pooling
  - [x] Redis integration (caching, sessions, rate limiting)
  - [x] JWT authentication with refresh tokens
  - [x] User registration, login, profile management
  - [x] Password change and security features
  - [x] Global error handling with Thai language
  - [x] Structured logging system
  - [ ] Product & Category APIs
  - [ ] Shopping Cart & Order APIs  
  - [ ] Payment Integration APIs
  - [ ] Admin Management APIs
- [ ] **Frontend Customer Interface** (0%)
- [ ] **Admin Dashboard** (0%)
- [ ] **Payment Integration Testing** (0%)
- [ ] **Docker Setup** (0%)
- [ ] **Production Deployment** (0%)

## 🔗 API Documentation

### Authentication Endpoints
- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User login (rate limited: 5/15min)
- `POST /api/auth/logout` - Secure logout
- `POST /api/auth/refresh` - Token refresh
- `GET /api/auth/profile` - Get user profile
- `PUT /api/auth/profile` - Update profile
- `POST /api/auth/change-password` - Change password
- `GET /api/auth/verify` - Verify token

### System Endpoints
- `GET /health` - Health check
- `GET /api` - API documentation

## 🚀 Quick Start

### Prerequisites
- Node.js 18+
- PostgreSQL 15+
- Redis 7+

### Installation

```bash
# Clone repository
git clone https://github.com/neszaran194/roblox-shop.git
cd roblox-shop

# Setup database
cd database
chmod +x ../scripts/setup-database.sh
../scripts/setup-database.sh

# Setup backend
cd ../backend
cp .env.example .env
# Edit .env file with your database credentials

# Install dependencies
npm install

# Run migrations (if not done by setup script)
npm run migrate

# Start development server
npm run dev
```

### Environment Variables

Copy `backend/.env.example` to `backend/.env` and configure:

```env
# Database
DATABASE_URL=postgresql://roblox_user:secure_password@localhost:5432/roblox_shop

# JWT
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production

# Redis
REDIS_URL=redis://localhost:6379

# Payment (PromptPay/TrueWallet)
PROMPTPAY_PHONE=0944283381
```

## 📋 Development Workflow

### Current Status:
1. **Database Layer** ✅ Complete (100%)
   - 11 comprehensive migrations
   - Advanced indexes and views
   - Stored procedures for business logic
   - Sample data seeding

2. **Backend API** 🚧 In Progress (40%)
   - ✅ Authentication system complete
   - ✅ Security middleware
   - ✅ Error handling & logging
   - ⏳ Product management APIs
   - ⏳ Order processing APIs
   - ⏳ Payment integration

3. **Frontend** ⏳ Pending (0%)
4. **Admin Dashboard** ⏳ Pending (0%)
5. **Testing & Deployment** ⏳ Pending (0%)

### Next Steps:
- [ ] Product & Category management APIs
- [ ] Shopping cart functionality
- [ ] Order processing system
- [ ] Payment integration (PromptPay/TrueWallet)
- [ ] Admin panel APIs

## 🧪 Testing

```bash
# Run tests (when available)
cd backend
npm test

# Test API endpoints
npm run test:api
```

## 🔑 Default Accounts

- **Super Admin:** `superadmin` / `admin123`
- **Test User:** `testuser` / `test123` (1000 credits)

## 📁 Project Structure

```
roblox-shop/
├── database/              # Database schemas & migrations
│   ├── migrations/        # 11 SQL migration files
│   ├── seeds/            # Initial data
│   └── backup/           # Backup scripts
├── backend/              # Node.js API server
│   ├── src/
│   │   ├── config/       # Database & Redis config
│   │   ├── middleware/   # Auth & error handling
│   │   ├── routes/       # API endpoints
│   │   ├── utils/        # Utilities & logging
│   │   └── app.js        # Express app setup
│   ├── package.json
│   └── server.js         # Entry point
├── frontend/             # React customer interface (planned)
├── admin-dashboard/      # React admin panel (planned)
└── scripts/              # Utility scripts
```

## 🛡️ Security Features

- **Password Security:** bcrypt hashing with 12 rounds
- **JWT Authentication:** Access + refresh token system
- **Rate Limiting:** IP-based request limiting
- **CORS Protection:** Configured allowed origins
- **Input Validation:** express-validator for all inputs
- **SQL Injection Protection:** Parameterized queries
- **Session Security:** Redis-based session storage
- **Activity Logging:** Comprehensive audit trails

## 🔧 Development Commands

```bash
# Backend development
cd backend
npm run dev          # Start with nodemon
npm run start        # Production start
npm run lint         # ESLint check
npm run lint:fix     # Fix linting issues
npm run migrate      # Run database migrations
npm run seed         # Seed sample data

# Database management
./scripts/setup-database.sh        # Full database setup
./scripts/setup-database.sh backup # Create backup
```

## 📊 Performance Features

- **Database Connection Pooling:** Optimized PostgreSQL connections
- **Redis Caching:** Intelligent caching strategies
- **Request Compression:** gzip compression middleware
- **Query Optimization:** Indexed searches and views
- **Session Management:** Redis-based sessions
- **Rate Limiting:** Prevent API abuse

## 🐛 Troubleshooting

### Common Issues:

1. **Database Connection Error:**
   ```bash
   # Check PostgreSQL is running
   pg_isready -h localhost -p 5432
   
   # Verify credentials in .env file
   ```

2. **Redis Connection Error:**
   ```bash
   # Check Redis is running
   redis-cli ping
   
   # Should return PONG
   ```

3. **Permission Errors:**
   ```bash
   # Make sure scripts are executable
   chmod +x scripts/setup-database.sh
   ```

## 📈 Monitoring & Logs

- **Application Logs:** `backend/logs/`
- **Health Check:** `GET /health`
- **API Documentation:** `GET /api`
- **Winston Logging:** Structured logs with rotation

## 🤝 Contributing

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Contact & Support

- **GitHub Issues:** [Report bugs or request features](https://github.com/neszaran194/roblox-shop/issues)
- **Discord:** [Your Discord Server]
- **Email:** [Your Email]

---

**⚠️ Note:** This project is currently in active development. The authentication system is complete, but product management, payment integration, and frontend are still in progress.

**🚀 Star this repo** if you find it useful and want to follow the development progress!