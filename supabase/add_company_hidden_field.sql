-- Add is_hidden column to companies table to allow super admins to hide them from the signup dropdown
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN NOT NULL DEFAULT false;
