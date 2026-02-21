-- ============================================================
-- SQL-Schema für BC News Hub
-- Erstelle diese Tabelle in deiner MySQL-Datenbank.
-- ============================================================

CREATE TABLE IF NOT EXISTS `posts` (
  `id`         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `title`      VARCHAR(500)  NOT NULL,
  `summary`    TEXT          NOT NULL,
  `source`     VARCHAR(255)  NOT NULL DEFAULT 'Unbekannt',
  `source_url` VARCHAR(1000) NOT NULL,
  `date`       DATE          NOT NULL,
  `kw`         TINYINT UNSIGNED NOT NULL COMMENT 'Kalenderwoche (1-53)',
  `year`       SMALLINT UNSIGNED NOT NULL COMMENT 'Jahr',
  `created_at` TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,

  -- Verhindert Duplikate basierend auf der Quell-URL
  UNIQUE KEY `uq_source_url` (`source_url`(500)),

  -- Für schnelle KW-/Jahresfilterung
  INDEX `idx_kw_year` (`year`, `kw`),

  -- Für Sortierung nach Datum
  INDEX `idx_date` (`date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- Newsletter-Subscriber
-- Speichert E-Mail-Adressen für den wöchentlichen Newsletter.
-- Double-Opt-In: Eintrag wird mit confirmed_at = NULL erstellt,
-- erst nach Bestätigung wird confirmed_at gesetzt.
-- ============================================================

CREATE TABLE IF NOT EXISTS `newsletter_subscribers` (
  `id`           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `email`        VARCHAR(320)  NOT NULL,
  `token`        CHAR(64)      NOT NULL COMMENT 'Bestätigungstoken (Double-Opt-In)',
  `confirmed_at` TIMESTAMP     NULL DEFAULT NULL COMMENT 'NULL = noch nicht bestätigt',
  `created_at`   TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  `unsubscribed_at` TIMESTAMP  NULL DEFAULT NULL COMMENT 'Abmeldezeitpunkt',

  UNIQUE KEY `uq_email` (`email`),
  INDEX `idx_token` (`token`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- Newsletter-Versandprotokoll
-- Verhindert doppelten Versand: Pro Subscriber + KW/Jahr nur ein Eintrag.
-- ============================================================

CREATE TABLE IF NOT EXISTS `newsletter_send_log` (
  `id`            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `subscriber_id` INT UNSIGNED NOT NULL,
  `kw`            TINYINT UNSIGNED NOT NULL COMMENT 'Kalenderwoche',
  `year`          SMALLINT UNSIGNED NOT NULL COMMENT 'Jahr',
  `sent_at`       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  -- Ein Subscriber kann pro KW/Jahr nur einmal eine Mail bekommen
  UNIQUE KEY `uq_subscriber_kw_year` (`subscriber_id`, `kw`, `year`),

  FOREIGN KEY (`subscriber_id`) REFERENCES `newsletter_subscribers`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- Kategorien
-- Jeder Post hat genau eine Kategorie (Spalte posts.category).
-- Die Tabelle definiert gültige Kategorien mit optionaler Farbe.
-- Farbe: Hex-Code für Badge-Hintergrund, NULL = Standard (Accent).
-- ============================================================

CREATE TABLE IF NOT EXISTS `categories` (
  `id`          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `name`        VARCHAR(100) NOT NULL COMMENT 'Anzeigename der Kategorie',
  `slug`        VARCHAR(100) NOT NULL COMMENT 'URL-freundlicher Slug',
  `description` VARCHAR(500) DEFAULT NULL COMMENT 'Optionale Beschreibung',
  `color`       VARCHAR(7)   DEFAULT NULL COMMENT 'Hex-Farbe z.B. #7c3aed (NULL = Standardfarbe)',
  `created_at`  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,

  UNIQUE KEY `uq_category_name` (`name`),
  UNIQUE KEY `uq_category_slug` (`slug`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- Tags
-- Einheitliches Konzept für Themen-Zuordnung (ersetzt Kategorien + Tags).
-- Jeder Post kann beliebig viele Tags haben (n:m).
-- Der erste Tag eines Posts dient als primäres Thema (Badge/Farbe).
-- ============================================================

CREATE TABLE IF NOT EXISTS `tags` (
  `id`          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `name`        VARCHAR(100) NOT NULL COMMENT 'Anzeigename des Tags',
  `slug`        VARCHAR(100) NOT NULL COMMENT 'URL-freundlicher Slug',
  `description` VARCHAR(500) DEFAULT NULL COMMENT 'Optionale Beschreibung',
  `color`       VARCHAR(7)   DEFAULT NULL COMMENT 'Optionale Hex-Farbe z.B. #7c3aed',
  `created_at`  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,

  UNIQUE KEY `uq_tag_name` (`name`),
  UNIQUE KEY `uq_tag_slug` (`slug`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- Standard-Tags einfügen (mit Farben für Haupt-Themen)
-- ============================================================

INSERT IGNORE INTO `tags` (`name`, `slug`, `description`, `color`) VALUES
  ('News',           'news',           'Allgemeine Business Central Neuigkeiten', '#0284c7'),
  ('Entwicklung',    'entwicklung',    'AL-Code, Extensions, Programmierung',     '#7c3aed'),
  ('Cloud',          'cloud',          'Cloud-Migration, SaaS, Azure',            '#d97706'),
  ('Updates',        'updates',        'Releases, Waves, kumulative Updates',     '#4f6ef7'),
  ('Community',      'community',      'Community-Events, MVPs, User Groups',     '#0d9488'),
  ('Tipps',          'tipps',          'Praxistipps und Best Practices',          '#059669'),
  ('AL',             'al',             'AL-Programmiersprache',                   '#7c3aed'),
  ('API',            'api',            'API-Entwicklung und Integrationen',       '#059669'),
  ('Azure',          'azure',          'Microsoft Azure Cloud',                   '#d97706'),
  ('Copilot',        'copilot',        'KI-Copilot in Business Central',          '#db2777'),
  ('Docker',         'docker',         'Container und DevOps',                    '#7c3aed'),
  ('Erweiterungen',  'erweiterungen',  'App-/Extension-Entwicklung',              '#7c3aed'),
  ('On-Premises',    'on-premises',    'Lokale Installation',                     '#d97706'),
  ('Performance',    'performance',    'Performance-Optimierung',                 '#db2777'),
  ('Power Platform', 'power-platform', 'Power Automate, Power BI, etc.',          '#059669'),
  ('SaaS',           'saas',           'Software as a Service',                   '#d97706'),
  ('Sicherheit',     'sicherheit',     'Sicherheit und Berechtigungen',           '#dc2626'),
  ('Upgrade',        'upgrade',        'Versions-Upgrades',                       '#4f6ef7'),
  ('Wave 1',         'wave-1',         'Release Wave 1 (Frühjahr)',               '#4f6ef7'),
  ('Wave 2',         'wave-2',         'Release Wave 2 (Herbst)',                 '#4f6ef7'),
  ('Administration', 'administration', 'Verwaltung und Konfiguration',            '#d97706'),
  ('Integration',    'integration',    'Schnittstellen und Drittsysteme',         '#059669'),
  ('KI',             'ki',             'Künstliche Intelligenz',                  '#db2777'),
  ('Release',        'release',        'Neue Releases und Versionen',             '#4f6ef7');


-- ============================================================
-- Tags (already defined above)
-- ============================================================


-- ============================================================
-- Verknüpfungstabelle: Posts ↔ Tags (n:m)
-- Ein Post kann viele Tags haben, ein Tag kann vielen Posts zugeordnet sein.
-- ============================================================

CREATE TABLE IF NOT EXISTS `post_tags` (
  `post_id` INT UNSIGNED NOT NULL,
  `tag_id`  INT UNSIGNED NOT NULL,

  PRIMARY KEY (`post_id`, `tag_id`),

  FOREIGN KEY (`post_id`) REFERENCES `posts`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`tag_id`)  REFERENCES `tags`(`id`)  ON DELETE CASCADE,

  INDEX `idx_tag_id` (`tag_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- Standard-Tags (already inserted above)
-- ============================================================


-- ============================================================
-- Newsletter-Tag-Präferenzen (n:m)
-- Verknüpft Subscriber mit den Tags, die sie interessieren.
-- Wenn ein Subscriber KEINE Einträge hat → erhält ALLE Posts.
-- ============================================================

CREATE TABLE IF NOT EXISTS `subscriber_tags` (
  `subscriber_id` INT UNSIGNED NOT NULL,
  `tag_id`         INT UNSIGNED NOT NULL,

  PRIMARY KEY (`subscriber_id`, `tag_id`),

  FOREIGN KEY (`subscriber_id`) REFERENCES `newsletter_subscribers`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`tag_id`)         REFERENCES `tags`(`id`) ON DELETE CASCADE,

  INDEX `idx_tag_id` (`tag_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- Beispiel-INSERT (so wie n8n ihn ausführen würde):
-- ============================================================
-- INSERT IGNORE INTO posts (title, summary, source, source_url, date, kw, year)
-- VALUES (
--   'Neues Feature in BC Wave 2',
--   'Microsoft hat ein neues Feature für Business Central angekündigt...',
--   'Microsoft Blog',
--   'https://example.com/artikel',
--   '2026-02-15',
--   7,
--   2026
-- );
-- Danach Tags zuweisen:
-- INSERT IGNORE INTO post_tags (post_id, tag_id)
-- SELECT LAST_INSERT_ID(), id FROM tags WHERE name IN ('Development', 'Wave 2');
