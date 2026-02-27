-- BC Beacon: Bestehende URL-Duplikate bereinigen
-- Ausführen auf der Produktions-DB (k349529_bcnews)
--
-- Problem: stefanmaron.onrender.com vs stefanmaron.com → gleiche Artikel doppelt
-- Problem: katson.com URLs mit ?utm_* Tracking-Parametern
--
-- Vorbereitung: Prüfe zuerst, was betroffen ist.

-- 1. Zeige alle onrender.com Duplikate
SELECT id, source_url, date, title
FROM posts
WHERE source_url LIKE '%stefanmaron.onrender.com%'
ORDER BY id;

-- 2. Zeige katson.com URLs mit UTM-Parametern
SELECT id, source_url
FROM posts
WHERE source_url LIKE '%katson.com%?utm_%';

-- 3. Bereinige: onrender.com → stefanmaron.com umschreiben
-- ACHTUNG: Bei Duplikaten (gleicher Pfad existiert schon unter .com)
-- wird das UPDATE durch den UNIQUE-Index fehlschlagen.
-- Daher: Erst die Duplikate löschen, dann umschreiben.

-- 3a. Lösche die onrender.com-Einträge, für die es bereits einen stefanmaron.com-Eintrag gibt
DELETE p2
FROM posts p2
INNER JOIN posts p1
  ON REPLACE(p2.source_url, 'stefanmaron.onrender.com', 'stefanmaron.com') = p1.source_url
WHERE p2.source_url LIKE '%stefanmaron.onrender.com%'
  AND p1.source_url LIKE '%stefanmaron.com%'
  AND p1.source_url NOT LIKE '%onrender%';

-- 3b. Schreibe verbleibende onrender.com-URLs um (die noch kein .com-Gegenstück haben)
UPDATE posts
SET source_url = REPLACE(source_url, 'stefanmaron.onrender.com', 'stefanmaron.com')
WHERE source_url LIKE '%stefanmaron.onrender.com%';

-- 4. UTM-Parameter von katson.com entfernen (alles ab ?utm_ abschneiden)
UPDATE posts
SET source_url = SUBSTRING_INDEX(source_url, '?utm_', 1)
WHERE source_url LIKE '%?utm_%';

-- 5. Ergebnis prüfen
SELECT COUNT(*) AS total_urls FROM posts;
SELECT source_url FROM posts WHERE source_url LIKE '%onrender%';
SELECT source_url FROM posts WHERE source_url LIKE '%utm_%';
