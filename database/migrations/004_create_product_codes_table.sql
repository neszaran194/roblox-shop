-- database/migrations/004_create_product_codes_table.sql
-- สร้างตาราง product_codes สำหรับเก็บรหัสเกมจริง

CREATE TABLE product_codes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    code VARCHAR(500) NOT NULL,
    is_used BOOLEAN DEFAULT false,
    reserved_until TIMESTAMP WITH TIME ZONE,
    used_by UUID REFERENCES users(id),
    used_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- สร้าง indexes
CREATE INDEX idx_product_codes_product_id ON product_codes(product_id);
CREATE INDEX idx_product_codes_is_used ON product_codes(is_used);
CREATE INDEX idx_product_codes_reserved_until ON product_codes(reserved_until);
CREATE INDEX idx_product_codes_used_by ON product_codes(used_by);
CREATE INDEX idx_product_codes_created_at ON product_codes(created_at);

-- สร้าง unique constraint สำหรับ code
CREATE UNIQUE INDEX idx_product_codes_code_unique ON product_codes(code);

-- สร้าง trigger สำหรับ updated_at
CREATE TRIGGER update_product_codes_updated_at 
    BEFORE UPDATE ON product_codes 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Function สำหรับจองรหัสชั่วคราว
CREATE OR REPLACE FUNCTION reserve_product_code(
    p_product_id UUID,
    p_user_id UUID,
    p_duration_minutes INTEGER DEFAULT 10
) RETURNS UUID AS $$
DECLARE
    code_id UUID;
BEGIN
    -- หารหัสที่ว่างและจองไว้
    SELECT id INTO code_id
    FROM product_codes 
    WHERE product_id = p_product_id 
        AND is_used = false 
        AND (reserved_until IS NULL OR reserved_until < NOW())
    LIMIT 1
    FOR UPDATE SKIP LOCKED;
    
    IF code_id IS NOT NULL THEN
        UPDATE product_codes 
        SET reserved_until = NOW() + INTERVAL '1 minute' * p_duration_minutes,
            updated_at = NOW()
        WHERE id = code_id;
    END IF;
    
    RETURN code_id;
END;
$$ LANGUAGE plpgsql;

-- Function สำหรับใช้รหัส
CREATE OR REPLACE FUNCTION use_product_code(
    p_code_id UUID,
    p_user_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
    success BOOLEAN := false;
BEGIN
    UPDATE product_codes 
    SET is_used = true,
        used_by = p_user_id,
        used_at = NOW(),
        updated_at = NOW()
    WHERE id = p_code_id 
        AND is_used = false
        AND (reserved_until IS NULL OR reserved_until > NOW());
    
    GET DIAGNOSTICS success = ROW_COUNT;
    RETURN success > 0;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE product_codes IS 'ตารางรหัสเกมจริง';
COMMENT ON COLUMN product_codes.reserved_until IS 'จองรหัสไว้จนถึงเวลานี้';
COMMENT ON FUNCTION reserve_product_code IS 'จองรหัสชั่วคราวสำหรับผู้ใช้';
COMMENT ON FUNCTION use_product_code IS 'ใช้รหัสและบันทึกผู้ใช้';