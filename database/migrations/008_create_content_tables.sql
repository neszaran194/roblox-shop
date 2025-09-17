-- database/migrations/008_create_content_tables.sql
-- สร้างตารางสำหรับจัดการเนื้อหาเว็บไซต์

-- ตารางแบนเนอร์
CREATE TABLE banners (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(200) NOT NULL,
    image_url VARCHAR(500) NOT NULL,
    link_url VARCHAR(500),
    alt_text VARCHAR(200),
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    start_date TIMESTAMP WITH TIME ZONE,
    end_date TIMESTAMP WITH TIME ZONE,
    click_count INTEGER DEFAULT 0,
    created_by UUID REFERENCES admin_users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ตารางประกาศ
CREATE TABLE announcements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    type VARCHAR(20) DEFAULT 'info' CHECK (
        type IN ('info', 'warning', 'success', 'error', 'promotion')
    ),
    background_color VARCHAR(7) DEFAULT '#3B82F6', -- Hex color
    text_color VARCHAR(7) DEFAULT '#FFFFFF',
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    start_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    end_date TIMESTAMP WITH TIME ZONE,
    auto_hide BOOLEAN DEFAULT false,
    hide_after_seconds INTEGER,
    created_by UUID REFERENCES admin_users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ตารางการตั้งค่าเว็บไซต์
CREATE TABLE site_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key VARCHAR(100) UNIQUE NOT NULL,
    value TEXT,
    data_type VARCHAR(20) DEFAULT 'string' CHECK (
        data_type IN ('string', 'number', 'boolean', 'json', 'text', 'url', 'color')
    ),
    category VARCHAR(50) DEFAULT 'general',
    description TEXT,
    is_public BOOLEAN DEFAULT false, -- true ถ้าสามารถแสดงใน frontend ได้
    updated_by UUID REFERENCES admin_users(id),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ตารางหน้า CMS
CREATE TABLE pages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(200) NOT NULL,
    slug VARCHAR(200) UNIQUE NOT NULL,
    content TEXT,
    excerpt TEXT,
    status VARCHAR(20) DEFAULT 'draft' CHECK (
        status IN ('draft', 'published', 'archived')
    ),
    template VARCHAR(50) DEFAULT 'default',
    meta_title VARCHAR(200),
    meta_description TEXT,
    meta_keywords TEXT,
    featured_image VARCHAR(500),
    view_count INTEGER DEFAULT 0,
    is_homepage BOOLEAN DEFAULT false,
    created_by UUID REFERENCES admin_users(id),
    updated_by UUID REFERENCES admin_users(id),
    published_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ตารางเมนูนำทาง
CREATE TABLE navigation_menus (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    location VARCHAR(50) DEFAULT 'main' CHECK (
        location IN ('main', 'footer', 'sidebar', 'mobile')
    ),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ตารางรายการเมนู
CREATE TABLE navigation_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    menu_id UUID NOT NULL REFERENCES navigation_menus(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES navigation_items(id),
    title VARCHAR(100) NOT NULL,
    url VARCHAR(500),
    page_id UUID REFERENCES pages(id),
    category_id UUID REFERENCES categories(id),
    icon VARCHAR(50),
    target VARCHAR(10) DEFAULT '_self' CHECK (target IN ('_self', '_blank')),
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    css_class VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ตารางคูปองส่วนลด
CREATE TABLE coupons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    type VARCHAR(20) DEFAULT 'fixed' CHECK (type IN ('fixed', 'percentage')),
    value DECIMAL(10,2) NOT NULL,
    minimum_order DECIMAL(10,2) DEFAULT 0,
    maximum_discount DECIMAL(10,2),
    usage_limit INTEGER,
    used_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    starts_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE,
    applicable_categories UUID[] DEFAULT '{}', -- Array of category IDs
    applicable_products UUID[] DEFAULT '{}', -- Array of product IDs
    created_by UUID REFERENCES admin_users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ตารางการใช้คูปอง
CREATE TABLE coupon_usages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    coupon_id UUID NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    discount_amount DECIMAL(10,2) NOT NULL,
    used_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(coupon_id, order_id)
);

-- สร้าง indexes
CREATE INDEX idx_banners_display_order ON banners(display_order);
CREATE INDEX idx_banners_is_active ON banners(is_active);
CREATE INDEX idx_banners_dates ON banners(start_date, end_date);
CREATE INDEX idx_banners_created_by ON banners(created_by);

CREATE INDEX idx_announcements_type ON announcements(type);
CREATE INDEX idx_announcements_is_active ON announcements(is_active);
CREATE INDEX idx_announcements_dates ON announcements(start_date, end_date);
CREATE INDEX idx_announcements_display_order ON announcements(display_order);

CREATE INDEX idx_site_settings_key ON site_settings(key);
CREATE INDEX idx_site_settings_category ON site_settings(category);
CREATE INDEX idx_site_settings_is_public ON site_settings(is_public);

CREATE INDEX idx_pages_slug ON pages(slug);
CREATE INDEX idx_pages_status ON pages(status);
CREATE INDEX idx_pages_is_homepage ON pages(is_homepage);
CREATE INDEX idx_pages_created_by ON pages(created_by);

CREATE INDEX idx_navigation_items_menu_id ON navigation_items(menu_id);
CREATE INDEX idx_navigation_items_parent_id ON navigation_items(parent_id);
CREATE INDEX idx_navigation_items_display_order ON navigation_items(display_order);

CREATE INDEX idx_coupons_code ON coupons(code);
CREATE INDEX idx_coupons_is_active ON coupons(is_active);
CREATE INDEX idx_coupons_expires_at ON coupons(expires_at);
CREATE INDEX idx_coupons_created_by ON coupons(created_by);

CREATE INDEX idx_coupon_usages_coupon_id ON coupon_usages(coupon_id);
CREATE INDEX idx_coupon_usages_user_id ON coupon_usages(user_id);
CREATE INDEX idx_coupon_usages_order_id ON coupon_usages(order_id);

-- สร้าง triggers
CREATE TRIGGER update_banners_updated_at 
    BEFORE UPDATE ON banners 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_announcements_updated_at 
    BEFORE UPDATE ON announcements 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_site_settings_updated_at 
    BEFORE UPDATE ON site_settings 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_pages_updated_at 
    BEFORE UPDATE ON pages 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_navigation_menus_updated_at 
    BEFORE UPDATE ON navigation_menus 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_navigation_items_updated_at 
    BEFORE UPDATE ON navigation_items 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_coupons_updated_at 
    BEFORE UPDATE ON coupons 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Function สำหรับตรวจสอบคูปอง
CREATE OR REPLACE FUNCTION validate_coupon(
    p_coupon_code VARCHAR(50),
    p_user_id UUID,
    p_order_total DECIMAL(10,2),
    p_category_ids UUID[] DEFAULT '{}',
    p_product_ids UUID[] DEFAULT '{}'
) RETURNS TABLE (
    is_valid BOOLEAN,
    discount_amount DECIMAL(10,2),
    error_message TEXT
) AS $$
DECLARE
    coupon_record RECORD;
    calculated_discount DECIMAL(10,2) := 0;
BEGIN
    -- ค้นหาคูปอง
    SELECT * INTO coupon_record
    FROM coupons 
    WHERE code = p_coupon_code AND is_active = true;
    
    -- ตรวจสอบคูปองมีอยู่หรือไม่
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 0::DECIMAL(10,2), 'คูปองไม่ถูกต้องหรือไม่มีอยู่';
        RETURN;
    END IF;
    
    -- ตรวจสอบวันหมดอายุ
    IF coupon_record.expires_at IS NOT NULL AND coupon_record.expires_at < NOW() THEN
        RETURN QUERY SELECT false, 0::DECIMAL(10,2), 'คูปองหมดอายุแล้ว';
        RETURN;
    END IF;
    
    -- ตรวจสอบวันเริ่มใช้
    IF coupon_record.starts_at > NOW() THEN
        RETURN QUERY SELECT false, 0::DECIMAL(10,2), 'คูปองยังไม่เริ่มใช้งาน';
        RETURN;
    END IF;
    
    -- ตรวจสอบจำนวนครั้งการใช้
    IF coupon_record.usage_limit IS NOT NULL 
       AND coupon_record.used_count >= coupon_record.usage_limit THEN
        RETURN QUERY SELECT false, 0::DECIMAL(10,2), 'คูปองถูกใช้หมดแล้ว';
        RETURN;
    END IF;
    
    -- ตรวจสอบยอดขั้นต่ำ
    IF p_order_total < coupon_record.minimum_order THEN
        RETURN QUERY SELECT false, 0::DECIMAL(10,2), 
            'ยอดสั่งซื้อไม่ถึงขั้นต่ำ ' || coupon_record.minimum_order::TEXT || ' บาท';
        RETURN;
    END IF;
    
    -- ตรวจสอบหมวดหมู่/สินค้าที่สามารถใช้ได้
    IF array_length(coupon_record.applicable_categories, 1) > 0 
       AND NOT (p_category_ids && coupon_record.applicable_categories) THEN
        RETURN QUERY SELECT false, 0::DECIMAL(10,2), 'คูปองไม่สามารถใช้กับหมวดหมู่สินค้านี้ได้';
        RETURN;
    END IF;
    
    IF array_length(coupon_record.applicable_products, 1) > 0 
       AND NOT (p_product_ids && coupon_record.applicable_products) THEN
        RETURN QUERY SELECT false, 0::DECIMAL(10,2), 'คูปองไม่สามารถใช้กับสินค้านี้ได้';
        RETURN;
    END IF;
    
    -- คำนวณส่วนลด
    IF coupon_record.type = 'fixed' THEN
        calculated_discount := coupon_record.value;
    ELSE -- percentage
        calculated_discount := p_order_total * (coupon_record.value / 100);
    END IF;
    
    -- ตรวจสอบส่วนลดสูงสุด
    IF coupon_record.maximum_discount IS NOT NULL 
       AND calculated_discount > coupon_record.maximum_discount THEN
        calculated_discount := coupon_record.maximum_discount;
    END IF;
    
    -- ส่วนลดไม่เกินยอดสั่งซื้อ
    IF calculated_discount > p_order_total THEN
        calculated_discount := p_order_total;
    END IF;
    
    RETURN QUERY SELECT true, calculated_discount, NULL::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Function สำหรับดึงการตั้งค่าเว็บไซต์
CREATE OR REPLACE FUNCTION get_site_settings(p_public_only BOOLEAN DEFAULT true)
RETURNS TABLE (
    key VARCHAR(100),
    value TEXT,
    data_type VARCHAR(20),
    category VARCHAR(50)
) AS $$
BEGIN
    RETURN QUERY
    SELECT s.key, s.value, s.data_type, s.category
    FROM site_settings s
    WHERE (NOT p_public_only OR s.is_public = true)
    ORDER BY s.category, s.key;
END;
$$ LANGUAGE plpgsql;

-- ใส่การตั้งค่าเว็บไซต์พื้นฐาน
INSERT INTO site_settings (key, value, data_type, category, description, is_public) VALUES
('site_name', 'Roblox Code Shop', 'string', 'general', 'ชื่อเว็บไซต์', true),
('site_description', 'ร้านขายรหัสเกม Roblox ราคาดี', 'text', 'general', 'คำอธิบายเว็บไซต์', true),
('site_logo', '/images/logo.png', 'url', 'appearance', 'โลโก้เว็บไซต์', true),
('site_favicon', '/images/favicon.ico', 'url', 'appearance', 'Favicon', true),
('primary_color', '#3B82F6', 'color', 'appearance', 'สีหลักของเว็บไซต์', true),
('secondary_color', '#10B981', 'color', 'appearance', 'สีรองของเว็บไซต์', true),
('contact_email', 'contact@robloxshop.com', 'string', 'contact', 'อีเมลติดต่อ', true),
('contact_phone', '0944283381', 'string', 'contact', 'เบอร์โทรติดต่อ', true),
('facebook_url', 'https://facebook.com/robloxshop', 'url', 'social', 'Facebook Fanpage', true),
('discord_url', 'https://discord.gg/robloxshop', 'url', 'social', 'Discord Server', true),
('currency', 'THB', 'string', 'payment', 'สกุลเงิน', false),
('tax_rate', '0.07', 'number', 'payment', 'อัตราภาษี', false),
('min_topup_amount', '10', 'number', 'payment', 'ยอดเติมเงินขั้นต่ำ', false),
('max_topup_amount', '50000', 'number', 'payment', 'ยอดเติมเงินสูงสุด', false),
('maintenance_mode', 'false', 'boolean', 'system', 'โหมดปิดปรุง', false),
('maintenance_message', 'เว็บไซต์อยู่ระหว่างการปิดปรุง', 'text', 'system', 'ข้อความโหมดปิดปรุง', false);

COMMENT ON TABLE banners IS 'ตารางแบนเนอร์เว็บไซต์';
COMMENT ON TABLE announcements IS 'ตารางประกาศเว็บไซต์';
COMMENT ON TABLE site_settings IS 'ตารางการตั้งค่าเว็บไซต์';
COMMENT ON TABLE pages IS 'ตารางหน้าเนื้อหา CMS';
COMMENT ON TABLE navigation_menus IS 'ตารางเมนูนำทาง';
COMMENT ON TABLE navigation_items IS 'ตารางรายการเมนู';
COMMENT ON TABLE coupons IS 'ตารางคูปองส่วนลด';
COMMENT ON TABLE coupon_usages IS 'ตารางการใช้คูปอง';

COMMENT ON FUNCTION validate_coupon IS 'ตรวจสอบและคำนวณส่วนลดจากคูปอง';
COMMENT ON FUNCTION get_site_settings IS 'ดึงการตั้งค่าเว็บไซต์';