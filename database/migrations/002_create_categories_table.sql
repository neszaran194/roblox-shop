-- database/migrations/002_create_categories_table.sql
-- สร้างตาราง categories สำหรับหมวดหมู่สินค้า

CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    slug VARCHAR(100) UNIQUE NOT NULL,
    image_url VARCHAR(500),
    banner_url VARCHAR(500),
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    meta_title VARCHAR(200),
    meta_description TEXT,
    meta_keywords TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- สร้าง indexes
CREATE INDEX idx_categories_slug ON categories(slug);
CREATE INDEX idx_categories_display_order ON categories(display_order);
CREATE INDEX idx_categories_is_active ON categories(is_active);
CREATE INDEX idx_categories_name ON categories(name);

-- สร้าง trigger สำหรับ updated_at
CREATE TRIGGER update_categories_updated_at 
    BEFORE UPDATE ON categories 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE categories IS 'ตารางหมวดหมู่สินค้า';
COMMENT ON COLUMN categories.slug IS 'URL slug สำหรับ SEO';
COMMENT ON COLUMN categories.display_order IS 'ลำดับการแสดงผล';