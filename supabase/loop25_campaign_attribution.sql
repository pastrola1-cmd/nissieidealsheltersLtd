-- =============================================================================
-- LOOP 25: Campaign Tracking & Attribution SQL Migration
-- =============================================================================

-- 1. Alter campaigns table to add analytics columns
ALTER TABLE public.campaigns
  ADD COLUMN IF NOT EXISTS share_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS lead_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS conversion_count INTEGER DEFAULT 0;

-- 2. Alter leads table to associate campaigns
ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS campaign_id UUID REFERENCES public.campaigns(id) ON DELETE SET NULL;

-- 3. Create campaign shares tracking table
CREATE TABLE IF NOT EXISTS public.campaign_shares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID REFERENCES public.campaigns(id) ON DELETE CASCADE NOT NULL,
  platform TEXT NOT NULL,
  shared_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Enable RLS on campaign_shares and add policy isolating to company staff
ALTER TABLE public.campaign_shares ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS campaign_shares_policy ON public.campaign_shares;
CREATE POLICY campaign_shares_policy ON public.campaign_shares
  FOR ALL
  TO authenticated
  USING (
    campaign_id IN (
      SELECT id FROM public.campaigns WHERE company_id = (
        SELECT company_id FROM public.profiles WHERE id = auth.uid()
      )
    )
  )
  WITH CHECK (
    campaign_id IN (
      SELECT id FROM public.campaigns WHERE company_id = (
        SELECT company_id FROM public.profiles WHERE id = auth.uid()
      )
    )
  );

-- 5. Trigger to automatically increment share_count on campaign when a share log is inserted
CREATE OR REPLACE FUNCTION public.handle_campaign_share_inserted()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.campaigns
  SET share_count = COALESCE(share_count, 0) + 1
  WHERE id = NEW.campaign_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_campaign_share_inserted ON public.campaign_shares;
CREATE TRIGGER trg_campaign_share_inserted
  AFTER INSERT ON public.campaign_shares
  FOR EACH ROW EXECUTE FUNCTION public.handle_campaign_share_inserted();

-- 6. Trigger to automatically update lead_count and conversion_count when leads change
CREATE OR REPLACE FUNCTION public.handle_lead_campaign_attribution()
RETURNS TRIGGER AS $$
BEGIN
  -- Handle INSERT
  IF TG_OP = 'INSERT' THEN
    IF NEW.campaign_id IS NOT NULL THEN
      UPDATE public.campaigns
      SET lead_count = COALESCE(lead_count, 0) + 1
      WHERE id = NEW.campaign_id;
    END IF;

  -- Handle UPDATE
  ELSIF TG_OP = 'UPDATE' THEN
    -- If campaign_id changed or was added
    IF (OLD.campaign_id IS DISTINCT FROM NEW.campaign_id) THEN
      -- Decrement old campaign lead count
      IF OLD.campaign_id IS NOT NULL THEN
        UPDATE public.campaigns
        SET lead_count = GREATEST(0, COALESCE(lead_count, 0) - 1)
        WHERE id = OLD.campaign_id;
      END IF;
      -- Increment new campaign lead count
      IF NEW.campaign_id IS NOT NULL THEN
        UPDATE public.campaigns
        SET lead_count = COALESCE(lead_count, 0) + 1
        WHERE id = NEW.campaign_id;
      END IF;
    END IF;

    -- If stage changed to 'closed' (conversion)
    IF NEW.stage = 'closed' AND OLD.stage != 'closed' AND NEW.campaign_id IS NOT NULL THEN
      UPDATE public.campaigns
      SET conversion_count = COALESCE(conversion_count, 0) + 1
      WHERE id = NEW.campaign_id;
    -- If stage changed away from 'closed'
    ELSIF OLD.stage = 'closed' AND NEW.stage != 'closed' AND NEW.campaign_id IS NOT NULL THEN
      UPDATE public.campaigns
      SET conversion_count = GREATEST(0, COALESCE(conversion_count, 0) - 1)
      WHERE id = NEW.campaign_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_lead_campaign_attribution ON public.leads;
CREATE TRIGGER trg_lead_campaign_attribution
  AFTER INSERT OR UPDATE ON public.leads
  FOR EACH ROW EXECUTE FUNCTION public.handle_lead_campaign_attribution();
