-- Migration: In-app direct live support chat for clients and Nissie Admin
CREATE TABLE IF NOT EXISTS public.support_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id TEXT NOT NULL,
  sender_id TEXT NOT NULL,
  sender_role TEXT NOT NULL DEFAULT 'client', -- 'client' or 'admin'
  sender_name TEXT NOT NULL,
  sender_phone TEXT,
  sender_email TEXT,
  property_id TEXT,
  property_title TEXT,
  message TEXT NOT NULL,
  is_read_by_admin BOOLEAN DEFAULT false,
  is_read_by_client BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Table for multi-agent support ticket management, assignment, status & internal notes
CREATE TABLE IF NOT EXISTS public.support_conversations (
  conversation_id TEXT PRIMARY KEY,
  client_name TEXT NOT NULL DEFAULT 'Client',
  client_phone TEXT,
  client_email TEXT,
  property_title TEXT,
  assigned_to_id TEXT,
  assigned_to_name TEXT,
  status TEXT NOT NULL DEFAULT 'open', -- 'open', 'in_progress', 'resolved', 'closed'
  internal_notes TEXT,
  last_message TEXT,
  last_message_time TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for lightning fast queries & realtime ordering
CREATE INDEX IF NOT EXISTS idx_support_messages_conv ON public.support_messages(conversation_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_support_messages_created ON public.support_messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_support_conv_assigned ON public.support_conversations(assigned_to_id);
CREATE INDEX IF NOT EXISTS idx_support_conv_status ON public.support_conversations(status);

-- Enable RLS
ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_conversations ENABLE ROW LEVEL SECURITY;

-- Allow anon & authenticated users to read and send messages
DROP POLICY IF EXISTS "support_messages_select" ON public.support_messages;
CREATE POLICY "support_messages_select" ON public.support_messages
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "support_messages_insert" ON public.support_messages;
CREATE POLICY "support_messages_insert" ON public.support_messages
  FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "support_messages_update" ON public.support_messages;
CREATE POLICY "support_messages_update" ON public.support_messages
  FOR UPDATE TO anon, authenticated USING (true);

-- Conversations policies
DROP POLICY IF EXISTS "support_conv_select" ON public.support_conversations;
CREATE POLICY "support_conv_select" ON public.support_conversations
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "support_conv_insert" ON public.support_conversations;
CREATE POLICY "support_conv_insert" ON public.support_conversations
  FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "support_conv_update" ON public.support_conversations;
CREATE POLICY "support_conv_update" ON public.support_conversations
  FOR UPDATE TO anon, authenticated USING (true);

-- Enable Realtime for support_messages & support_conversations
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND schemaname = 'public' 
    AND tablename = 'support_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.support_messages;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND schemaname = 'public' 
    AND tablename = 'support_conversations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.support_conversations;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';

