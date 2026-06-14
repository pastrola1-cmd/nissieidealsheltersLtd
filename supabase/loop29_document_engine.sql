-- =============================================================================
-- LOOP 29: Scalewealth Estate Document Engine (SDE)
-- =============================================================================
-- Run this migration in the Supabase SQL Editor.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  lead_id UUID REFERENCES public.leads(id) ON DELETE CASCADE,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  type TEXT NOT NULL CHECK (type IN ('offer_letter', 'receipt', 'tenancy_agreement', 'purchase_agreement', 'commission_statement')),
  title TEXT NOT NULL,
  file_url TEXT NOT NULL,
  variables JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Index for querying documents by lead or company
CREATE INDEX IF NOT EXISTS idx_documents_company ON public.documents(company_id);
CREATE INDEX IF NOT EXISTS idx_documents_lead ON public.documents(lead_id);

-- Enable RLS
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;

-- Select policy: Anyone in the company can view company documents
DROP POLICY IF EXISTS documents_select ON public.documents;
CREATE POLICY documents_select ON public.documents
  FOR SELECT TO authenticated
  USING (company_id = public.get_my_company());

-- Write policy: Anyone in the company can write/modify documents
DROP POLICY IF EXISTS documents_write ON public.documents;
CREATE POLICY documents_write ON public.documents
  FOR ALL TO authenticated
  USING (company_id = public.get_my_company());
