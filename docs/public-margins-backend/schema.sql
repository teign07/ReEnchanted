CREATE TABLE IF NOT EXISTS contributions (
  id TEXT PRIMARY KEY,
  request_id TEXT NOT NULL UNIQUE,
  event_id TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('souvenir', 'spark', 'choice', 'detail')),
  category TEXT,
  choice_id TEXT,
  encrypted_payload TEXT,
  payload_iv TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  deletion_token_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  moderated_at TEXT
);

CREATE INDEX IF NOT EXISTS contributions_status_created
  ON contributions(status, created_at DESC);
CREATE INDEX IF NOT EXISTS contributions_event_choice
  ON contributions(event_id, choice_id, status);

CREATE TABLE IF NOT EXISTS broadcasts (
  post_id TEXT PRIMARY KEY,
  text TEXT NOT NULL,
  author_name TEXT NOT NULL,
  author_username TEXT NOT NULL,
  author_avatar_url TEXT,
  permalink TEXT NOT NULL,
  created_at TEXT NOT NULL,
  fetched_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS broadcasts_created
  ON broadcasts(created_at DESC);

CREATE TABLE IF NOT EXISTS creator_posts (
  post_id TEXT PRIMARY KEY,
  creator_slug TEXT NOT NULL,
  text TEXT NOT NULL,
  author_name TEXT NOT NULL,
  author_username TEXT NOT NULL,
  author_avatar_url TEXT,
  permalink TEXT NOT NULL,
  created_at TEXT NOT NULL,
  fetched_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS creator_posts_created
  ON creator_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS creator_posts_creator
  ON creator_posts(creator_slug, created_at DESC);

-- X charges for every user resource returned. Cache stable account IDs and
-- display details so the daily post refresh does not buy the same profiles
-- again and again. Profiles are refreshed by the Worker after 30 days.
CREATE TABLE IF NOT EXISTS x_accounts (
  username_key TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  username TEXT NOT NULL,
  name TEXT NOT NULL,
  profile_image_url TEXT,
  refreshed_at TEXT NOT NULL
);
