-- database/migrations/006_create_transactions_table.sql
-- สร้างตารางธุรกรรมการเงิน (Integration กับ promptpay-truewallet-system)

-- ตารางธุรกรรม PromptPay
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    transaction_id VARCHAR(100) UNIQUE NOT NULL, -- จาก promptpay-truewallet-system
    amount DECIMAL(10,2) NOT NULL,
    random_cents INTEGER NOT NULL, -- สำหรับ QR Code
    qr_code_data TEXT,
    status VARCHAR(20) DEFAULT 'pending' CHECK (
        status IN ('pending', 'completed', 'expired', 'failed')
    ),
    payment_method VARCHAR(20) DEFAULT 'promptpay' CHECK (
        payment_method IN ('promptpay', 'truewallet')
    ),
    phone_number VARCHAR(15) DEFAULT '0944283381',
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE,
    webhook_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ตารางธุรกรรม TrueWallet Voucher
CREATE TABLE voucher_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    voucher_code VARCHAR(100) NOT NULL,
    gift_url TEXT,
    amount DECIMAL(10,2),
    status VARCHAR(20) DEFAULT 'pending' CHECK (
        status IN ('pending', 'completed', 'failed', 'used')
    ),
    error_message TEXT,
    response_data JSONB,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ตารางประวัติการเปลี่ยนแปลงเครดิต
CREATE TABLE credit_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    transaction_type VARCHAR(20) NOT NULL CHECK (
        transaction_type IN ('deposit', 'purchase', 'refund', 'adjustment', 'bonus')
    ),
    amount DECIMAL(10,2) NOT NULL, -- บวกสำหรับเพิ่ม ลบสำหรับหัก
    balance_before DECIMAL(10,2) NOT NULL,
    balance_after DECIMAL(10,2) NOT NULL,
    description TEXT NOT NULL,
    reference_type VARCHAR(20) CHECK (
        reference_type IN ('promptpay', 'truewallet', 'order', 'manual', 'system')
    ),
    reference_id UUID, -- อ้างอิงไป transaction, order หรือ table อื่น
    processed_by UUID REFERENCES users(id), -- แอดมินที่ทำรายการ (สำหรับ manual)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ตาราง SMS tracking (สำหรับ webhook)
CREATE TABLE sms_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id UUID REFERENCES transactions(id),
    phone_number VARCHAR(15) NOT NULL,
    message_content TEXT NOT NULL,
    amount DECIMAL(10,2),
    parsed_data JSONB,
    processed BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- สร้าง indexes
CREATE INDEX idx_transactions_user_id ON transactions(user_id);
CREATE INDEX idx_transactions_transaction_id ON transactions(transaction_id);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_expires_at ON transactions(expires_at);
CREATE INDEX idx_transactions_created_at ON transactions(created_at DESC);

CREATE INDEX idx_voucher_transactions_user_id ON voucher_transactions(user_id);
CREATE INDEX idx_voucher_transactions_voucher_code ON voucher_transactions(voucher_code);
CREATE INDEX idx_voucher_transactions_status ON voucher_transactions(status);
CREATE INDEX idx_voucher_transactions_created_at ON voucher_transactions(created_at DESC);

CREATE INDEX idx_credit_transactions_user_id ON credit_transactions(user_id);
CREATE INDEX idx_credit_transactions_type ON credit_transactions(transaction_type);
CREATE INDEX idx_credit_transactions_reference ON credit_transactions(reference_type, reference_id);
CREATE INDEX idx_credit_transactions_created_at ON credit_transactions(created_at DESC);

CREATE INDEX idx_sms_logs_transaction_id ON sms_logs(transaction_id);
CREATE INDEX idx_sms_logs_processed ON sms_logs(processed);
CREATE INDEX idx_sms_logs_created_at ON sms_logs(created_at DESC);

-- สร้าง triggers
CREATE TRIGGER update_transactions_updated_at 
    BEFORE UPDATE ON transactions 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_voucher_transactions_updated_at 
    BEFORE UPDATE ON voucher_transactions 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Function สำหรับเพิ่มเครดิต
CREATE OR REPLACE FUNCTION add_user_credit(
    p_user_id UUID,
    p_amount DECIMAL(10,2),
    p_description TEXT,
    p_reference_type VARCHAR(20) DEFAULT 'manual',
    p_reference_id UUID DEFAULT NULL,
    p_processed_by UUID DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    old_balance DECIMAL(10,2);
    new_balance DECIMAL(10,2);
BEGIN
    -- ล็อกและดึงยอดเครดิตปัจจุบัน
    SELECT credits INTO old_balance
    FROM users 
    WHERE id = p_user_id 
    FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ไม่พบผู้ใช้ที่ระบุ';
    END IF;
    
    -- คำนวณยอดใหม่
    new_balance := old_balance + p_amount;
    
    IF new_balance < 0 THEN
        RAISE EXCEPTION 'เครดิตไม่เพียงพอ';
    END IF;
    
    -- อัปเดตยอดเครดิต
    UPDATE users 
    SET credits = new_balance,
        updated_at = NOW()
    WHERE id = p_user_id;
    
    -- บันทึกประวัติ
    INSERT INTO credit_transactions (
        user_id, transaction_type, amount, 
        balance_before, balance_after, description,
        reference_type, reference_id, processed_by
    ) VALUES (
        p_user_id, 
        CASE WHEN p_amount > 0 THEN 'deposit' ELSE 'purchase' END,
        p_amount, old_balance, new_balance, p_description,
        p_reference_type, p_reference_id, p_processed_by
    );
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function สำหรับตรวจสอบและทำความสะอาด transaction หมดอายุ
CREATE OR REPLACE FUNCTION cleanup_expired_transactions() 
RETURNS INTEGER AS $$
DECLARE
    expired_count INTEGER;
BEGIN
    -- อัปเดต transaction ที่หมดอายุ
    UPDATE transactions 
    SET status = 'expired',
        updated_at = NOW()
    WHERE status = 'pending' 
        AND expires_at < NOW();
    
    GET DIAGNOSTICS expired_count = ROW_COUNT;
    
    -- ปลดล็อครหัสที่จองไว้สำหรับ transaction หมดอายุ
    UPDATE product_codes 
    SET reserved_until = NULL,
        updated_at = NOW()
    WHERE reserved_until < NOW();
    
    RETURN expired_count;
END;
$$ LANGUAGE plpgsql;

-- Function สำหรับดึงสถิติการเงิน
CREATE OR REPLACE FUNCTION get_financial_stats(
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_end_date DATE DEFAULT CURRENT_DATE
) RETURNS TABLE (
    total_deposits DECIMAL(10,2),
    total_purchases DECIMAL(10,2),
    total_refunds DECIMAL(10,2),
    net_revenue DECIMAL(10,2),
    transaction_count BIGINT,
    unique_customers BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(SUM(CASE WHEN ct.transaction_type = 'deposit' THEN ct.amount ELSE 0 END), 0) as total_deposits,
        COALESCE(SUM(CASE WHEN ct.transaction_type = 'purchase' THEN ABS(ct.amount) ELSE 0 END), 0) as total_purchases,
        COALESCE(SUM(CASE WHEN ct.transaction_type = 'refund' THEN ct.amount ELSE 0 END), 0) as total_refunds,
        COALESCE(SUM(CASE WHEN ct.transaction_type = 'purchase' THEN ABS(ct.amount) 
                          WHEN ct.transaction_type = 'refund' THEN -ct.amount 
                          ELSE 0 END), 0) as net_revenue,
        COUNT(*) as transaction_count,
        COUNT(DISTINCT ct.user_id) as unique_customers
    FROM credit_transactions ct
    WHERE DATE(ct.created_at) BETWEEN p_start_date AND p_end_date;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE transactions IS 'ตารางธุรกรรม PromptPay';
COMMENT ON TABLE voucher_transactions IS 'ตารางธุรกรรม TrueWallet Voucher';
COMMENT ON TABLE credit_transactions IS 'ตารางประวัติการเปลี่ยนแปลงเครดิต';
COMMENT ON TABLE sms_logs IS 'ตารางบันทึก SMS สำหรับ webhook';

COMMENT ON FUNCTION add_user_credit IS 'เพิ่ม/หักเครดิตของผู้ใช้พร้อมบันทึกประวัติ';
COMMENT ON FUNCTION cleanup_expired_transactions IS 'ทำความสะอาด transaction ที่หมดอายุ';
COMMENT ON FUNCTION get_financial_stats IS 'ดึงสถิติการเงินในช่วงเวลาที่กำหนด';