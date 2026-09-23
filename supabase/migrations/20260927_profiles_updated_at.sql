-- Fix profile-completion crash (42703: record "new" has no field "updated_at").
-- tr_profiles_set_updated_at fires on every profiles UPDATE but the column
-- did not exist. Also removes the redundant silent role-revert trigger
-- (trg_protect_profile_privilege already guards role/status/company).

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

UPDATE public.profiles
SET updated_at = COALESCE(updated_at, created_at, now())
WHERE updated_at IS NULL;

DROP TRIGGER IF EXISTS trg_protect_profile_sensitive ON public.profiles;
DROP FUNCTION IF EXISTS public.protect_profile_sensitive_columns();
