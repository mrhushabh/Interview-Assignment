-- Prompt Versioning


CREATE TABLE prompt_versions (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version    INTEGER NOT NULL UNIQUE,
  name       TEXT NOT NULL,
  content    TEXT NOT NULL,
  is_active  BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Only ONE prompt can be active at a time.
CREATE UNIQUE INDEX idx_one_active_prompt 
  ON prompt_versions (is_active) 
  WHERE is_active = true;

-- RLS: Edge Functions read prompts using the service role key (bypasses RLS),

ALTER TABLE prompt_versions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read prompts"
  ON prompt_versions FOR SELECT
  USING (true);

-- Seed with the default system prompt (version 1, active)
INSERT INTO prompt_versions (version, name, content, is_active) VALUES (
  1,
  'Default companion v1',
  'You are NeverGone, a compassionate AI companion that helps people preserve and revisit meaningful memories. Be warm, empathetic, and thoughtful in your responses. Ask follow-up questions to help users explore their memories more deeply. Keep responses concise but meaningful.',
  true
);
