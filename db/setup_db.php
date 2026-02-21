<?php
/**
 * Einmaliges Setup-Script: Legt die posts-Tabelle in der Datenbank an.
 * Nach Ausführung bitte löschen!
 */
require_once __DIR__ . '/db_config.php';

try {
    $pdo = getDbConnection();
    echo "Verbindung zur Datenbank OK!\n";

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS `posts` (
            `id`          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            `title`       VARCHAR(500)      NOT NULL,
            `summary`     TEXT              NOT NULL,
            `source`      VARCHAR(255)      NOT NULL DEFAULT 'Unbekannt',
            `source_url`  VARCHAR(1000)     NOT NULL,
            `category`    VARCHAR(50)       NOT NULL DEFAULT 'News',
            `date`        DATE              NOT NULL,
            `tags`        JSON              DEFAULT NULL,
            `kw`          TINYINT UNSIGNED  NOT NULL COMMENT 'Kalenderwoche 1-53',
            `year`        SMALLINT UNSIGNED NOT NULL COMMENT 'Jahr',
            `created_at`  TIMESTAMP         DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY `uq_source_url` (`source_url`(500)),
            INDEX `idx_kw_year` (`year`, `kw`),
            INDEX `idx_date` (`date`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");

    echo "Tabelle 'posts' erfolgreich angelegt!\n\n";

    // Struktur anzeigen
    echo "Tabellenstruktur:\n";
    echo str_repeat('-', 60) . "\n";
    $result = $pdo->query('DESCRIBE posts');
    foreach ($result as $row) {
        printf("%-15s %-25s %s\n", $row['Field'], $row['Type'], $row['Key'] ?: '');
    }

    echo "\nFertig! Bitte diese Datei jetzt löschen (setup_db.php).\n";

} catch (PDOException $e) {
    echo "FEHLER: " . $e->getMessage() . "\n";
    exit(1);
}
