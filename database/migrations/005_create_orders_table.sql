-- database/migrations/005_create_orders_table.sql
-- สร้างตาราง orders สำหรับคำสั่งซื้อ

CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_number VARCHAR(20) UNIQUE NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    credits_used DECIMAL(10,2) NOT NULL DEFAULT 0,
    status VARCHAR(20) DEFAULT 'pending' CHECK (
        status IN ('pending', 'processing', 'completed', 'cancelled', 'failed')
    ),
    payment_method VARCHAR(50),
    payment_reference VARCHAR(200),
    notes TEXT,
    admin_notes TEXT,
    processed_by UUID REFERENCES users(id),
    processed_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- สร้างตาราง order_items
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    product_code_id UUID REFERENCES product_codes(id),
    product_name VARCHAR(200) NOT NULL, -- เก็บชื่อสินค้าเวลาสั่งซื้อ
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,
    product_code VARCHAR(500), -- รหัสที่ลูกค้าได้รับ
    delivered_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- สร้าง indexes สำหรับ orders
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_order_number ON orders(order_number);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX idx_orders_completed_at ON orders(completed_at DESC);
CREATE INDEX idx_orders_processed_by ON orders(processed_by);

-- สร้าง indexes สำหรับ order_items
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_order_items_product_code_id ON order_items(product_code_id);
CREATE INDEX idx_order_items_delivered_at ON order_items(delivered_at);

-- สร้าง triggers
CREATE TRIGGER update_orders_updated_at 
    BEFORE UPDATE ON orders 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Function สำหรับสร้างหมายเลขคำสั่งซื้อ
CREATE OR REPLACE FUNCTION generate_order_number() 
RETURNS VARCHAR(20) AS $$
DECLARE
    new_number VARCHAR(20);
    counter INTEGER;
BEGIN
    -- สร้างหมายเลขคำสั่งซื้อในรูปแบบ ORD-YYYYMMDD-XXXX
    SELECT COUNT(*) + 1 INTO counter
    FROM orders 
    WHERE DATE(created_at) = CURRENT_DATE;
    
    new_number := 'ORD-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || LPAD(counter::TEXT, 4, '0');
    
    -- ตรวจสอบว่าหมายเลขนี้ยังไม่มี (กรณี race condition)
    WHILE EXISTS (SELECT 1 FROM orders WHERE order_number = new_number) LOOP
        counter := counter + 1;
        new_number := 'ORD-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || LPAD(counter::TEXT, 4, '0');
    END LOOP;
    
    RETURN new_number;
END;
$$ LANGUAGE plpgsql;

-- Function สำหรับคำนวณยอดรวมคำสั่งซื้อ
CREATE OR REPLACE FUNCTION calculate_order_total(p_order_id UUID)
RETURNS DECIMAL(10,2) AS $$
DECLARE
    total_amount DECIMAL(10,2);
BEGIN
    SELECT COALESCE(SUM(total_price), 0) INTO total_amount
    FROM order_items 
    WHERE order_id = p_order_id;
    
    RETURN total_amount;
END;
$$ LANGUAGE plpgsql;

-- Trigger สำหรับอัปเดต stock เมื่อสั่งซื้อสำเร็จ
CREATE OR REPLACE FUNCTION update_product_stock_on_order()
RETURNS TRIGGER AS $$
BEGIN
    -- เมื่อ order เปลี่ยนเป็น completed
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        UPDATE products 
        SET stock = stock - oi.quantity,
            sales_count = sales_count + oi.quantity
        FROM order_items oi
        WHERE oi.order_id = NEW.id 
            AND products.id = oi.product_id;
    END IF;
    
    -- เมื่อ order ถูกยกเลิก คืน stock
    IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
        UPDATE products 
        SET stock = stock + oi.quantity,
            sales_count = GREATEST(sales_count - oi.quantity, 0)
        FROM order_items oi
        WHERE oi.order_id = NEW.id 
            AND products.id = oi.product_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_product_stock_trigger
    AFTER UPDATE OF status ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_product_stock_on_order();

COMMENT ON TABLE orders IS 'ตารางคำสั่งซื้อ';
COMMENT ON TABLE order_items IS 'ตารางรายการสินค้าในคำสั่งซื้อ';
COMMENT ON COLUMN orders.credits_used IS 'จำนวนเครดิตที่ใช้';
COMMENT ON COLUMN order_items.product_code IS 'รหัสเกมที่ลูกค้าได้รับ';