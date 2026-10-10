# Konkrete Abnahme unserer Apps

Stand: 10.10.2026. Diese Abläufe sind Anforderungen für zukünftige Prüfungen,
keine Meldung, dass sie bereits implementiert oder aktuell bestanden sind.
Mit synthetischen Fixtures und isolierten Datenorten prüfen. Fehlende Funktionen
als offen markieren; neueste Nutzerentscheidungen haben Vorrang vor historischen Vorgaben.

## Für jede App

1. Exakten Bundlepfad und Buildnummer feststellen; öffnen ohne Terminal-Abhängigkeit.
2. Kernablauf ausführen; Hauptaktionen müssen sichtbar und mit echten Klicks bedienbar sein.
3. Kleines, normales und großes Fenster prüfen; lange Texte und leere Zustände einbeziehen.
4. Menübefehle, relevante Shortcuts, Fokus und Rücknavigation prüfen.
5. Fenster schließen, über Dock wieder öffnen, App beenden und erneut starten.
   Persistente Daten und ausdrücklich definierte Sitzungszustände bleiben erhalten.
6. Finder, Dock während/nach Laufzeit und App-Umschalter zeigen dasselbe Motiv und
   den richtigen Namen. Sichtbare Icongröße passt zu allen benachbarten Icons;
   Vergleich ohne Hover-Vergrößerung, auch auf dunklem Hintergrund.
7. Fehlerzustand gezielt auslösen: verständliche Meldung, kein stiller Datenverlust,
   danach ist ein gültiger weiterer Versuch möglich.

## Minuto

| Ablauf | erwartetes Ergebnis |
| --- | --- |
| Timer starten → Ansicht wechseln → manuell buchen → Timer stoppen | Manuelle Buchung und Timer-Eintrag entstehen unabhängig, ohne Doppelbuchung. |
| Timer über Schlafmodus/Mitternacht; Neustart entsprechend Produktvertrag | Dauer folgt dem tatsächlichen Startzeitpunkt; Erhalt/Fortsetzung ist klar definiert. |
| Von und Bis auf denselben Tag setzen | Nur Einträge dieses lokalen Kalendertags; keine Einträge des Folgetags. |
| Filter auf Kunde/Projekt/Status/Zeitraum kombinieren | Liste, relevante Summen und CSV enthalten dieselbe definierte Auswahl. |
| Monatsnavigation mit Daten am Monatsanfang und -ende | Kalender und Monatssumme zeigen korrekte Zuordnung; leerer Monat ist verständlich. |
| Kunde → Projekt → Abrechnungsticket anlegen, favorisieren, archivieren | Auswahl und Zuordnung aktualisieren sich; historische Einträge bleiben erhalten. |
| Zeiteintrag abschließen, auch ohne hinterlegte Zuordnung | Neueste Abschlussregel gilt; fehlende Daten erzeugen keinen stillen Fehler. |
| CSV mit Notiz, Sonderzeichen und separaten Ticketfeldern exportieren | Jira- und Abrechnungsticket bleiben getrennt; CSV lässt sich korrekt wieder lesen. |
| JSON importieren / wiederherstellen / beschädigte Datei wählen | Definierter Konfliktmodus, vorherige Sicherung und Erhalt bei fehlgeschlagener Validierung. |
| Migration mit Altordner, mit vorhandenem Ziel und beim zweiten Start | Altbestand bleibt erhalten; Zieldaten werden nicht überschrieben oder erneut dupliziert. |

## Nori

| Ablauf | erwartetes Ergebnis |
| --- | --- |
| `⌘N` aus Inbox, Kanban und Kalender → erstellen → bearbeiten | Gemeinsamer Dialog, korrekte Zuordnung und definierter Anfangsstatus. |
| Task ohne Projekt mit Datum erstellen | Task erscheint in passenden globalen Datumsansichten und Suche. |
| Alle optionalen Dialogfelder aktivieren, Fenster verkleinern, scrollen | Titel/Bedienung bleiben erreichbar; keine abgeschnittenen Inhalte oder blockierten Klicks. |
| Reminder ohne/mit Due Date setzen, ändern, entfernen | Glocke ist anklickbar, Zeitpunkt sichtbar und nach Speichern/Reload korrekt. |
| Projekt wechseln, Parent/Blocked by/Milestone ändern | Gültige Auswahl, keine verlorenen Tasks oder ungültigen Hierarchien. |
| Neue und bestehende Tasks mit `⌘↩` speichern; Esc/Hintergrundklick | Definierte Speichern-/Verwerfen-Regel gilt in beiden Dialogzuständen. |
| Kanban mit vielen Karten; Gantt an Monats-/Jahresgrenze | Alles erreichbar; Datumslabels ohne Überlappung; Task-Klick öffnet richtigen Editor. |
| Anhänge hinzufügen → Original entfernen → Reload → Backup/Restore | App-eigene Kopie bleibt erreichbar; wiederhergestellte Referenzen zeigen auf vorhandene Dateien. |
| Projektfarbe ändern → Kalender und Sidebar öffnen | Farbe wird gespeichert und konsistent dargestellt. |
| Minuto-Zuordnung / Capture-URL mit kodierten Texten und Anhängen | Nur fachlich passende Einträge angeboten; Übergabe vollständig und ohne Doppelanlage. |
| iCloud mit zwei getrennten Testbeständen, Offline-Änderungen und Konflikt | Status entspricht tatsächlichem Zustand; keine still überschriebenen Änderungen. Bis dahin ungeprüft. |

## SheetSQL

| Ablauf | erwartetes Ergebnis |
| --- | --- |
| Datei öffnen → SQL tippen → zweite Datei importieren | SQL, Cursor und Entwurf bleiben erhalten; keine automatische Abfrage. |
| Spaltennamen mit Leerzeichen/Anführungszeichen einfügen | Korrekt zitierter Identifier an Cursorposition bzw. statt Textauswahl; keine Smart Quotes. |
| Mehrzeilig einfügen, scrollen und formatieren | Zeilennummern entsprechen Textlayout; Inhalt/Strings werden nicht unbeabsichtigt verändert. |
| SQL laden/speichern mit ungespeichertem Entwurf | Kein stilles Ersetzen; UTF-8-`.sql` und definierte Speichern-/Verwerfen-Regel. |
| Ausführen → neuer Ergebnis-Tab → maximiert → SQL-Konsole → zurück → × | Jeder Wechsel und echtes Schließen funktioniert; Aktionsleiste erscheint korrekt. |
| Mehrere Ergebnis-Tabs unterschiedlich filtern/sortieren | Zustände unabhängig; CSV exportiert ausgewählten Tab; neue Abfrage verändert alte Tabs nicht. |
| Quelle schließen, zuletzt geöffnete Datei schließen | Aktueller Produktvertrag für Startbildschirm/Editor/Tabs gilt; keine veraltete Auswahl. |
| Text-ID `00001234`, NULL, leerer Text, Zahlen und JOIN importieren/abfragen | Fachliche Unterschiede bleiben erhalten; Ergebnisse mit Sollwerten vergleichen. |
| Mehr Zeilen als Ergebnislimit abfragen | Begrenzung sichtbar; „vollständig“ nur melden, wenn tatsächlich vollständig geladen/exportiert. |
| Ungültige SQL- und rechenintensive Abfrage, danach gültige Abfrage | Sichtbare Fehler/Timeouts; App bleibt bedienbar, anschließende Abfrage funktioniert. |

## DataScope

| Ablauf | erwartetes Ergebnis |
| --- | --- |
| CSV/TSV mit deutschen Zahlen, NULL, Leertext, Whitespace und Text-IDs | Kennzahlen stimmen mit unabhängigen Sollwerten; keine stillen Typverluste. |
| XLSX mit mehreren Blättern und Daten hinter Leerzeilen | Gewähltes Blatt wird vollständig importiert; keine vorzeitige Beendigung an Leerzeile. |
| Große Datei analysieren, Fenster bedienen und abbrechen | UI bleibt bedienbar; Worker beendet; temporäre Ressourcen werden nach Freigabe entfernt. |
| Lauf A abbrechen, Lauf B starten | Späte Status-/Ergebnismeldungen von A überschreiben B nicht. |
| Fehlerhaften Import auslösen, danach gültige Datei analysieren | Sichtbarer Parserfehler; kein unbemerktes Überspringen; nächster Lauf funktioniert. |
| Vorschau und Kennzahlen vergleichen | Vorschau begrenzt, Kennzahlen über vollständigen Import; Unterschied sichtbar erklärt. |
| Gebündelte App nach Setup offline starten | Engine/Excel-Erweiterung ohne Entwicklungsordner oder Laufzeitdownload verfügbar. |
| Benchmark mit definiertem Fixture wiederholen | Zeilen/Spalten, Hardware, Laufzeit und Speichermessung angegeben; keine pauschale Leistungsgarantie. |
| Absturz/Neustart mit verwaistem Analyseordner | Gezieltes Crash-Aufräumen gemäß Implementierungsstand; bis Umsetzung als offen führen. |

## Prüfprotokoll zum Kopieren

```text
Datum / App:
Commit / Version / Buildnummer:
Bundlepfad / macOS / Architektur:
Fixture / isolierter Datenort:
Automatisierte Tests und Ergebnis:
UI-Ablauf → Soll → Ist → bestanden/fehlgeschlagen/ungeprüft:
Dock-/Iconvergleich / Fenstergrößen / Screenshotreferenzen:
Offene Punkte und Grund:
```

Diese Checklisten werden bei neuen Regressionen ergänzt. Größere neue Funktionen
bekommen eigene Abnahmekriterien; hier wird kein noch nicht beauftragter Ausbau gestartet.
