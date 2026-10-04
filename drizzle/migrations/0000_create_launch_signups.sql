CREATE TABLE public.launch_signups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
  email text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT launch_signups_email_unique UNIQUE (email)
);

GRANT INSERT ON public.launch_signups TO anon;
GRANT INSERT ON public.launch_signups TO authenticated;
GRANT ALL ON public.launch_signups TO service_role;

ALTER TABLE public.launch_signups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can join the launch list"
ON public.launch_signups
FOR INSERT
TO anon, authenticated
WITH CHECK (
  char_length(name) BETWEEN 1 AND 100
  AND char_length(email) BETWEEN 3 AND 254
  AND email = lower(email)
);