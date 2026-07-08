-- Loop 38: Termii SMS Integration Migration
-- Add Termii API Key and Sender ID configurations to the companies table

ALTER TABLE companies ADD COLUMN IF NOT EXISTS termii_api_key TEXT;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS termii_sender_id TEXT DEFAULT 'Nissie';
