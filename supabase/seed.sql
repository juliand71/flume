-- Seed data for local development
-- Debug user UUID matches auth.DebugUserID in Go API

-- ── Debug user in Supabase Auth ─────────────────────────────────────────────

INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at, confirmation_token,
  raw_app_meta_data, raw_user_meta_data
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'debug@flume.local',
  crypt('debug123', gen_salt('bf')),
  now(), now(), now(), '',
  '{"provider":"email","providers":["email"]}',
  '{}'
) ON CONFLICT (id) DO NOTHING;

-- Profile starts at onboarding so the full flow can be tested
INSERT INTO public.profiles (id, display_name, onboarding_step)
VALUES ('00000000-0000-0000-0000-000000000000', 'Debug User', 'link_bank')
ON CONFLICT (id) DO NOTHING;
