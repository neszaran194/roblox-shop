-- database/migrations/007_create_admin_users_table.sql
-- สร้างตารางสำหรับแอดมินและระบบสิทธิ์

CREATE TABLE admin_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'staff' CHECK (
        role IN ('super_admin', 'admin', 'staff', 'moderator')
    ),
    permissions JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMP WITH TIME ZONE,
    login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMP WITH TIME ZONE,
    two_factor_enabled BOOLEAN DEFAULT false,
    two_factor_secret VARCHAR(100),
    created_by UUID REFERENCES admin_users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ตารางกำหนดสิทธิ์ตาม Role
CREATE TABLE role_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role VARCHAR(20) NOT NULL,
    permission VARCHAR(50) NOT NULL,
    is_granted BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(role, permission)
);

-- ตารางบันทึกการเข้าใช้งาน Admin
CREATE TABLE admin_login_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_user_id UUID REFERENCES admin_users(id) ON DELETE SET NULL,
    username VARCHAR(50),
    ip_address INET,
    user_agent TEXT,
    login_status VARCHAR(20) CHECK (
        login_status IN ('success', 'failed', 'locked', 'invalid_2fa')
    ),
    session_id VARCHAR(100),
    logout_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ตารางบันทึกกิจกรรม Admin
CREATE TABLE activity_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_user_id UUID REFERENCES admin_users(id) ON DELETE SET NULL,
    admin_username VARCHAR(50),
    action VARCHAR(50) NOT NULL,
    table_name VARCHAR(50),
    record_id UUID,
    old_data JSONB,
    new_data JSONB,
    description TEXT,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ตารางเซสชั่น Admin
CREATE TABLE admin_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_user_id UUID NOT NULL REFERENCES admin_users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    refresh_token VARCHAR(255) UNIQUE,
    ip_address INET,
    user_agent TEXT,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- สร้าง indexes
CREATE INDEX idx_admin_users_username ON admin_users(username);
CREATE INDEX idx_admin_users_email ON admin_users(email);
CREATE INDEX idx_admin_users_role ON admin_users(role);
CREATE INDEX idx_admin_users_is_active ON admin_users(is_active);

CREATE INDEX idx_role_permissions_role ON role_permissions(role);
CREATE INDEX idx_role_permissions_permission ON role_permissions(permission);

CREATE INDEX idx_admin_login_logs_admin_user_id ON admin_login_logs(admin_user_id);
CREATE INDEX idx_admin_login_logs_ip_address ON admin_login_logs(ip_address);
CREATE INDEX idx_admin_login_logs_created_at ON admin_login_logs(created_at DESC);

CREATE INDEX idx_activity_logs_admin_user_id ON activity_logs(admin_user_id);
CREATE INDEX idx_activity_logs_action ON activity_logs(action);
CREATE INDEX idx_activity_logs_table_name ON activity_logs(table_name);
CREATE INDEX idx_activity_logs_created_at ON activity_logs(created_at DESC);

CREATE INDEX idx_admin_sessions_admin_user_id ON admin_sessions(admin_user_id);
CREATE INDEX idx_admin_sessions_session_token ON admin_sessions(session_token);
CREATE INDEX idx_admin_sessions_expires_at ON admin_sessions(expires_at);
CREATE INDEX idx_admin_sessions_is_active ON admin_sessions(is_active);

-- สร้าง triggers
CREATE TRIGGER update_admin_users_updated_at 
    BEFORE UPDATE ON admin_users 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_admin_sessions_updated_at 
    BEFORE UPDATE ON admin_sessions 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Function สำหรับตรวจสอบสิทธิ์
CREATE OR REPLACE FUNCTION check_admin_permission(
    p_admin_id UUID,
    p_permission VARCHAR(50)
) RETURNS BOOLEAN AS $$
DECLARE
    admin_role VARCHAR(20);
    has_permission BOOLEAN := false;
BEGIN
    -- ดึง role ของแอดมิน
    SELECT role INTO admin_role
    FROM admin_users 
    WHERE id = p_admin_id AND is_active = true;
    
    IF NOT FOUND THEN
        RETURN false;
    END IF;
    
    -- Super Admin มีสิทธิ์ทุกอย่าง
    IF admin_role = 'super_admin' THEN
        RETURN true;
    END IF;
    
    -- ตรวจสอบสิทธิ์จาก role_permissions
    SELECT COALESCE(is_granted, false) INTO has_permission
    FROM role_permissions 
    WHERE role = admin_role AND permission = p_permission;
    
    RETURN COALESCE(has_permission, false);
END;
$$ LANGUAGE plpgsql;

-- Function สำหรับบันทึกกิจกรรม
CREATE OR REPLACE FUNCTION log_admin_activity(
    p_admin_id UUID,
    p_action VARCHAR(50),
    p_table_name VARCHAR(50) DEFAULT NULL,
    p_record_id UUID DEFAULT NULL,
    p_old_data JSONB DEFAULT NULL,
    p_new_data JSONB DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    log_id UUID;
    admin_username VARCHAR(50);
BEGIN
    -- ดึงชื่อผู้ใช้ของแอดมิน
    SELECT username INTO admin_username
    FROM admin_users 
    WHERE id = p_admin_id;
    
    -- บันทึกกิจกรรม
    INSERT INTO activity_logs (
        admin_user_id, admin_username, action, table_name, record_id,
        old_data, new_data, description, ip_address, user_agent
    ) VALUES (
        p_admin_id, admin_username, p_action, p_table_name, p_record_id,
        p_old_data, p_new_data, p_description, p_ip_address, p_user_agent
    ) RETURNING id INTO log_id;
    
    RETURN log_id;
END;
$$ LANGUAGE plpgsql;

-- Function สำหรับทำความสะอาดเซสชั่นหมดอายุ
CREATE OR REPLACE FUNCTION cleanup_expired_admin_sessions()
RETURNS INTEGER AS $$
DECLARE
    expired_count INTEGER;
BEGIN
    UPDATE admin_sessions 
    SET is_active = false,
        updated_at = NOW()
    WHERE expires_at < NOW() 
        AND is_active = true;
    
    GET DIAGNOSTICS expired_count = ROW_COUNT;
    
    -- ลบเซสชั่นเก่าที่หมดอายุแล้วนาน
    DELETE FROM admin_sessions 
    WHERE expires_at < NOW() - INTERVAL '7 days';
    
    RETURN expired_count;
END;
$$ LANGUAGE plpgsql;

-- ใส่สิทธิ์พื้นฐานสำหรับแต่ละ Role
INSERT INTO role_permissions (role, permission, is_granted) VALUES
-- Super Admin (ไม่ต้องกำหนดเพราะมีสิทธิ์ทุกอย่าง)

-- Admin permissions
('admin', 'dashboard.view', true),
('admin', 'products.view', true),
('admin', 'products.create', true),
('admin', 'products.edit', true),
('admin', 'products.delete', true),
('admin', 'orders.view', true),
('admin', 'orders.edit', true),
('admin', 'orders.process', true),
('admin', 'users.view', true),
('admin', 'users.edit', true),
('admin', 'financial.view', true),
('admin', 'financial.manage', true),
('admin', 'reports.view', true),
('admin', 'content.manage', true),
('admin', 'settings.manage', false),
('admin', 'admin.manage', false),

-- Staff permissions
('staff', 'dashboard.view', true),
('staff', 'products.view', true),
('staff', 'products.edit', false),
('staff', 'orders.view', true),
('staff', 'orders.process', true),
('staff', 'users.view', true),
('staff', 'users.edit', false),
('staff', 'financial.view', false),
('staff', 'reports.view', false),
('staff', 'content.manage', false),

-- Moderator permissions
('moderator', 'dashboard.view', true),
('moderator', 'products.view', true),
('moderator', 'orders.view', true),
('moderator', 'users.view', true),
('moderator', 'content.manage', true),
('moderator', 'reports.view', true);

COMMENT ON TABLE admin_users IS 'ตารางผู้ดูแลระบบ';
COMMENT ON TABLE role_permissions IS 'ตารางกำหนดสิทธิ์ตาม Role';
COMMENT ON TABLE admin_login_logs IS 'ตารางบันทึกการเข้าใช้งานแอดมิน';
COMMENT ON TABLE activity_logs IS 'ตารางบันทึกกิจกรรมแอดมิน';
COMMENT ON TABLE admin_sessions IS 'ตารางเซสชั่นแอดมิน';

COMMENT ON FUNCTION check_admin_permission IS 'ตรวจสอบสิทธิ์ของแอดมิน';
COMMENT ON FUNCTION log_admin_activity IS 'บันทึกกิจกรรมของแอดมิน';
COMMENT ON FUNCTION cleanup_expired_admin_sessions IS 'ทำความสะอาดเซสชั่นหมดอายุ';