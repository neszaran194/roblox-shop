-- database/migrations/009_create_notifications_table.sql
-- สร้างตารางระบบการแจ้งเตือน

-- ตารางการแจ้งเตือนสำหรับลูกค้า
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(30) NOT NULL CHECK (
        type IN ('order_completed', 'code_delivered', 'payment_success', 'promotion', 'system', 'welcome')
    ),
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    data JSONB DEFAULT '{}', -- ข้อมูลเพิ่มเติม (order_id, product_id, etc.)
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ตารางการตั้งค่าการแจ้งเตือนของลูกค้า
CREATE TABLE notification_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    email_notifications BOOLEAN DEFAULT true,
    push_notifications BOOLEAN DEFAULT true,
    order_notifications BOOLEAN DEFAULT true,
    promotion_notifications BOOLEAN DEFAULT true,
    system_notifications BOOLEAN DEFAULT true,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id)
);

-- ตารางการแจ้งเตือนสำหรับแอดมิน
CREATE TABLE admin_notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type VARCHAR(30) NOT NULL CHECK (
        type IN ('new_order', 'low_stock', 'payment_received', 'system_error', 'user_registered', 'failed_delivery')
    ),
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    severity VARCHAR(10) DEFAULT 'info' CHECK (
        severity IN ('low', 'info', 'warning', 'high', 'critical')
    ),
    data JSONB DEFAULT '{}',
    is_read BOOLEAN DEFAULT false,
    read_by UUID REFERENCES admin_users(id),
    read_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ตารางเทมเพลตอีเมล
CREATE TABLE email_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) UNIQUE NOT NULL,
    subject VARCHAR(200) NOT NULL,
    body_html TEXT NOT NULL,
    body_text TEXT,
    variables JSONB DEFAULT '{}', -- ตัวแปรที่สามารถใช้ในเทมเพลต
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES admin_users(id),
    updated_by UUID REFERENCES admin_users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ตารางประวัติการส่งอีเมล
CREATE TABLE email_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    template_id UUID REFERENCES email_templates(id),
    user_id UUID REFERENCES users(id),
    email_to VARCHAR(255) NOT NULL,
    subject VARCHAR(200) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' CHECK (
        status IN ('pending', 'sent', 'failed', 'bounced')
    ),
    error_message TEXT,
    sent_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ตารางสำหรับ Push Notification Tokens (สำหรับแอป Mobile ในอนาคต)
CREATE TABLE push_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(500) NOT NULL,
    platform VARCHAR(20) CHECK (platform IN ('android', 'ios', 'web')),
    is_active BOOLEAN DEFAULT true,
    last_used TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, token)
);

-- สร้าง indexes
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_type ON notifications(type);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX idx_notifications_expires_at ON notifications(expires_at);

CREATE INDEX idx_admin_notifications_type ON admin_notifications(type);
CREATE INDEX idx_admin_notifications_severity ON admin_notifications(severity);
CREATE INDEX idx_admin_notifications_is_read ON admin_notifications(is_read);
CREATE INDEX idx_admin_notifications_created_at ON admin_notifications(created_at DESC);

CREATE INDEX idx_email_templates_name ON email_templates(name);
CREATE INDEX idx_email_templates_is_active ON email_templates(is_active);

CREATE INDEX idx_email_logs_user_id ON email_logs(user_id);
CREATE INDEX idx_email_logs_status ON email_logs(status);
CREATE INDEX idx_email_logs_created_at ON email_logs(created_at DESC);
CREATE INDEX idx_email_logs_template_id ON email_logs(template_id);

CREATE INDEX idx_push_tokens_user_id ON push_tokens(user_id);
CREATE INDEX idx_push_tokens_platform ON push_tokens(platform);
CREATE INDEX idx_push_tokens_is_active ON push_tokens(is_active);

-- สร้าง triggers
CREATE TRIGGER update_notification_settings_updated_at 
    BEFORE UPDATE ON notification_settings 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_email_templates_updated_at 
    BEFORE UPDATE ON email_templates 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_push_tokens_updated_at 
    BEFORE UPDATE ON push_tokens 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Function สำหรับสร้างการแจ้งเตือน
CREATE OR REPLACE FUNCTION create_notification(
    p_user_id UUID,
    p_type VARCHAR(30),
    p_title VARCHAR(200),
    p_message TEXT,
    p_data JSONB DEFAULT '{}',
    p_expires_hours INTEGER DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    notification_id UUID;
    expires_at TIMESTAMP WITH TIME ZONE;
BEGIN
    -- คำนวณวันหมดอายุ
    IF p_expires_hours IS NOT NULL THEN
        expires_at := NOW() + INTERVAL '1 hour' * p_expires_hours;
    END IF;
    
    -- สร้างการแจ้งเตือน
    INSERT INTO notifications (user_id, type, title, message, data, expires_at)
    VALUES (p_user_id, p_type, p_title, p_message, p_data, expires_at)
    RETURNING id INTO notification_id;
    
    RETURN notification_id;
END;
$$ LANGUAGE plpgsql;

-- Function สำหรับสร้างการแจ้งเตือนแอดมิน
CREATE OR REPLACE FUNCTION create_admin_notification(
    p_type VARCHAR(30),
    p_title VARCHAR(200),
    p_message TEXT,
    p_severity VARCHAR(10) DEFAULT 'info',
    p_data JSONB DEFAULT '{}',
    p_expires_hours INTEGER DEFAULT 24
) RETURNS UUID AS $$
DECLARE
    notification_id UUID;
    expires_at TIMESTAMP WITH TIME ZONE;
BEGIN
    -- คำนวณวันหมดอายุ
    expires_at := NOW() + INTERVAL '1 hour' * p_expires_hours;
    
    -- สร้างการแจ้งเตือน
    INSERT INTO admin_notifications (type, title, message, severity, data, expires_at)
    VALUES (p_type, p_title, p_message, p_severity, p_data, expires_at)
    RETURNING id INTO notification_id;
    
    RETURN notification_id;
END;
$$ LANGUAGE plpgsql;

-- Function สำหรับทำเครื่องหมายว่าอ่านแล้ว
CREATE OR REPLACE FUNCTION mark_notifications_read(
    p_user_id UUID,
    p_notification_ids UUID[] DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    IF p_notification_ids IS NULL THEN
        -- อ่านทั้งหมด
        UPDATE notifications 
        SET is_read = true, 
            read_at = NOW()
        WHERE user_id = p_user_id 
            AND is_read = false;
    ELSE
        -- อ่านเฉพาะที่ระบุ
        UPDATE notifications 
        SET is_read = true, 
            read_at = NOW()
        WHERE user_id = p_user_id 
            AND id = ANY(p_notification_ids)
            AND is_read = false;
    END IF;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$ LANGUAGE plpgsql;

-- Function สำหรับทำความสะอาดการแจ้งเตือนเก่า
CREATE OR REPLACE FUNCTION cleanup_old_notifications()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- ลบการแจ้งเตือนที่หมดอายุ
    DELETE FROM notifications 
    WHERE expires_at IS NOT NULL 
        AND expires_at < NOW();
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- ลบการแจ้งเตือนแอดมินที่หมดอายุ
    DELETE FROM admin_notifications 
    WHERE expires_at IS NOT NULL 
        AND expires_at < NOW();
    
    -- ลบการแจ้งเตือนที่อ่านแล้วและเก่ามาก (เก็บไว้ 30 วัน)
    DELETE FROM notifications 
    WHERE is_read = true 
        AND read_at < NOW() - INTERVAL '30 days';
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Function สำหรับดึงการแจ้งเตือนที่ยังไม่อ่าน
CREATE OR REPLACE FUNCTION get_unread_notifications(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    id UUID,
    type VARCHAR(30),
    title VARCHAR(200),
    message TEXT,
    data JSONB,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT n.id, n.type, n.title, n.message, n.data, n.created_at
    FROM notifications n
    WHERE n.user_id = p_user_id 
        AND n.is_read = false
        AND (n.expires_at IS NULL OR n.expires_at > NOW())
    ORDER BY n.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Trigger สำหรับสร้างการตั้งค่าการแจ้งเตือนเมื่อมีผู้ใช้ใหม่
CREATE OR REPLACE FUNCTION create_default_notification_settings()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO notification_settings (user_id)
    VALUES (NEW.id);
    
    -- สร้างการแจ้งเตือนต้อนรับ
    PERFORM create_notification(
        NEW.id,
        'welcome',
        'ยินดีต้อนรับสู่ Roblox Code Shop!',
        'ขอบคุณที่สมัครสมาชิกกับเรา เริ่มต้นช้อปปิ้งรหัสเกมโปรดของคุณได้เลย!',
        jsonb_build_object('username', NEW.username)
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER create_notification_settings_on_user_register
    AFTER INSERT ON users
    FOR EACH ROW
    EXECUTE FUNCTION create_default_notification_settings();

-- ใส่เทมเพลตอีเมลพื้นฐาน
INSERT INTO email_templates (name, subject, body_html, body_text, variables) VALUES
('welcome', 'ยินดีต้อนรับสู่ Roblox Code Shop', 
'<h1>สวัสดี {{username}}!</h1><p>ยินดีต้อนรับสู่ Roblox Code Shop ร้านขายรหัสเกมโรบล็อกซ์ที่ดีที่สุด</p>', 
'สวัสดี {{username}}! ยินดีต้อนรับสู่ Roblox Code Shop', 
'{"username": "ชื่อผู้ใช้"}'),

('order_completed', 'คำสั่งซื้อเสร็จสิ้นแล้ว - หมายเลข {{order_number}}',
'<h1>คำสั่งซื้อเสร็จสิ้น!</h1><p>รหัสเกมของคุณพร้อมใช้งานแล้ว หมายเลขคำสั่งซื้อ: {{order_number}}</p>',
'คำสั่งซื้อเสร็จสิ้น! รหัสเกมของคุณพร้อมใช้งานแล้ว หมายเลขคำสั่งซื้อ: {{order_number}}',
'{"order_number": "หมายเลขคำสั่งซื้อ", "username": "ชื่อผู้ใช้"}'),

('payment_success', 'เติมเงินเรียบร้อย - {{amount}} บาท',
'<h1>เติมเงินสำเร็จ!</h1><p>คุณได้เติมเงินจำนวน {{amount}} บาท เข้าระบบเรียบร้อยแล้ว</p>',
'เติมเงินสำเร็จ! คุณได้เติมเงินจำนวน {{amount}} บาท เข้าระบบเรียบร้อยแล้ว',
'{"amount": "จำนวนเงิน", "username": "ชื่อผู้ใช้", "balance": "ยอดคงเหลือ"}');

COMMENT ON TABLE notifications IS 'ตารางการแจ้งเตือนสำหรับลูกค้า';
COMMENT ON TABLE notification_settings IS 'ตารางการตั้งค่าการแจ้งเตือนของลูกค้า';
COMMENT ON TABLE admin_notifications IS 'ตารางการแจ้งเตือนสำหรับแอดมิน';
COMMENT ON TABLE email_templates IS 'ตารางเทมเพลตอีเมล';
COMMENT ON TABLE email_logs IS 'ตารางประวัติการส่งอีเมล';
COMMENT ON TABLE push_tokens IS 'ตารางโทเค็นสำหรับ Push Notification';

COMMENT ON FUNCTION create_notification IS 'สร้างการแจ้งเตือนสำหรับลูกค้า';
COMMENT ON FUNCTION create_admin_notification IS 'สร้างการแจ้งเตือนสำหรับแอดมิน';
COMMENT ON FUNCTION mark_notifications_read IS 'ทำเครื่องหมายการแจ้งเตือนว่าอ่านแล้ว';
COMMENT ON FUNCTION cleanup_old_notifications IS 'ทำความสะอาดการแจ้งเตือนเก่า';
COMMENT ON FUNCTION get_unread_notifications IS 'ดึงการแจ้งเตือนที่ยังไม่อ่าน';