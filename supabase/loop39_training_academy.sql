-- =====================================================================
-- NISSIE TRAINING ACADEMY — DATABASE SCHEMA & CONFIGURATION
-- =====================================================================

-- 1. Add Gemini API Key to Companies
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS gemini_api_key TEXT;

-- 2. Training Materials Table
CREATE TABLE IF NOT EXISTS public.training_materials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  content_text TEXT,
  media_url TEXT,
  media_name TEXT,
  points INTEGER NOT NULL DEFAULT 50 CHECK (points >= 0),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Training Simulators Table
CREATE TABLE IF NOT EXISTS public.training_simulators (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  objection_type TEXT NOT NULL CHECK (objection_type IN ('price', 'location', 'legal', 'trust', 'custom')),
  client_persona TEXT NOT NULL,
  initial_message TEXT NOT NULL,
  scenarios JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array of multiple-choice steps for fallback
  points INTEGER NOT NULL DEFAULT 100 CHECK (points >= 0),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Training Exams Table
CREATE TABLE IF NOT EXISTS public.training_exams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  passing_score INTEGER NOT NULL DEFAULT 80 CHECK (passing_score BETWEEN 0 AND 100),
  time_limit_mins INTEGER NOT NULL DEFAULT 60 CHECK (time_limit_mins > 0),
  questions JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array of 100+ questions
  points INTEGER NOT NULL DEFAULT 200 CHECK (points >= 0),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. Training Progress Table
CREATE TABLE IF NOT EXISTS public.training_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  item_type TEXT NOT NULL CHECK (item_type IN ('material', 'simulator', 'exam')),
  item_id UUID NOT NULL,
  score INTEGER CHECK (score BETWEEN 0 AND 100),
  completed_at TIMESTAMPTZ DEFAULT now()
);

-- 6. Training Badges Table
CREATE TABLE IF NOT EXISTS public.training_badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  badge_name TEXT NOT NULL,
  unlocked_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.training_materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_simulators ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_badges ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS training_materials_select ON public.training_materials;
DROP POLICY IF EXISTS training_materials_write ON public.training_materials;
DROP POLICY IF EXISTS training_simulators_select ON public.training_simulators;
DROP POLICY IF EXISTS training_simulators_write ON public.training_simulators;
DROP POLICY IF EXISTS training_exams_select ON public.training_exams;
DROP POLICY IF EXISTS training_exams_write ON public.training_exams;
DROP POLICY IF EXISTS training_progress_select ON public.training_progress;
DROP POLICY IF EXISTS training_progress_insert ON public.training_progress;
DROP POLICY IF EXISTS training_badges_select ON public.training_badges;
DROP POLICY IF EXISTS training_badges_insert ON public.training_badges;

-- Define Policies

-- A. Training Materials
CREATE POLICY training_materials_select ON public.training_materials
  FOR SELECT TO authenticated
  USING (company_id = public.get_my_company() OR public.get_my_role() = 'platform_admin');

CREATE POLICY training_materials_write ON public.training_materials
  FOR ALL TO authenticated
  USING (
    (public.get_my_role() IN ('admin', 'manager') AND company_id = public.get_my_company())
    OR public.get_my_role() = 'platform_admin'
  );

-- B. Training Simulators
CREATE POLICY training_simulators_select ON public.training_simulators
  FOR SELECT TO authenticated
  USING (company_id = public.get_my_company() OR public.get_my_role() = 'platform_admin');

CREATE POLICY training_simulators_write ON public.training_simulators
  FOR ALL TO authenticated
  USING (
    (public.get_my_role() IN ('admin', 'manager') AND company_id = public.get_my_company())
    OR public.get_my_role() = 'platform_admin'
  );

-- C. Training Exams
CREATE POLICY training_exams_select ON public.training_exams
  FOR SELECT TO authenticated
  USING (company_id = public.get_my_company() OR public.get_my_role() = 'platform_admin');

CREATE POLICY training_exams_write ON public.training_exams
  FOR ALL TO authenticated
  USING (
    (public.get_my_role() IN ('admin', 'manager') AND company_id = public.get_my_company())
    OR public.get_my_role() = 'platform_admin'
  );

-- D. Training Progress
CREATE POLICY training_progress_select ON public.training_progress
  FOR SELECT TO authenticated
  USING (company_id = public.get_my_company() OR public.get_my_role() = 'platform_admin');

CREATE POLICY training_progress_insert ON public.training_progress
  FOR INSERT TO authenticated
  WITH CHECK (
    profile_id = auth.uid()
    AND company_id = public.get_my_company()
  );

-- E. Training Badges
CREATE POLICY training_badges_select ON public.training_badges
  FOR SELECT TO authenticated
  USING (company_id = public.get_my_company() OR public.get_my_role() = 'platform_admin');

CREATE POLICY training_badges_insert ON public.training_badges
  FOR INSERT TO authenticated
  WITH CHECK (
    profile_id = auth.uid()
    AND company_id = public.get_my_company()
  );

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_training_materials_company ON public.training_materials(company_id);
CREATE INDEX IF NOT EXISTS idx_training_simulators_company ON public.training_simulators(company_id);
CREATE INDEX IF NOT EXISTS idx_training_exams_company ON public.training_exams(company_id);
CREATE INDEX IF NOT EXISTS idx_training_progress_profile ON public.training_progress(profile_id);
CREATE INDEX IF NOT EXISTS idx_training_badges_profile ON public.training_badges(profile_id);

-- =====================================================================
-- NISSIE TRAINING ACADEMY — PRE-SEEDED STUDY MATERIALS & EXAMS
-- =====================================================================

-- Default Company: Nissie Ideal Shelters (d3b07384-d113-4ec6-a5d7-ecf9e01103e6)
-- (If this company doesn't exist yet, inserts will ignore or execute gracefully)

-- Seed Study Guide
INSERT INTO public.training_materials (id, company_id, title, description, content_text, points)
VALUES (
  'e0b07384-d113-4ec6-a5d7-ecf9e01103e6',
  'd3b07384-d113-4ec6-a5d7-ecf9e01103e6',
  'Mastering Title Deeds & Legal Ownership in Nigeria',
  'A professional guide explaining Certificates of Occupancy (C of O), Governor Consent, Gazette, and Deed of Assignment.',
  '## 1. Land Ownership & The Land Use Act of 1978\nIn Nigeria, all land in a state is vested in the State Governor, who holds it in trust for the people. This means individuals do not own land indefinitely; instead, they lease it for a maximum period of 99 years through a **Certificate of Occupancy (C of O)**.\n\n## 2. Key Title Documents You Must Know\n- **Certificate of Occupancy (C of O):** The first certificate issued by the state government to lease land to an owner for 99 years. Only one C of O can exist on a plot.\n- **Governor Consent:** When a holder of a C of O sells their land to a new buyer, the transfer requires approval from the governor. This is called Governor Consent.\n- **Deed of Assignment:** The legal contract between the seller and buyer transfering interest/rights. It must be registered to apply for Governor Consent.\n- **Gazette:** An official government publication recording land acquired by government and land released (excised) back to native communities. Excised land is safe for purchase.\n- **Registered Survey:** Defines the precise coordinates and boundaries of the property, verified at the Surveyor General''s office.\n\n## 3. High-Value Marketing Tip\nWhen talking to clients who are skeptical about land ownership safety, always reassure them by presenting Nissie''s verified survey coordinates and confirming that Nissie properties carry clear, government-approved titles.',
  50
) ON CONFLICT (id) DO NOTHING;

-- Seed Objection Handling Simulator
INSERT INTO public.training_simulators (id, company_id, title, description, objection_type, client_persona, initial_message, scenarios, points)
VALUES (
  'e1b07384-d113-4ec6-a5d7-ecf9e01103e6',
  'd3b07384-d113-4ec6-a5d7-ecf9e01103e6',
  'Handling the "Too Expensive" Objection',
  'Simulate handling a prospect who claims Nissie Gardens prices are inflated compared to competitor layouts.',
  'price',
  'Frugal Investor',
  'I looked at Nissie Gardens, but the neighboring estate is selling similar sized plots for 20% cheaper. Why should I pay more here?',
  '[
    {
      "id": "step_1",
      "objection_text": "I looked at Nissie Gardens, but the neighboring estate is selling similar sized plots for 20% cheaper. Why should I pay more here?",
      "options": [
        {
          "text": "Our estate comes with instant C of O allocation and fully tarred access roads. The cheaper estate is currently agricultural land without approved layout titles, meaning high future risk.",
          "score": 10,
          "feedback": "Excellent choice! You immediately shifted the conversation from cost to value and risk reduction.",
          "next_step_id": null
        },
        {
          "text": "If you want cheap land, you get what you pay for. We don''t offer low-quality properties.",
          "score": 2,
          "feedback": "Warning: Avoid sounding dismissive or insulting to the customer. This will lose you the sale.",
          "next_step_id": null
        },
        {
          "text": "I can talk to my manager to see if we can give you a 20% discount to match their price.",
          "score": 5,
          "feedback": "Caution: Giving discounts immediately devalues the brand and reduces your commission unnecessarily. Always sell value first.",
          "next_step_id": null
        }
      ]
    }
  ]'::jsonb,
  100
) ON CONFLICT (id) DO NOTHING;

-- Seed Timed Quiz / Pro Certification Exam
INSERT INTO public.training_exams (id, company_id, title, description, passing_score, time_limit_mins, questions, points)
VALUES (
  'e2b07384-d113-4ec6-a5d7-ecf9e01103e6',
  'd3b07384-d113-4ec6-a5d7-ecf9e01103e6',
  'Nissie Certified Closer Exam',
  'Demonstrate master-level real estate marketing knowledge, title deeds certification, and objection handling skills to earn 200 XP.',
  80,
  30,
  '[
    {
      "id": "q1",
      "question_text": "What does a Certificate of Occupancy (C of O) certify in Nigeria?",
      "options": [
        "Permanent, infinite ownership of land without state oversight",
        "A lease-hold right issued by the state government for a term of up to 99 years",
        "Permission to build a commercial factory on any land",
        "A temporary layout outline subject to annual relocation"
      ],
      "correct_index": 1,
      "explanation": "Under the Land Use Act of 1978, all land in a state is held in trust by the Governor. A C of O grants a leasehold interest for a maximum of 99 years."
    },
    {
      "id": "q2",
      "question_text": "When a buyer purchases land from an existing C of O holder, what official state approval is required to finalize the transfer?",
      "options": [
        "Survey Plan registration",
        "Governor Consent",
        "Family receipt endorsement",
        "LGA Chairman signature"
      ],
      "correct_index": 1,
      "explanation": "Governor Consent is legally required for any subsequent transfer of interest in land that already has a Certificate of Occupancy."
    },
    {
      "id": "q3",
      "question_text": "What is the primary benefit of recommending Nissie''s installment payment plan to a client who has 70% of the property value ready?",
      "options": [
        "They get a 50% discount on the remaining sum",
        "They can immediately build a duplex without making further payments",
        "They lock in the current property price and secure the unit while spreading balance payments",
        "They bypass the requirement for legal title registration"
      ],
      "correct_index": 2,
      "explanation": "Installments allow clients to lock in the property price, protecting them against inflation and property value appreciation during the payment tenure."
    },
    {
      "id": "q4",
      "question_text": "Which closing technique is best exemplified by asking: ''Should we issue the purchase receipt in your personal name or in your company''s registered name?''",
      "options": [
        "The Assumptive Close",
        "The Urgency Close",
        "The Alternative-Choice Close",
        "The Fear of Loss Close"
      ],
      "correct_index": 0,
      "explanation": "The Assumptive Close assumes the buyer has already made the decision to buy, prompting them on execution details to streamline completion."
    },
    {
      "id": "q5",
      "question_text": "A client tells you: ''I love Nissie Gardens, but the neighborhood seems undeveloped right now.'' What is the most professional response?",
      "options": [
        "''Yes, it is undeveloped. Please look at our properties in central Victoria Island instead.''",
        "''Development takes time, you just have to wait 15 years.''",
        "''Buying in an emerging area gives you the highest capital appreciation. Once tarred roads and infrastructure are finished, the price will double or triple.''",
        "''We are developing everything next month so do not worry.''"
      ],
      "correct_index": 2,
      "explanation": "Framer of undeveloped areas should highlight investment upside and capital gains, which is the core driver of high real estate ROI."
    }
  ]'::jsonb,
  200
) ON CONFLICT (id) DO NOTHING;

