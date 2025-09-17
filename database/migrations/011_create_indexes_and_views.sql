-- database/migrations/011_create_indexes_and_views.sql
-- สร้าง indexes เพิ่มเติมและ Views สำหรับการ query ที่ซับซ้อน

-- ===== Additional Indexes =====

-- Full Text Search indexes
CREATE INDEX idx_products_name_fulltext ON products USING gin(to_tsvector('thai', name));
CREATE INDEX idx_products_description_fulltext ON products USING gin(to_tsvector('thai', description));
CREATE INDEX idx_categories_name_fulltext ON categories USING gin(to_tsvector('thai', name));

-- Composite indexes สำหรับ queries ที่ใช้บ่อย
CREATE INDEX idx_products_category_active_featured ON products(category_id, is_active, is_featured);
CREATE INDEX idx_products_active_popular_sales ON products(is_active, is_popular, sales_count DESC);
CREATE INDEX idx_orders_user_status_created ON orders(user_id, status, created_at DESC);
CREATE INDEX idx_transactions_user_status_created ON transactions(user_id, status, created_at DESC);

-- Partial indexes สำหรับข้อมูลที่ใช้บ่อย
CREATE INDEX idx_products_active_stock ON products(id, stock) WHERE is_active = true AND stock > 0;
CREATE INDEX idx_orders_pending ON orders(id, user_id, created_at) WHERE status = 'pending';
CREATE INDEX idx_notifications_unread ON notifications(user_id, created_at DESC) WHERE is_read = false;

-- ===== Views =====

-- View สำหรับสินค้าพร้อมข้อมูลหมวดหมู่
CREATE VIEW product_details AS
SELECT 
    p.id,
    p.name,
    p.description,
    p.slug,
    p.price,
    p.stock,
    p.image_urls,
    p.is_featured,
    p.is_popular,
    p.is_active,
    p.view_count,
    p.sales_count,
    p.created_at,
    p.updated_at,
    c.id as category_id,
    c.name as category_name,
    c.slug as category_slug,
    c.image_url as category_image,
    -- คำนวณจำนวนรหัสที่ใช้ได้จริง
    (SELECT COUNT(*) FROM product_codes pc 
     WHERE pc.product_id = p.id 
       AND pc.is_used = false 
       AND (pc.reserved_until IS NULL OR pc.reserved_until < NOW())
    ) as available_codes
FROM products p
INNER JOIN categories c ON p.category_id = c.id;

-- View สำหรับคำสั่งซื้อพร้อมข้อมูลลูกค้า
CREATE VIEW order_details AS
SELECT 
    o.id,
    o.order_number,
    o.total_amount,
    o.credits_used,
    o.status,
    o.payment_method,
    o.created_at,
    o.updated_at,
    o.completed_at,
    u.id as user_id,
    u.username,
    u.email,
    -- คำนวณจำนวนรายการ
    (SELECT COUNT(*) FROM order_items oi WHERE oi.order_id = o.id) as item_count,
    -- คำนวณจำนวนรหัสที่ส่งแล้ว
    (SELECT COUNT(*) FROM order_items oi WHERE oi.order_id = o.id AND oi.delivered_at IS NOT NULL) as delivered_count
FROM orders o
INNER JOIN users u ON o.user_id = u.id;

-- View สำหรับสถิติการขายรายวัน
CREATE VIEW daily_sales_stats AS
SELECT 
    DATE(o.completed_at) as sale_date,
    COUNT(*) as order_count,
    SUM(o.total_amount) as total_revenue,
    SUM(o.credits_used) as credits_used,
    COUNT(DISTINCT o.user_id) as unique_customers,
    AVG(o.total_amount) as average_order_value
FROM orders o
WHERE o.status = 'completed' 
    AND o.completed_at IS NOT NULL
GROUP BY DATE(o.completed_at);

-- View สำหรับสถิติสินค้า
CREATE VIEW product_stats AS
SELECT 
    p.id,
    p.name,
    p.category_id,
    p.price,
    p.stock,
    p.sales_count,
    p.view_count,
    -- คำนวณ conversion rate
    CASE 
        WHEN p.view_count > 0 THEN ROUND((p.sales_count::DECIMAL / p.view_count * 100), 2)
        ELSE 0
    END as conversion_rate,
    -- คำนวณรายได้รวม
    (SELECT COALESCE(SUM(oi.total_price), 0) 
     FROM order_items oi 
     INNER JOIN orders o ON oi.order_id = o.id 
     WHERE oi.product_id = p.id AND o.status = 'completed'
    ) as total_revenue,
    -- วันที่ขายล่าสุด
    (SELECT MAX(o.completed_at) 
     FROM order_items oi 
     INNER JOIN orders o ON oi.order_id = o.id 
     WHERE oi.product_id = p.id AND o.status = 'completed'
    ) as last_sale_date
FROM products p;

-- View สำหรับสถิติลูกค้า
CREATE VIEW customer_stats AS
SELECT 
    u.id,
    u.username,
    u.email,
    u.created_at as registration_date,
    u.last_login,
    u.credits,
    -- จำนวนคำสั่งซื้อ
    (SELECT COUNT(*) FROM orders o WHERE o.user_id = u.id) as total_orders,
    -- จำนวนคำสั่งซื้อที่สำเร็จ
    (SELECT COUNT(*) FROM orders o WHERE o.user_id = u.id AND o.status = 'completed') as completed_orders,
    -- ยอดใช้จ่ายรวม
    (SELECT COALESCE(SUM(o.total_amount), 0) FROM orders o WHERE o.user_id = u.id AND o.status = 'completed') as total_spent,
    -- คำสั่งซื้อล่าสุด
    (SELECT MAX(o.created_at) FROM orders o WHERE o.user_id = u.id) as last_order_date,
    -- ยอดเติมเงินรวม
    (SELECT COALESCE(SUM(ct.amount), 0) 
     FROM credit_transactions ct 
     WHERE ct.user_id = u.id AND ct.transaction_type = 'deposit'
    ) as total_deposited
FROM users u
WHERE u.role = 'user';

-- View สำหรับสถิติการเงิน
CREATE VIEW financial_summary AS
SELECT 
    DATE(ct.created_at) as transaction_date,
    ct.transaction_type,
    COUNT(*) as transaction_count,
    SUM(ct.amount) as total_amount,
    COUNT(DISTINCT ct.user_id) as unique_users
FROM credit_transactions ct
GROUP BY DATE(ct.created_at), ct.transaction_type;

-- View สำหรับ Dashboard
CREATE VIEW dashboard_stats AS
SELECT 
    -- ผู้ใช้ทั้งหมด
    (SELECT COUNT(*) FROM users WHERE role = 'user') as total_users,
    -- ผู้ใช้ใหม่วันนี้
    (SELECT COUNT(*) FROM users WHERE role = 'user' AND DATE(created_at) = CURRENT_DATE) as new_users_today,
    -- สินค้าทั้งหมด
    (SELECT COUNT(*) FROM products WHERE is_active = true) as total_products,
    -- สินค้าหมดสต็อก
    (SELECT COUNT(*) FROM products WHERE is_active = true AND stock = 0) as out_of_stock_products,
    -- คำสั่งซื้อวันนี้
    (SELECT COUNT(*) FROM orders WHERE DATE(created_at) = CURRENT_DATE) as orders_today,
    -- คำสั่งซื้อรอดำเนินการ
    (SELECT COUNT(*) FROM orders WHERE status = 'pending') as pending_orders,
    -- รายได้วันนี้
    (SELECT COALESCE(SUM(total_amount), 0) FROM orders 
     WHERE status = 'completed' AND DATE(completed_at) = CURRENT_DATE) as revenue_today,
    -- รายได้เดือนนี้
    (SELECT COALESCE(SUM(total_amount), 0) FROM orders 
     WHERE status = 'completed' 
       AND DATE_TRUNC('month', completed_at) = DATE_TRUNC('month', CURRENT_DATE)) as revenue_this_month,
    -- การแจ้งเตือนแอดมินที่ยังไม่อ่าน
    (SELECT COUNT(*) FROM admin_notifications WHERE is_read = false) as unread_admin_notifications;

-- ===== Materialized Views สำหรับ Performance =====

-- Materialized View สำหรับสินค้าขายดี
CREATE MATERIALIZED VIEW top_selling_products AS
SELECT 
    p.id,
    p.name,
    p.price,
    p.image_urls[1] as primary_image,
    p.sales_count,
    c.name as category_name,
    -- คำนวณรายได้
    COALESCE(SUM(oi.total_price), 0) as total_revenue,
    -- คำนวณจำนวนคำสั่งซื้อ
    COUNT(DISTINCT oi.order_id) as order_count
FROM products p
INNER JOIN categories c ON p.category_id = c.id
LEFT JOIN order_items oi ON p.id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.id AND o.status = 'completed'
WHERE p.is_active = true
GROUP BY p.id, p.name, p.price, p.image_urls, p.sales_count, c.name
ORDER BY p.sales_count DESC, total_revenue DESC;

-- Index สำหรับ Materialized View
CREATE INDEX idx_top_selling_products_sales ON top_selling_products(sales_count DESC);
CREATE INDEX idx_top_selling_products_revenue ON top_selling_products(total_revenue DESC);

-- Function สำหรับ Refresh Materialized Views
CREATE OR REPLACE FUNCTION refresh_materialized_views()
RETURNS VOID AS $
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY top_selling_products;
    -- เพิ่ม materialized views อื่นๆ ในอนาคต
END;
$ LANGUAGE plpgsql;

-- ===== Search Functions =====

-- Function สำหรับค้นหาสินค้า
CREATE OR REPLACE FUNCTION search_products(
    p_query TEXT,
    p_category_id UUID DEFAULT NULL,
    p_min_price DECIMAL DEFAULT NULL,
    p_max_price DECIMAL DEFAULT NULL,
    p_in_stock_only BOOLEAN DEFAULT true,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
) RETURNS TABLE (
    id UUID,
    name VARCHAR(200),
    description TEXT,
    price DECIMAL(10,2),
    stock INTEGER,
    image_urls TEXT[],
    category_name VARCHAR(100),
    rank REAL
) AS $
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.name,
        p.description,
        p.price,
        p.stock,
        p.image_urls,
        c.name as category_name,
        ts_rank(
            to_tsvector('thai', p.name || ' ' || COALESCE(p.description, '')),
            plainto_tsquery('thai', p_query)
        ) as rank
    FROM products p
    INNER JOIN categories c ON p.category_id = c.id
    WHERE p.is_active = true
        AND (NOT p_in_stock_only OR p.stock > 0)
        AND (p_category_id IS NULL OR p.category_id = p_category_id)
        AND (p_min_price IS NULL OR p.price >= p_min_price)
        AND (p_max_price IS NULL OR p.price <= p_max_price)
        AND (
            p_query IS NULL OR p_query = '' OR
            to_tsvector('thai', p.name || ' ' || COALESCE(p.description, '')) @@ plainto_tsquery('thai', p_query)
        )
    ORDER BY 
        CASE WHEN p_query IS NULL OR p_query = '' THEN p.sales_count ELSE NULL END DESC,
        CASE WHEN p_query IS NOT NULL AND p_query != '' THEN rank ELSE NULL END DESC,
        p.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$ LANGUAGE plpgsql;

-- ===== Cleanup Functions =====

-- Function สำหรับทำความสะอาดข้อมูลทั้งหมด
CREATE OR REPLACE FUNCTION cleanup_all_expired_data()
RETURNS TEXT AS $
DECLARE
    result TEXT := '';
    expired_transactions INTEGER;
    expired_sessions INTEGER;
    expired_notifications INTEGER;
    expired_password_resets INTEGER;
BEGIN
    -- ทำความสะอาดธุรกรรมหมดอายุ
    SELECT cleanup_expired_transactions() INTO expired_transactions;
    result := result || 'Expired transactions: ' || expired_transactions || E'\n';
    
    -- ทำความสะอาดเซสชั่นแอดมิน
    SELECT cleanup_expired_admin_sessions() INTO expired_sessions;
    result := result || 'Expired admin sessions: ' || expired_sessions || E'\n';
    
    -- ทำความสะอาดการแจ้งเตือน
    SELECT cleanup_old_notifications() INTO expired_notifications;
    result := result || 'Old notifications: ' || expired_notifications || E'\n';
    
    -- ทำความสะอาดโทเค็นรีเซ็ตรหัสผ่าน
    SELECT cleanup_expired_password_resets() INTO expired_password_resets;
    result := result || 'Expired password resets: ' || expired_password_resets || E'\n';
    
    -- Refresh materialized views
    PERFORM refresh_materialized_views();
    result := result || 'Materialized views refreshed' || E'\n';
    
    RETURN result;
END;
$ LANGUAGE plpgsql;

COMMENT ON VIEW product_details IS 'View สินค้าพร้อมข้อมูลหมวดหมู่และจำนวนรหัสที่ใช้ได้';
COMMENT ON VIEW order_details IS 'View คำสั่งซื้อพร้อมข้อมูลลูกค้า';
COMMENT ON VIEW daily_sales_stats IS 'View สถิติการขายรายวัน';
COMMENT ON VIEW product_stats IS 'View สถิติสินค้า';
COMMENT ON VIEW customer_stats IS 'View สถิติลูกค้า';
COMMENT ON VIEW dashboard_stats IS 'View สถิติสำหรับหน้า Dashboard';

COMMENT ON MATERIALIZED VIEW top_selling_products IS 'Materialized View สินค้าขายดี';

COMMENT ON FUNCTION search_products IS 'ค้นหาสินค้าด้วย Full Text Search';
COMMENT ON FUNCTION refresh_materialized_views IS 'Refresh Materialized Views ทั้งหมด';
COMMENT ON FUNCTION cleanup_all_expired_data IS 'ทำความสะอาดข้อมูลหมดอายุทั้งหมด';