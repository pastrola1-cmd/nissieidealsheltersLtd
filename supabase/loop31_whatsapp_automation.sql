-- =============================================================================
-- LOOP 31: WhatsApp Business API Schema
-- Adds support for storing WhatsApp API credentials and logging sent messages.
-- =============================================================================

-- 1. Add WhatsApp API configurations to Companies
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS whatsapp_phone_number_id TEXT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS whatsapp_waba_id TEXT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS whatsapp_access_token TEXT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS whatsapp_enabled BOOLEAN DEFAULT false;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS whatsapp_template_name TEXT DEFAULT 'property_inquiry_auto';

-- 2. Create whatsapp_messages log table for tracking delivery status
CREATE TABLE IF NOT EXISTS public.whatsapp_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  lead_id UUID REFERENCES public.leads(id) ON DELETE CASCADE NOT NULL,
  message_sid TEXT UNIQUE, -- Meta Message ID (wamid.XXX)
  recipient_phone TEXT NOT NULL,
  template_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sent', 'delivered', 'read', 'failed')),
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Enable RLS for message logs
ALTER TABLE public.whatsapp_messages ENABLE ROW LEVEL SECURITY;

-- 4. Drop policy if exists
DROP POLICY IF EXISTS whatsapp_messages_select ON public.whatsapp_messages;

-- 5. RLS policy for message logs viewable by company staff
CREATE POLICY whatsapp_messages_select ON public.whatsapp_messages
  FOR SELECT TO authenticated
  USING (company_id = public.get_my_company());
