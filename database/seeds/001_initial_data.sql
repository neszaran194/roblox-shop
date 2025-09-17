-- database/seeds/001_initial_data.sql
-- ข้อมูลเริ่มต้นสำหรับระบบ

-- ===== Super Admin Account =====
INSERT INTO admin_users (
    id, username, email, password_hash, role, is_active, created_at
) VALUES (
    '00000000-0000-0000-0000-000000000001',
    'superadmin',
    'admin@robloxshop.com',
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewSBToDhqZQoe2km', -- password: admin123
    'super_admin',
    true,
    NOW()
);

-- ===== Default Categories =====
INSERT INTO categories (id, name, description, slug, display_order, is_active) VALUES
('11111111-1111-1111-1111-111111111111', 'Robux', 'รหัส Robux สำหรับเติมในเกม Roblox', 'robux', 1, true),
('11111111-1111-1111-1111-111111111112', 'Game Pass', 'รหัส Game Pass สำหรับเกมต่างๆ ใน Roblox', 'game-pass', 2, true),
('11111111-1111-1111-1111-111111111113', 'Premium', 'รหัสสมาชิก Roblox Premium', 'premium', 3, true),
('11111111-1111-1111-1111-111111111114', 'Gift Card', 'บัตรของขวัญ Roblox', 'gift-card', 4, true),
('11111111-1111-1111-1111-111111111115', 'Accessories', 'รหัสไอเทมและอุปกรณ์ตกแต่งตัวละคร', 'accessories', 5, true);

-- ===== Sample Products =====
INSERT INTO products (id, category_id, name, description, price, stock, image_urls, is_featured, is_popular, is_active, slug) VALUES
-- Robux Products
('22222222-2222-2222-2222-222222222221', '11111111-1111-1111-1111-111111111111', 
 '80 Robux', 'รหัส Robux จำนวน 80 สำหรับใช้ในเกม Roblox', 39.00, 100, 
 ARRAY['/images/products/robux-80.jpg'], true, true, true, '80-robux'),
 
('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 
 '400 Robux', 'รหัส Robux จำนวน 400 สำหรับใช้ในเกม Roblox', 179.00, 50, 
 ARRAY['/images/products/robux-400.jpg'], true, true, true, '400-robux'),
 
('22222222-2222-2222-2222-222222222223', '11111111-1111-1111-1111-111111111111', 
 '800 Robux', 'รหัส Robux จำนวน 800 สำหรับใช้ในเกม Roblox', 349.00, 25, 
 ARRAY['/images/products/robux-800.jpg'], true, true, true, '800-robux'),

-- Premium Products
('22222222-2222-2222-2222-222222222224', '11111111-1111-1111-1111-111111111113', 
 'Roblox Premium 1 เดือน', 'สมาชิก Roblox Premium ระยะเวลา 1 เดือน', 159.00, 20, 
 ARRAY['/images/products/premium-1month.jpg'], true, false, true, 'premium-1-month'),

-- Game Pass Products  
('22222222-2222-2222-2222-222222222225', '11111111-1111-1111-1111-111111111112', 
 'Adopt Me! Fly Potion', 'Game Pass สำหรับ Fly Potion ในเกม Adopt Me!', 89.00, 15, 
 ARRAY['/images/products/adoptme-fly.jpg'], false, true, true, 'adopt-me-fly-potion'),

-- Gift Card Products
('22222222-2222-2222-2222-222222222226', '11111111-1111-1111-1111-111111111114', 
 'Roblox Gift Card 200 บาท', 'บัตรของขวัญ Roblox มูลค่า 200 บาท', 200.00, 10, 
 ARRAY['/images/products/giftcard-200.jpg'], false, false, true, 'gift-card-200');

-- ===== Sample Product Codes =====
-- สำหรับ 80 Robux (10 รหัส)
INSERT INTO product_codes (product_id, code) VALUES
('22222222-2222-2222-2222-222222222221', 'ROBUX80001'),
('22222222-2222-2222-2222-222222222221', 'ROBUX80002'),
('22222222-2222-2222-2222-222222222221', 'ROBUX80003'),
('22222222-2222-2222-2222-222222222221', 'ROBUX80004'),
('22222222-2222-2222-2222-222222222221', 'ROBUX80005'),
('22222222-2222-2222-2222-222222222221', 'ROBUX80006'),
('22222222-2222-2222-2222-222222222221', 'ROBUX80007'),
('22222222-2222-2222-2222-222222222221', 'ROBUX80008'),
('22222222-2222-2222-2222-222222222221', 'ROBUX80009'),
('22222222-2222-2222-2222-222222222221', 'ROBUX80010');

-- สำหรับ 400 Robux (5 รหัส)
INSERT INTO product_codes (product_id, code) VALUES
('22222222-2222-2222-2222-222222222222', 'ROBUX400001'),
('22222222-2222-2222-2222-222222222222', 'ROBUX400002'),
('22222222-2222-2222-2222-222222222222', 'ROBUX400003'),
('22222222-2222-2222-2222-222222222222', 'ROBUX400004'),
('22222222-2222-2222-2222-222222222222', 'ROBUX400005');

-- ===== Sample Banners =====
INSERT INTO banners (title, image_url, link_url, display_order, is_active) VALUES
('ยินดีต้อนรับสู่ Roblox Code Shop', '/images/banners/welcome-banner.jpg', '/', 1, true),
('โปรโมชั่น Robux ลดราคาพิเศษ!', '/images/banners/robux-promotion.jpg', '/category/robux', 2, true),
('Premium Membership เริ่มต้นเพียง 159 บาท', '/images/banners/premium-offer.jpg', '/category/premium', 3, true);

-- ===== Sample Announcements =====
INSERT INTO announcements (title, content, type, background_color, text_color, display_order, is_active) VALUES
('🎉 เปิดให้บริการแล้ว!', 'ยินดีต้อนรับสู่ร้านขายรหัสเกม Roblox ที่ดีที่สุด', 'success', '#10B981', '#FFFFFF', 1, true),
('💳 รองรับการชำระเงินผ่าน PromptPay และ TrueWallet', 'เติมเงินง่าย ปลอดภัย ได้เครดิตทันที', 'info', '#3B82F6', '#FFFFFF', 2, true),
('🔥 โปรโมชั่นพิเศษสำหรับสมาชิกใหม่!', 'สมัครวันนี้ รับส่วนลดทันที 10%', 'promotion', '#F59E0B', '#FFFFFF', 3, true);

-- ===== Navigation Menus =====
INSERT INTO navigation_menus (id, name, location, is_active) VALUES
('33333333-3333-3333-3333-333333333331', 'หลัก', 'main', true),
('33333333-3333-3333-3333-333333333332', 'ฟุตเตอร์', 'footer', true);

-- Main Menu Items
INSERT INTO navigation_items (menu_id, title, url, display_order, is_active) VALUES
('33333333-3333-3333-3333-333333333331', 'หน้าแรก', '/', 1, true),
('33333333-3333-3333-3333-333333333331', 'ร้านค้า', '/shop', 2, true),
('33333333-3333-3333-3333-333333333331', 'ติดต่อเรา', '/contact', 3, true);

-- Category Menu Items
INSERT INTO navigation_items (menu_id, title, category_id, display_order, is_active) VALUES
('33333333-3333-3333-3333-333333333331', 'Robux', '11111111-1111-1111-1111-111111111111', 4, true),
('33333333-3333-3333-3333-333333333331', 'Game Pass', '11111111-1111-1111-1111-111111111112', 5, true),
('33333333-3333-3333-3333-333333333331', 'Premium', '11111111-1111-1111-1111-111111111113', 6, true);

-- Footer Menu Items
INSERT INTO navigation_items (menu_id, title, url, display_order, is_active) VALUES
('33333333-3333-3333-3333-333333333332', 'เกี่ยวกับเรา', '/about', 1, true),
('33333333-3333-3333-3333-333333333332', 'นโยบายความเป็นส่วนตัว', '/privacy', 2, true),
('33333333-3333-3333-3333-333333333332', 'เงื่อนไขการใช้งาน', '/terms', 3, true),
('33333333-3333-3333-3333-333333333332', 'คำถามที่พบบ่อย', '/faq', 4, true);

-- ===== Sample Coupons =====
INSERT INTO coupons (code, name, description, type, value, minimum_order, usage_limit, is_active, expires_at) VALUES
('WELCOME10', 'ส่วนลดสมาชิกใหม่ 10%', 'รับส่วนลด 10% สำหรับการสั่งซื้อแรก', 'percentage', 10.00, 50.00, 100, true, NOW() + INTERVAL '30 days'),
('SAVE50', 'ลด 50 บาท', 'ส่วนลด 50 บาทเมื่อซื้อครบ 500 บาท', 'fixed', 50.00, 500.00, 50, true, NOW() + INTERVAL '15 days'),
('ROBUX20', 'ส่วนลด Robux 20%', 'ส่วนลด 20% สำหรับสินค้า Robux เท่านั้น', 'percentage', 20.00, 100.00, NULL, true, NOW() + INTERVAL '7 days');

-- กำหนดคูปอง ROBUX20 ใช้ได้เฉพาะหมวดหมู่ Robux
UPDATE coupons 
SET applicable_categories = ARRAY['11111111-1111-1111-1111-111111111111']
WHERE code = 'ROBUX20';

-- ===== Sample Test User =====
INSERT INTO users (
    id, username, email, password_hash, credits, is_active
) VALUES (
    '44444444-4444-4444-4444-444444444444',
    'testuser',
    'test@example.com',
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewSBToDhqZQoe2km', -- password: test123
    1000.00,
    true
);

-- ===== Sample Pages =====
INSERT INTO pages (title, slug, content, status, meta_title, meta_description, is_homepage) VALUES
('เกี่ยวกับเรา', 'about', 
'<h1>เกี่ยวกับ Roblox Code Shop</h1>
<p>เราเป็นร้านขายรหัสเกม Roblox ที่เชื่อถือได้ มีรหัสเกมหลากหลายประเภท ราคาดี บริการดี</p>
<h2>ทำไมต้องเลือกเรา?</h2>
<ul>
<li>รหัสของแท้ 100%</li>
<li>ส่งรหัสรวดเร็วภายใน 5 นาที</li>
<li>บริการลูกค้า 24/7</li>
<li>ระบบชำระเงินปลอดภัย</li>
</ul>', 
'published', 'เกี่ยวกับเรา - Roblox Code Shop', 
'ร้านขายรหัสเกม Roblox ที่เชื่อถือได้ รหัสของแท้ ราคาดี บริการรวดเร็ว', false),

('นโยบายความเป็นส่วนตัว', 'privacy',
'<h1>นโยบายความเป็นส่วนตัว</h1>
<p>เราให้ความสำคัญกับความเป็นส่วนตัวของลูกค้า</p>
<h2>ข้อมูลที่เราเก็บรวบรวม</h2>
<p>เราเก็บรวบรวมข้อมูลที่จำเป็นสำหรับการให้บริการเท่านั้น</p>
<h2>การใช้ข้อมูล</h2>
<p>ข้อมูลของคุณจะใช้สำหรับการประมวลผลคำสั่งซื้อและการติดต่อสื่อสารเท่านั้น</p>',
'published', 'นโยบายความเป็นส่วนตัว - Roblox Code Shop',
'นโยบายความเป็นส่วนตัวของ Roblox Code Shop', false),

('เงื่อนไขการใช้งาน', 'terms',
'<h1>เงื่อนไขการใช้งาน</h1>
<p>การใช้งานเว็บไซต์นี้ถือว่าคุณยอมรับเงื่อนไขดังต่อไปนี้</p>
<h2>การสั่งซื้อ</h2>
<p>คำสั่งซื้อจะสมบูรณ์เมื่อได้รับการชำระเงินแล้วเท่านั้น</p>
<h2>การคืนเงิน</h2>
<p>สินค้าดิจิทัลไม่สามารถคืนได้หลังจากส่งรหัสแล้ว</p>',
'published', 'เงื่อนไขการใช้งาน - Roblox Code Shop',
'เงื่อนไขการใช้งานเว็บไซต์ Roblox Code Shop', false),

('คำถามที่พบบ่อย', 'faq',
'<h1>คำถามที่พบบ่อย (FAQ)</h1>
<h2>รหัสที่ซื้อมาใช้งานได้จริงไหม?</h2>
<p>ใช่ เรามีรหัสของแท้ 100% และรับประกันการใช้งาน</p>
<h2>ใช้เวลานานแค่ไหนถึงจะได้รหัส?</h2>
<p>ปกติจะได้รหัสภายใน 5 นาทีหลังชำระเงิน</p>
<h2>ถ้ารหัสไม่สามารถใช้งานได้จะทำอย่างไร?</h2>
<p>ติดต่อเรามาทันที เราจะเปลี่ยนรหัสใหม่ให้ฟรี</p>
<h2>รองรับการชำระเงินแบบไหนบ้าง?</h2>
<p>รองรับ PromptPay และ TrueWallet Voucher</p>',
'published', 'คำถามที่พบบ่อย - Roblox Code Shop',
'คำถามที่พบบ่อยเกี่ยวกับการซื้อรหัสเกม Roblox', false);

-- ===== Email Templates (เพิ่มเติม) =====
INSERT INTO email_templates (name, subject, body_html, body_text, variables) VALUES
('password_reset', 'รีเซ็ตรหัสผ่าน - Roblox Code Shop',
'<h1>รีเซ็ตรหัสผ่าน</h1>
<p>สวัสดี {{username}}</p>
<p>คุณได้ทำการขอรีเซ็ตรหัสผ่าน กรุณาคลิกลิงก์ด้านล่างเพื่อตั้งรหัสผ่านใหม่:</p>
<p><a href="{{reset_link}}" style="background: #3B82F6; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">รีเซ็ตรหัสผ่าน</a></p>
<p>ลิงก์นี้จะหมดอายุใน 1 ชั่วโมง</p>
<p>หากคุณไม่ได้ขอรีเซ็ตรหัสผ่าน กรุณาเพิกเฉยต่ออีเมลนี้</p>',
'สวัสดี {{username}} คุณได้ทำการขอรีเซ็ตรหัสผ่าน กรุณาเปิดลิงก์: {{reset_link}}',
'{"username": "ชื่อผู้ใช้", "reset_link": "ลิงก์รีเซ็ตรหัสผ่าน"}'),

('order_failed', 'คำสั่งซื้อล้มเหลว - หมายเลข {{order_number}}',
'<h1>คำสั่งซื้อล้มเหลว</h1>
<p>สวัสดี {{username}}</p>
<p>เสียใจด้วย คำสั่งซื้อหมายเลข {{order_number}} ของคุณล้มเหลว</p>
<p>สาเหตุ: {{reason}}</p>
<p>เครดิตจำนวน {{amount}} บาท ได้ถูกคืนเข้าบัญชีของคุณแล้ว</p>
<p>หากมีข้อสงสัย กรุณาติดต่อทีมงานของเรา</p>',
'คำสั่งซื้อ {{order_number}} ล้มเหลว สาเหตุ: {{reason}} เครดิต {{amount}} บาท ถูกคืนแล้ว',
'{"username": "ชื่อผู้ใช้", "order_number": "หมายเลขคำสั่งซื้อ", "reason": "สาเหตุ", "amount": "จำนวนเงิน"}');

-- ===== Sample Credit Transactions =====
-- เติมเงินให้ test user
INSERT INTO credit_transactions (
    user_id, transaction_type, amount, balance_before, balance_after, 
    description, reference_type
) VALUES (
    '44444444-4444-4444-4444-444444444444', 
    'deposit', 1000.00, 0.00, 1000.00,
    'เติมเงินเริ่มต้นสำหรับทดสอบ', 'manual'
);

-- ===== Update Products Stock to Match Codes =====
UPDATE products SET stock = (
    SELECT COUNT(*) 
    FROM product_codes 
    WHERE product_codes.product_id = products.id 
        AND is_used = false
);

-- ===== Sample Notification Settings for Test User =====
-- (จะถูกสร้างอัตโนมัติผ่าน trigger เมื่อสร้าง user)

-- ===== Refresh Materialized Views =====
REFRESH MATERIALIZED VIEW top_selling_products;

-- ===== Success Message =====
DO $ 
BEGIN 
    RAISE NOTICE 'Initial data seeded successfully!';
    RAISE NOTICE 'Super Admin: username=superadmin, password=admin123';
    RAISE NOTICE 'Test User: username=testuser, password=test123, credits=1000.00';
    RAISE NOTICE 'Products: % active products created', (SELECT COUNT(*) FROM products WHERE is_active = true);
    RAISE NOTICE 'Categories: % categories created', (SELECT COUNT(*) FROM categories WHERE is_active = true);
    RAISE NOTICE 'Product Codes: % codes available', (SELECT COUNT(*) FROM product_codes WHERE is_used = false);
END $;