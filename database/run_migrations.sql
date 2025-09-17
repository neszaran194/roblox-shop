-- database/run_migrations.sql
-- สคริปต์สำหรับรันการ migration ทั้งหมดพร้อมกัน

-- ตั้งค่าเริ่มต้น
\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';
SET timezone = 'Asia/Bangkok';

-- แสดงข้อความเริ่มต้น
SELECT 'Starting database migrations for Roblox Code Shop...' as status;

-- สร้าง extensions และฟังก์ชั่นพื้นฐาน
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- รัน migrations ตามลำดับ
\echo 'Running migration 001: Creating users table...'
\i migrations/001_create_users_table.sql

\echo 'Running migration 002: Creating categories table...'
\i migrations/002_create_categories_table.sql

\echo 'Running migration 003: Creating products table...'
\i migrations/003_create_products_table.sql

\echo 'Running migration 004: Creating product codes table...'
\i migrations/004_create_product_codes_table.sql

\echo 'Running migration 005: Creating orders table...'
\i migrations/005_create_orders_table.sql

\echo 'Running migration 006: Creating transactions table...'
\i migrations/006_create_transactions_table.sql

\echo 'Running migration 007: Creating admin users table...'
\i migrations/007_create_admin_users_table.sql

\echo 'Running migration 008: Creating content tables...'
\i migrations/008_create_content_tables.sql

\echo 'Running migration 009: Creating notifications table...'
\i migrations/009_create_notifications_table.sql

\echo 'Running migration 010: Creating password resets table...'
\i migrations/010_create_password_resets_table.sql

\echo 'Running migration 011: Creating indexes and views...'
\i migrations/011_create_indexes_and_views.sql

-- แสดงสถานะการ migration
SELECT 'All migrations completed successfully!' as status;

-- แสดงสรุปตาราง
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- แสดงจำนวน indexes
SELECT 
    'Total indexes created: ' || COUNT(*) as index_summary
FROM pg_indexes 
WHERE schemaname = 'public';

-- แสดงจำนวนฟังก์ชั่น
SELECT 
    'Total functions created: ' || COUNT(*) as function_summary
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public';

SELECT 'Database schema ready for seeding!' as final_status;