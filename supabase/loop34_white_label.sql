-- =============================================================================
-- LOOP 34: White Label Landing Pages
-- Adds support for custom domain mappings on companies.
-- =============================================================================

-- Add custom_domain to companies table
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS custom_domain TEXT UNIQUE;

-- Create index for faster domain lookup
CREATE INDEX IF NOT EXISTS idx_companies_custom_domain ON public.companies(custom_domain);
