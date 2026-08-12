-- Loop 41: Email Campaign History Schema & Policies
-- Run this in your Supabase SQL Editor (https://supabase.com)

-- 1. Add Email Integration fields to Companies table
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS email_provider TEXT DEFAULT 'simulation';
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS smtp_host TEXT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS smtp_port INTEGER DEFAULT 587;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS smtp_username TEXT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS smtp_password TEXT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS smtp_sender_name TEXT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS smtp_sender_email TEXT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS brevo_api_key TEXT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS brevo_sender_name TEXT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS brevo_sender_email TEXT;

-- 2. Create Email Campaigns Table
CREATE TABLE IF NOT EXISTS public.email_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  subject TEXT NOT NULL,
  body TEXT NOT NULL,
  recipient_filter JSONB,
  total_recipients INTEGER DEFAULT 0 NOT NULL,
  delivered_count INTEGER DEFAULT 0 NOT NULL,
  failed_count INTEGER DEFAULT 0 NOT NULL,
  status TEXT DEFAULT 'sent' NOT NULL, -- 'sending', 'sent', 'failed'
  sent_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 3. Create Email Messages Table
CREATE TABLE IF NOT EXISTS public.email_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID REFERENCES public.email_campaigns(id) ON DELETE CASCADE NOT NULL,
  recipient_name TEXT,
  recipient_email TEXT NOT NULL,
  recipient_type TEXT, -- 'lead', 'partner', 'custom'
  status TEXT DEFAULT 'pending' NOT NULL, -- 'delivered', 'failed', 'pending'
  error_message TEXT,
  sent_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.email_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_messages ENABLE ROW LEVEL SECURITY;

-- 5. Drop existing policies if any to prevent duplicates
DROP POLICY IF EXISTS email_campaigns_company_isolation ON public.email_campaigns;
DROP POLICY IF EXISTS email_messages_company_isolation ON public.email_messages;

-- 6. Add Company Isolation Policies
CREATE POLICY email_campaigns_company_isolation ON public.email_campaigns
  FOR ALL USING (company_id = (SELECT company_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY email_messages_company_isolation ON public.email_messages
  FOR ALL USING (campaign_id IN (SELECT id FROM public.email_campaigns));
