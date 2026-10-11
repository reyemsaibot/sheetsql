# SheetSQL

SheetSQL ist eine native macOS-App, mit der Excel-Arbeitsblätter lokal per SQL analysiert werden können. Die Daten bleiben auf dem Mac; als SQL-Engine wird SQLite verwendet.

## Aktueller Umfang

- `.xlsx`- und `.xlsm`-Dateien öffnen und als SQL-Tabellen verwenden
- mehrere Arbeitsmappen und Arbeitsblätter gleichzeitig verwalten
- SQL-Editor mit Syntaxhervorhebung, Zeilennummern und Autovervollständigung
- Tabellen- und Spaltennamen per Klick in den Editor einsetzen
- `SELECT`, `JOIN`, `GROUP BY`, CTEs und Fensterfunktionen ausführen
- SQL-Parameter wie `:region` verwenden, ohne die Abfrage im Editor zu verändern
- Syntaxprüfung vor der Ausführung
- Verlauf und Favoriten für Abfragen
- Ergebnisse sortieren, filtern und durchsuchen
- Ergebnisse als CSV oder `.xlsx` exportieren
- Ergebnis-Tabs öffnen, schließen und vergleichen
- Arbeitsbereiche als `.sheetsql` speichern und laden
- Spaltenprofiling für Excel-Daten und aggregierte SQL-Ergebnisse
- visueller JOIN-Builder mit `INNER`, `LEFT` und `FULL OUTER JOIN`
- automatische Vorschläge für mögliche JOIN-Schlüssel
- JOIN-Analyse mit Trefferquote, Duplikat- und Leerwertprüfung
- gespeicherte Parameterprofile für wiederkehrende Abfragen
- SQLite-Abfrageplan zur Einordnung von Scans und Zugriffen
- Gruppierungs-/Pivot-Assistent für `SUM`, `AVG`, `MIN`, `MAX` und `COUNT`
- nicht-destruktive Datenbereinigungs-Demo für `TRIM`, `UPPER` und `REPLACE`

## Voraussetzungen

- macOS 14 oder neuer
- Swift 6 beziehungsweise Xcode Command Line Tools
- Apple Silicon oder Intel entsprechend der lokalen Swift-Installation

Die App arbeitet nach dem Build offline. Excel-Dateien werden direkt vom lokalen Dateisystem gelesen und nicht hochgeladen.

## Build und Start

```bash
./scripts/build-app.sh
open output/SheetSQL.app
```

Die Release-App wird unter `output/SheetSQL.app` erzeugt. Für die Tests:

```bash
swift test --disable-sandbox
```

## Bedienung

1. Excel-Datei öffnen oder die Beispieldaten laden.
2. Ein Arbeitsblatt auswählen und SQL eingeben.
3. Mit `⌘↵` ausführen.
4. Ergebnisse filtern, sortieren oder in einem neuen Tab öffnen.
5. Das Ergebnislimit lässt sich unter **SheetSQL > Einstellungen …** ändern; der Standardwert beträgt 10.000 Zeilen.

Wichtige Tastaturkürzel:

| Aktion | Kürzel |
| --- | --- |
| SQL ausführen | `⌘↵` |
| SQL prüfen | `⌘L` |
| SQL-Datei laden | `⇧⌘O` |
| SQL speichern | `⌘S` |
| Ergebnis-Tab öffnen | `⌥⌘T` |
| Excel-Ergebnis exportieren | `⌘E` |
| Arbeitsbereich speichern | `⌃⌘S` |

## SQL-Parameter

Parameter werden beim Ausführen abgefragt. Die Editor-Abfrage bleibt dabei unverändert:

```sql
SELECT *
FROM "Umsaetze"
WHERE "Region" = :region;
```

Texte werden sicher quotiert, Zahlen numerisch eingesetzt und `NULL` erkannt.

## Werkzeuge

Über **Werkzeuge** sind folgende Funktionen erreichbar:

- **Spaltenprofil:** Typ, leere Werte, eindeutige Werte, Beispiele, Minimum und Maximum.
- **Profil aktives SQL-Ergebnis:** dieselben Kennzahlen für aggregierte oder gefilterte Ergebnisse.
- **JOIN-Builder:** Tabellen und Spalten auswählen, Schlüsselvorschläge prüfen und SQL in den Editor übernehmen.
- **JOIN-Analyse:** Trefferquote sowie Duplikate und leere Schlüsselwerte vor dem Erzeugen des JOINs prüfen.
- **Abfrageplan:** SQLite-Zugriffsplan der aktuellen Abfrage anzeigen.
- **Gruppierungsassistent:** Eine `GROUP BY`-Auswertung aus Arbeitsblatt, Gruppenspalte, Wertspalte und Aggregation erzeugen.
- **Parameterprofile:** Werte für `:parameter` speichern und beim Ausführen wiederverwenden.
- **Datenbereinigung-Demo:** Auswirkungen typischer SQL-Bereinigungen vor der Ausführung nachvollziehen.

## Sinnvolle nächste Ergänzungen

1. **Nicht-destruktive Datenbereinigung auf Arbeitsblättern:** bereinigte Ansicht als neue virtuelle Tabelle erzeugen.
2. **Zusammengesetzte JOIN-Schlüssel:** mehrere Spalten als Schlüssel bewerten und vorschlagen.
3. **Automatisierte native UI-Tests:** zentrale Abläufe wie Öffnen, Einfügen, Ausführen, Tabwechsel und Schließen dauerhaft absichern.
4. **Exportprofile:** Spaltenauswahl, Datumsformat und Zielordner für wiederkehrende Exporte speichern.

## Daten und Grenzen

- Excel-Dateien werden als lesbare SQLite-Tabellen in einer temporären In-Memory-Datenbank verwendet.
- Schreibende SQL-Befehle sind gesperrt; SheetSQL ist ein Analysewerkzeug.
- Ergebnisse sind standardmäßig auf 10.000 Zeilen pro Abfrage begrenzt. Das Limit kann in den Einstellungen auf einen höheren Wert gesetzt werden.
- Arbeitsbereiche speichern Dateipfade, SQL, Verlauf und Favoriten. Die Excel-Dateien werden nicht kopiert.
- Die automatische JOIN-Erkennung liefert Vorschläge, ersetzt aber keine fachliche Prüfung der Schlüssel.

## Tests und Release-Status

Die Swift-Test-Suite deckt Excel-Import, SQL-Ausführung, Filterung, Sortierung, Tabs, Export, Arbeitsbereiche, Profiling und JOIN-Schlüsselerkennung ab. Native UI-Abläufe werden zusätzlich am erzeugten App-Bundle manuell geprüft.

Der aktuelle Stand ist ein lokaler Entwicklungsbuild (`0.1.0`). Eine Developer-ID-Signatur, Notarisierung und ein automatischer Update-Kanal sind noch nicht eingerichtet.

## Lizenz

Für das Projekt ist derzeit noch keine öffentliche Lizenz festgelegt.
