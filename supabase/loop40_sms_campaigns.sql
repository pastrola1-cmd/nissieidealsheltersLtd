-- Loop 40: SMS Campaign History Schema & Policies

CREATE TABLE IF NOT EXISTS public.sms_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  channel TEXT DEFAULT 'generic' NOT NULL,
  sender_id TEXT DEFAULT 'Nissie' NOT NULL,
  recipient_filter JSONB,
  total_recipients INTEGER DEFAULT 0 NOT NULL,
  delivered_count INTEGER DEFAULT 0 NOT NULL,
  failed_count INTEGER DEFAULT 0 NOT NULL,
  status TEXT DEFAULT 'sent' NOT NULL,
  sent_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.sms_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID REFERENCES public.sms_campaigns(id) ON DELETE CASCADE NOT NULL,
  recipient_name TEXT,
  recipient_phone TEXT NOT NULL,
  recipient_type TEXT,
  message_body TEXT NOT NULL,
  status TEXT DEFAULT 'pending' NOT NULL,
  termii_message_id TEXT,
  error_message TEXT,
  sent_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Ensure company_id column exists (in case table was previously created without it)
ALTER TABLE public.sms_campaigns ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE;

-- Enable RLS
ALTER TABLE public.sms_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sms_messages ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS sms_campaigns_company_isolation ON public.sms_campaigns;
DROP POLICY IF EXISTS sms_messages_company_isolation ON public.sms_messages;

-- RLS Policies: Company Isolation (Users can only see campaigns within their own agency)
CREATE POLICY sms_campaigns_company_isolation ON public.sms_campaigns
  FOR ALL USING (company_id = (SELECT company_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY sms_messages_company_isolation ON public.sms_messages
  FOR ALL USING (campaign_id IN (SELECT id FROM public.sms_campaigns));
