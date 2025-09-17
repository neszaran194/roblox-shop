-- database/migrations/010_create_password_resets_table.sql
-- สร้างตารางสำหรับการรีเซ็ตรหัสผ่าน

-- ตารางสำหรับการรีเซ็ตรหัสผ่านลูกค้า
CREATE TABLE password_resets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL,
    token VARCHAR(255) UNIQUE NOT NULL,
    used BOOLEAN DEFAULT false,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    used_at TIMESTAMP WITH TIME ZONE,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ตารางสำหรับการรีเซ็ตรหัสผ่านแอดมิน
CREATE TABLE admin_password_resets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL,
    token VARCHAR(255) UNIQUE NOT NULL,
    used BOOLEAN DEFAULT false,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    used_at TIMESTAMP WITH TIME ZONE,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- สร้าง indexes
CREATE INDEX idx_password_resets_email ON password_resets(email);
CREATE INDEX idx_password_resets_token ON password_resets(token);
CREATE INDEX idx_password_resets_expires_at ON password_resets(expires_at);
CREATE INDEX idx_password_resets_used ON password_resets(used);

CREATE INDEX idx_admin_password_resets_email ON admin_password_resets(email);
CREATE INDEX idx_admin_password_resets_token ON admin_password_resets(token);
CREATE INDEX idx_admin_password_resets_expires_at ON admin_password_resets(expires_at);
CREATE INDEX idx_admin_password_resets_used ON admin_password_resets(used);

-- Function สำหรับสร้างโทเค็นรีเซ็ตรหัสผ่าน
CREATE OR REPLACE FUNCTION create_password_reset_token(
    p_email VARCHAR(255),
    p_is_admin BOOLEAN DEFAULT false,
    p_expires_hours INTEGER DEFAULT 1
) RETURNS VARCHAR(255) AS $$
DECLARE
    reset_token VARCHAR(255);
    user_exists BOOLEAN := false;
BEGIN
    -- สร้างโทเค็นแบบสุ่ม
    reset_token := encode(gen_random_bytes(32), 'hex');
    
    -- ตรวจสอบว่าอีเมลมีอยู่ในระบบ
    IF p_is_admin THEN
        SELECT EXISTS(SELECT 1 FROM admin_users WHERE email = p_email AND is_active = true) INTO user_exists;
    ELSE
        SELECT EXISTS(SELECT 1 FROM users WHERE email = p_email AND is_active = true) INTO user_exists;
    END IF;
    
    -- หากไม่มีผู้ใช้ ก็ยังสร้างโทเค็นปลอมเพื่อป้องกัน email enumeration
    -- แต่จะไม่ส่งอีเมลจริง
    
    -- ยกเลิกโทเค็นเก่าที่ยังไม่ได้ใช้
    IF p_is_admin THEN
        UPDATE admin_password_resets 
        SET used = true, used_at = NOW()
        WHERE email = p_email AND used = false;
        
        INSERT INTO admin_password_resets (email, token, expires_at)
        VALUES (p_email, reset_token, NOW() + INTERVAL '1 hour' * p_expires_hours);
    ELSE
        UPDATE password_resets 
        SET used = true, used_at = NOW()
        WHERE email = p_email AND used = false;
        
        INSERT INTO password_resets (email, token, expires_at)
        VALUES (p_email, reset_token, NOW() + INTERVAL '1 hour' * p_expires_hours);
    END IF;
    
    -- คืนค่าโทเค็นเฉพาะเมื่อพบผู้ใช้จริง
    IF user_exists THEN
        RETURN reset_token;
    ELSE
        RETURN NULL; -- ไม่ส่งโทเค็นจริงถ้าไม่มีผู้ใช้
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function สำหรับตรวจสอบและใช้โทเค็นรีเซ็ตรหัสผ่าน
CREATE OR REPLACE FUNCTION use_password_reset_token(
    p_token VARCHAR(255),
    p_new_password_hash VARCHAR(255),
    p_is_admin BOOLEAN DEFAULT false,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    reset_record RECORD;
    target_email VARCHAR(255);
    success BOOLEAN := false;
BEGIN
    -- ค้นหาและตรวจสอบโทเค็น
    IF p_is_admin THEN
        SELECT * INTO reset_record
        FROM admin_password_resets
        WHERE token = p_token 
            AND used = false 
            AND expires_at > NOW()
        FOR UPDATE;
    ELSE
        SELECT * INTO reset_record
        FROM password_resets
        WHERE token = p_token 
            AND used = false 
            AND expires_at > NOW()
        FOR UPDATE;
    END IF;
    
    IF NOT FOUND THEN
        RETURN false;
    END IF;
    
    target_email := reset_record.email;
    
    -- อัปเดตรหัสผ่านใหม่
    IF p_is_admin THEN
        UPDATE admin_users 
        SET password_hash = p_new_password_hash,
            updated_at = NOW(),
            login_attempts = 0,
            locked_until = NULL
        WHERE email = target_email;
        
        GET DIAGNOSTICS success = ROW_COUNT;
        
        -- บันทึกการใช้โทเค็น
        UPDATE admin_password_resets
        SET used = true,
            used_at = NOW(),
            ip_address = p_ip_address,
            user_agent = p_user_agent
        WHERE id = reset_record.id;
    ELSE
        UPDATE users 
        SET password_hash = p_new_password_hash,
            updated_at = NOW()
        WHERE email = target_email;
        
        GET DIAGNOSTICS success = ROW_COUNT;
        
        -- บันทึกการใช้โทเค็น
        UPDATE password_resets
        SET used = true,
            used_at = NOW(),
            ip_address = p_ip_address,
            user_agent = p_user_agent
        WHERE id = reset_record.id;
    END IF;
    
    RETURN success > 0;
END;
$$ LANGUAGE plpgsql;

-- Function สำหรับทำความสะอาดโทเค็นหมดอายุ
CREATE OR REPLACE FUNCTION cleanup_expired_password_resets()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER := 0;
    temp_count INTEGER;
BEGIN
    -- ลบโทเค็นรีเซ็ตรหัสผ่านลูกค้าที่หมดอายุ
    DELETE FROM password_resets 
    WHERE expires_at < NOW() - INTERVAL '1 day';
    
    GET DIAGNOSTICS temp_count = ROW_COUNT;
    deleted_count := deleted_count + temp_count;
    
    -- ลบโทเค็นรีเซ็ตรหัสผ่านแอดมินที่หมดอายุ
    DELETE FROM admin_password_resets 
    WHERE expires_at < NOW() - INTERVAL '1 day';
    
    GET DIAGNOSTICS temp_count = ROW_COUNT;
    deleted_count := deleted_count + temp_count;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Function สำหรับดึงสถิติการรีเซ็ตรหัสผ่าน
CREATE OR REPLACE FUNCTION get_password_reset_stats(
    p_days INTEGER DEFAULT 7
) RETURNS TABLE (
    date DATE,
    user_resets BIGINT,
    admin_resets BIGINT,
    successful_resets BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH date_series AS (
        SELECT generate_series(
            CURRENT_DATE - INTERVAL '1 day' * (p_days - 1),
            CURRENT_DATE,
            INTERVAL '1 day'
        )::DATE as date
    ),
    user_reset_stats AS (
        SELECT DATE(created_at) as date, COUNT(*) as count
        FROM password_resets
        WHERE created_at >= CURRENT_DATE - INTERVAL '1 day' * p_days
        GROUP BY DATE(created_at)
    ),
    admin_reset_stats AS (
        SELECT DATE(created_at) as date, COUNT(*) as count
        FROM admin_password_resets
        WHERE created_at >= CURRENT_DATE - INTERVAL '1 day' * p_days
        GROUP BY DATE(created_at)
    ),
    successful_stats AS (
        SELECT DATE(used_at) as date, COUNT(*) as count
        FROM (
            SELECT used_at FROM password_resets WHERE used = true AND used_at IS NOT NULL
            UNION ALL
            SELECT used_at FROM admin_password_resets WHERE used = true AND used_at IS NOT NULL
        ) combined
        WHERE used_at >= CURRENT_DATE - INTERVAL '1 day' * p_days
        GROUP BY DATE(used_at)
    )
    SELECT 
        ds.date,
        COALESCE(urs.count, 0) as user_resets,
        COALESCE(ars.count, 0) as admin_resets,
        COALESCE(ss.count, 0) as successful_resets
    FROM date_series ds
    LEFT JOIN user_reset_stats urs ON ds.date = urs.date
    LEFT JOIN admin_reset_stats ars ON ds.date = ars.date
    LEFT JOIN successful_stats ss ON ds.date = ss.date
    ORDER BY ds.date;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE password_resets IS 'ตารางการรีเซ็ตรหัสผ่านลูกค้า';
COMMENT ON TABLE admin_password_resets IS 'ตารางการรีเซ็ตรหัสผ่านแอดมิน';

COMMENT ON FUNCTION create_password_reset_token IS 'สร้างโทเค็นสำหรับรีเซ็ตรหัสผ่าน';
COMMENT ON FUNCTION use_password_reset_token IS 'ใช้โทเค็นเพื่อรีเซ็ตรหัสผ่าน';
COMMENT ON FUNCTION cleanup_expired_password_resets IS 'ทำความสะอาดโทเค็นหมดอายุ';
COMMENT ON FUNCTION get_password_reset_stats IS 'ดึงสถิติการรีเซ็ตรหัสผ่าน';