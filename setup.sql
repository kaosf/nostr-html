CREATE TABLE IF NOT EXISTS nostr_events (
  id TEXT PRIMARY KEY NOT NULL,
  kind INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  body TEXT NOT NULL
) STRICT;

CREATE INDEX IF NOT EXISTS index_nostr_events_on_id ON nostr_events(id);
CREATE INDEX IF NOT EXISTS index_nostr_events_on_kind ON nostr_events(kind);
CREATE INDEX IF NOT EXISTS index_nostr_events_on_created_at ON nostr_events(created_at);

CREATE TABLE IF NOT EXISTS urls (
  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  nostr_event_id TEXT NOT NULL,
  body TEXT NOT NULL,
  UNIQUE(nostr_event_id, body)
) STRICT;

CREATE INDEX IF NOT EXISTS index_urls_on_id ON urls(id);
CREATE INDEX IF NOT EXISTS index_urls_on_nostr_event_id ON urls(nostr_event_id);

CREATE TABLE IF NOT EXISTS images (
  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  url_id INTEGER NOT NULL,
  mime_t TEXT NOT NULL,
  sha256 TEXT NOT NULL
) STRICT;

CREATE INDEX IF NOT EXISTS index_images_on_sha256 ON images(sha256);
