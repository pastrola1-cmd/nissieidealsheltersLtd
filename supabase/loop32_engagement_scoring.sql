-- =============================================================================
-- LOOP 32: Engagement Signals & Lead Scoring
-- Adds columns and functions to track lead engagement and update intent scores.
-- =============================================================================

-- 1. Add Columns to leads table
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS intent_score TEXT DEFAULT 'Cold' CHECK (intent_score IN ('Cold', 'Warm', 'Hot'));
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS engagement_signals JSONB DEFAULT '{}'::jsonb;

-- 2. Create function to recalculate lead intent score
CREATE OR REPLACE FUNCTION public.recalculate_lead_intent_score(p_lead_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_buyer_phone TEXT;
  v_company_id UUID;
  v_property_count INTEGER;
  v_signals JSONB;
  v_score TEXT := 'Cold';
  v_video_progress INTEGER := 0;
  v_scroll_depth INTEGER := 0;
  v_time_on_page INTEGER := 0;
  v_visit_count INTEGER := 1;
  v_created_at TIMESTAMPTZ;
  v_last_visit_at TIMESTAMPTZ;
BEGIN
  -- Get lead data
  SELECT buyer_phone, company_id, engagement_signals, created_at
  INTO v_buyer_phone, v_company_id, v_signals, v_created_at
  FROM public.leads
  WHERE id = p_lead_id;

  IF v_buyer_phone IS NULL THEN
    RETURN 'Cold';
  END IF;

  -- Check property submissions count for this buyer
  SELECT COUNT(DISTINCT property_id) INTO v_property_count
  FROM public.leads
  WHERE buyer_phone = v_buyer_phone AND company_id = v_company_id;

  -- Extract engagement parameters
  v_video_progress := COALESCE((v_signals->>'max_video_progress')::integer, 0);
  v_scroll_depth := COALESCE((v_signals->>'max_scroll_depth')::integer, 0);
  v_time_on_page := COALESCE((v_signals->>'time_on_page_seconds')::integer, 0);
  v_visit_count := COALESCE((v_signals->>'visit_count')::integer, 1);
  IF v_signals->>'last_visit_at' IS NOT NULL THEN
    v_last_visit_at := (v_signals->>'last_visit_at')::timestamptz;
  END IF;

  -- Determine Score
  -- HOT CONDITIONS:
  -- - Submitted on 2+ properties
  -- - Watched 75%+ video AND spent 60+ seconds on page
  -- - Return visit within 48 hours of creation AND (video progress > 25 OR scroll depth > 50)
  IF v_property_count >= 2 THEN
    v_score := 'Hot';
  ELSIF v_video_progress >= 75 AND v_time_on_page >= 60 THEN
    v_score := 'Hot';
  ELSIF v_visit_count >= 2 AND v_last_visit_at IS NOT NULL AND (v_last_visit_at - v_created_at) <= INTERVAL '48 hours' AND (v_video_progress > 25 OR v_scroll_depth > 50) THEN
    v_score := 'Hot';
  -- WARM CONDITIONS:
  -- - Watched 50%+ of video
  -- - Scroll depth >= 75%
  -- - Time on page >= 60 seconds
  -- - Return visit (visit_count >= 2)
  ELSIF v_video_progress >= 50 OR v_scroll_depth >= 75 OR v_time_on_page >= 60 OR v_visit_count >= 2 THEN
    v_score := 'Warm';
  ELSE
    v_score := 'Cold';
  END IF;

  -- Update score
  UPDATE public.leads
  SET intent_score = v_score,
      updated_at = now()
  WHERE id = p_lead_id;

  -- Update all other leads for the same buyer to reflect same score if portfolio buyer
  IF v_property_count >= 2 AND v_score = 'Hot' THEN
    UPDATE public.leads
    SET intent_score = 'Hot',
        updated_at = now()
    WHERE buyer_phone = v_buyer_phone AND company_id = v_company_id AND intent_score <> 'Hot';
  END IF;

  RETURN v_score;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create function to log lead engagement signal
CREATE OR REPLACE FUNCTION public.log_lead_engagement(
  p_lead_id UUID,
  p_signal_type TEXT,
  p_signal_value TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_signals JSONB;
BEGIN
  -- Get current signals
  SELECT COALESCE(engagement_signals, '{}'::jsonb) INTO v_signals
  FROM public.leads
  WHERE id = p_lead_id;

  -- Update based on signal type
  IF p_signal_type = 'video_progress' THEN
    v_signals := jsonb_set(
      v_signals,
      '{max_video_progress}',
      to_jsonb(GREATEST(COALESCE((v_signals->>'max_video_progress')::integer, 0), p_signal_value::integer))
    );
  ELSIF p_signal_type = 'scroll_depth' THEN
    v_signals := jsonb_set(
      v_signals,
      '{max_scroll_depth}',
      to_jsonb(GREATEST(COALESCE((v_signals->>'max_scroll_depth')::integer, 0), p_signal_value::integer))
    );
  ELSIF p_signal_type = 'time_on_page' THEN
    v_signals := jsonb_set(
      v_signals,
      '{time_on_page_seconds}',
      to_jsonb(GREATEST(COALESCE((v_signals->>'time_on_page_seconds')::integer, 0), p_signal_value::integer))
    );
  ELSIF p_signal_type = 'page_visit' THEN
    v_signals := jsonb_set(
      v_signals,
      '{visit_count}',
      to_jsonb(COALESCE((v_signals->>'visit_count')::integer, 0) + 1)
    );
    v_signals := jsonb_set(
      v_signals,
      '{last_visit_at}',
      to_jsonb(p_signal_value)
    );
  END IF;

  -- Save back to lead
  UPDATE public.leads
  SET engagement_signals = v_signals,
      updated_at = now()
  WHERE id = p_lead_id;

  -- Recalculate intent score
  PERFORM public.recalculate_lead_intent_score(p_lead_id);

  RETURN v_signals;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
