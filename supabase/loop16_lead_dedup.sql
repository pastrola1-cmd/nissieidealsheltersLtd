-- =============================================================================
-- LOOP 16: Lead Deduplication, Import & Export Engine
-- =============================================================================
-- Run this in the Supabase SQL Editor.
-- =============================================================================

-- 1. Add lead_fingerprint column to leads table
ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS lead_fingerprint TEXT;

-- 2. Create trigger function to compute fingerprint
CREATE OR REPLACE FUNCTION public.generate_lead_fingerprint()
RETURNS TRIGGER AS $$
BEGIN
  IF (NEW.buyer_phone IS NOT NULL AND TRIM(NEW.buyer_phone) != '') OR (NEW.buyer_email IS NOT NULL AND TRIM(NEW.buyer_email) != '') THEN
    NEW.lead_fingerprint := COALESCE(LOWER(TRIM(NEW.buyer_phone)), '') || ':' || COALESCE(LOWER(TRIM(NEW.buyer_email)), '');
  ELSE
    NEW.lead_fingerprint := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Attach trigger to leads table
DROP TRIGGER IF EXISTS trg_lead_fingerprint ON public.leads;
CREATE TRIGGER trg_lead_fingerprint
  BEFORE INSERT OR UPDATE ON public.leads
  FOR EACH ROW EXECUTE FUNCTION public.generate_lead_fingerprint();

-- 4. Create unique index per company (ignoring nulls)
CREATE UNIQUE INDEX IF NOT EXISTS idx_leads_fingerprint_company
  ON public.leads (lead_fingerprint, company_id)
  WHERE lead_fingerprint IS NOT NULL;
