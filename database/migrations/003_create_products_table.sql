-- database/migrations/003_create_products_table.sql
-- สร้างตาราง products สำหรับสินค้า

CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    slug VARCHAR(200) UNIQUE NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    stock INTEGER DEFAULT 0,
    image_urls TEXT[], -- Array of image URLs
    is_featured BOOLEAN DEFAULT false,
    is_popular BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    meta_title VARCHAR(200),
    meta_description TEXT,
    meta_keywords TEXT,
    view_count INTEGER DEFAULT 0,
    sales_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- สร้าง indexes
CREATE INDEX idx_products_category_id ON products(category_id);
CREATE INDEX idx_products_slug ON products(slug);
CREATE INDEX idx_products_is_active ON products(is_active);
CREATE INDEX idx_products_is_featured ON products(is_featured);
CREATE INDEX idx_products_is_popular ON products(is_popular);
CREATE INDEX idx_products_price ON products(price);
CREATE INDEX idx_products_stock ON products(stock);
CREATE INDEX idx_products_name ON products(name);
CREATE INDEX idx_products_sales_count ON products(sales_count DESC);
CREATE INDEX idx_products_created_at ON products(created_at DESC);

-- สร้าง trigger สำหรับ updated_at
CREATE TRIGGER update_products_updated_at 
    BEFORE UPDATE ON products 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE products IS 'ตารางสินค้า (รหัสเกม)';
COMMENT ON COLUMN products.stock IS 'จำนวนรหัสคงเหลือ';
COMMENT ON COLUMN products.image_urls IS 'รูปภาพสินค้าหลายรูป';
COMMENT ON COLUMN products.is_featured IS 'สินค้าแนะนำ';
COMMENT ON COLUMN products.is_popular IS 'สินค้ายอดนิยม';