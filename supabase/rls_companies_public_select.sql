-- Allow public select access on the companies table so anonymous/non-logged-in users can fetch the list of agencies on signup.
CREATE POLICY companies_public_select ON public.companies
  FOR SELECT
  USING (true);
