#!/bin/bash

# scripts/setup-database.sh
# สคริปต์สำหรับตั้งค่าฐานข้อมูลเริ่มต้น

set -e

echo "🚀 Setting up Roblox Shop Database..."

# ตัวแปรสำหรับการเชื่อมต่อฐานข้อมูล
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_USER=${POSTGRES_USER:-roblox_user}
DB_PASSWORD=${POSTGRES_PASSWORD:-secure_password}
DB_NAME=${POSTGRES_DB:-roblox_shop}

# สีสำหรับข้อความ
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ฟังก์ชันสำหรับแสดงข้อความ
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ตรวจสอบว่า PostgreSQL ทำงานอยู่หรือไม่
check_postgres() {
    print_status "Checking PostgreSQL connection..."
    
    if pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USER; then
        print_success "PostgreSQL is running"
    else
        print_error "Cannot connect to PostgreSQL"
        print_error "Please check if PostgreSQL is running and connection details are correct"
        exit 1
    fi
}

# สร้างฐานข้อมูลถ้ายังไม่มี
create_database() {
    print_status "Creating database '$DB_NAME' if not exists..."
    
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1 || {
        print_status "Database '$DB_NAME' does not exist, creating..."
        PGPASSWORD=$DB_PASSWORD createdb -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME
        print_success "Database '$DB_NAME' created"
    }
}

# รัน migrations
run_migrations() {
    print_status "Running database migrations..."
    
    cd "$(dirname "$0")/../database"
    
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f run_migrations.sql
    
    print_success "All migrations completed"
}

# รัน seeds
run_seeds() {
    print_status "Seeding initial data..."
    
    cd "$(dirname "$0")/../database"
    
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f seeds/001_initial_data.sql
    
    print_success "Initial data seeded"
}

# สร้าง backup directory
setup_backup() {
    print_status "Setting up backup directory..."
    
    BACKUP_DIR="$(dirname "$0")/../database/backup"
    mkdir -p $BACKUP_DIR
    
    # สร้าง backup script
    cat > $BACKUP_DIR/backup.sh << EOF
#!/bin/bash
# Auto-generated backup script

BACKUP_DIR=\$(dirname "\$0")
DATE=\$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="\$BACKUP_DIR/roblox_shop_backup_\$DATE.sql"

echo "Creating backup: \$BACKUP_FILE"

PGPASSWORD=$DB_PASSWORD pg_dump \\
    -h $DB_HOST \\
    -p $DB_PORT \\
    -U $DB_USER \\
    -d $DB_NAME \\
    --no-owner \\
    --no-privileges \\
    --clean \\
    --create > "\$BACKUP_FILE"

if [ \$? -eq 0 ]; then
    echo "Backup completed successfully: \$BACKUP_FILE"
    
    # Keep only last 7 backups
    ls -t \$BACKUP_DIR/roblox_shop_backup_*.sql | tail -n +8 | xargs rm -f
    echo "Old backups cleaned up (keeping last 7)"
else
    echo "Backup failed!"
    exit 1
fi
EOF
    
    chmod +x $BACKUP_DIR/backup.sh
    print_success "Backup system setup completed"
}

# แสดงสรุปผลลัพธ์
show_summary() {
    print_success "Database setup completed successfully!"
    echo ""
    echo "📊 Database Summary:"
    echo "  Host: $DB_HOST:$DB_PORT"
    echo "  Database: $DB_NAME"
    echo "  User: $DB_USER"
    echo ""
    echo "🔑 Default Accounts:"
    echo "  Super Admin: username=superadmin, password=admin123"
    echo "  Test User: username=testuser, password=test123"
    echo ""
    echo "🛠️ Available Commands:"
    echo "  Backup: ./database/backup/backup.sh"
    echo "  Cleanup: psql -c \"SELECT cleanup_all_expired_data();\""
    echo "  Reset: dropdb $DB_NAME && ./setup-database.sh"
    echo ""
    print_warning "Please change default passwords in production!"
}

# Main execution
main() {
    echo "╔════════════════════════════════════════╗"
    echo "║        Roblox Shop Database Setup      ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    
    # ตรวจสอบ dependencies
    command -v psql >/dev/null 2>&1 || { print_error "psql is required but not installed."; exit 1; }
    command -v pg_isready >/dev/null 2>&1 || { print_error "pg_isready is required but not installed."; exit 1; }
    
    # รัน setup steps
    check_postgres
    create_database
    run_migrations
    run_seeds
    setup_backup
    show_summary
}

# ตรวจสอบ arguments
case "${1:-}" in
    "migrations-only")
        print_status "Running migrations only..."
        check_postgres
        run_migrations
        print_success "Migrations completed"
        ;;
    "seeds-only")
        print_status "Running seeds only..."
        check_postgres
        run_seeds
        print_success "Seeds completed"
        ;;
    "backup")
        print_status "Creating backup..."
        check_postgres
        ./database/backup/backup.sh
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  (no args)       Full database setup (migrations + seeds)"
        echo "  migrations-only Run migrations only"
        echo "  seeds-only      Run seeds only"  
        echo "  backup          Create database backup"
        echo "  help            Show this help message"
        echo ""
        echo "Environment Variables:"
        echo "  DB_HOST         Database host (default: localhost)"
        echo "  DB_PORT         Database port (default: 5432)"
        echo "  POSTGRES_USER   Database user (default: roblox_user)"
        echo "  POSTGRES_PASSWORD Database password (default: secure_password)"
        echo "  POSTGRES_DB     Database name (default: roblox_shop)"
        ;;
    *)
        main
        ;;
esac