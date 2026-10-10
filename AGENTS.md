# Arbeitsregeln für unsere macOS-Apps

Stand: 10.10.2026. Gilt für diesen Workspace und als Vorlage für die nächste App.
Grundlage: Nori, Minuto, SheetSQL und DataScope. Die ausführliche Fehler- und
Erkenntnissammlung steht in [docs/APP-ERKENNTNISSE.md](docs/APP-ERKENNTNISSE.md),
konkrete Prüfabläufe in [docs/APP-ABNAHME.md](docs/APP-ABNAHME.md).
Bei einer neuen App diese Dateien in deren Projekt übernehmen und die
projektspezifischen Angaben aktualisieren. Aktuelle Nutzeranweisungen haben Vorrang.

## 1. Vor dem ersten Code

- Projektordner, Git-Root, aktuelle Änderungen und vorhandene Anweisungen prüfen.
  Mehrere Apps liegen hier nebeneinander; niemals fremde Änderungen überschreiben.
- Neue Apps in einem eigenen Unterordner und bei Bedarf eigenem Repository anlegen.
  Nori liegt am Workspace-Root; Minuto unter `minuto/`, SheetSQL unter `SheetSQL/`,
  DataScope unter `DataScope/`. Ordnernamen sind keine zuverlässigen Produktnamen.
- Kurz festhalten: Zielgruppe, Hauptablauf, MVP, bewusst spätere Funktionen,
  unterstützte macOS-Version, CPU-Architektur, Sprache, Datenformate und Datenort.
- App-Name, Bundle-ID, ausführbare Datei und Ausgabeort früh festlegen.
  Bundle-ID und Datenpfade bei Updates stabil halten oder gezielt migrieren.
- Referenz-Apps und Screenshots in konkrete Anforderungen übersetzen: Anordnung,
  Aktionen, Standardzustände, leere Zustände, Navigation und Fensterverhalten.
- Für größere Apps einen dauerhaften Plan mit Etappen und Abnahmekriterien anlegen.
  Zuerst einen vollständigen Kernablauf bauen: öffnen → arbeiten → speichern/exportieren.

## 2. Technik und Aufbau

- Für unsere lokalen Mac-Apps native SwiftUI-Oberflächen bevorzugen. AppKit gezielt
  für Texteditoren, Tabellen, Fenster, Fokus und Interaktionen einsetzen.
  Bestehende funktionierende Architektur nur bei begründetem Bedarf ändern.
- Datenmodell, Persistenz, Fachlogik und UI trennen. Keine dauerhaft riesige Datei
  mit der gesamten App; kleine Views und wiederverwendbare Dialoge verwenden.
- Erstellen und Bearbeiten desselben Objekts teilen dieselben Komponenten.
- Datenimport, SQL und Profiling außerhalb des MainActor ausführen; UI-Änderungen
  auf dem MainActor. Abbruch und Lebensdauer von Workern explizit behandeln.
- Swift-6-Isolation, Sendable-Captures, Initialisierungsreihenfolge und Cleanup
  von Event-Monitoren beachten. Concurrency-Probleme nicht durch pauschales
  Abschalten von Prüfungen verdecken. Property-Wrapper pro Variable deklarieren.
- Bibliotheksversionen und Downloads fixieren, Prüfsummen und Lizenzen dokumentieren.
  Dynamische Bibliotheken ins Bundle packen und relative Laufzeitpfade verwenden.
- „Lokal/offline“ muss nach dem Setup ohne Server und ohne Laufzeitdownload funktionieren.

## 3. Oberfläche und Bedienung

- Ruhiges macOS-Design: Systemschrift, klare Hierarchie, zurückhaltende Akzentfarbe,
  einheitliche Rahmen, Abstände und Ausrichtung. Keine überflüssigen Erklärtexte.
- Symbolaktionen bevorzugt mit SF Symbols darstellen; Bedeutung pro Symbol konsistent
  halten. Tooltip und Accessibility-Label ergänzen, stabile UI-IDs für wichtige Aktionen.
- Sichtbare Symbolgröße und Klickfläche getrennt behandeln: als Projektstartwert
  14–18 pt für kleine UI-Symbole und mindestens 24 × 24 pt für ihre Klickfläche.
  Dies sind unsere Startwerte, keine universelle Apple-Vorgabe; praktisch prüfen.
- Hauptaktionen bleiben sichtbar. Seltene Aktionen ins Menü/Kontextmenü;
  optionale Felder erst bei Bedarf anzeigen. Keine doppelten Schalter für dieselbe Option.
- Einstellungen über App-Menü und `⌘,`; neue Objekte über Menü und `⌘N`, bei Bedarf
  `⇧⌘N`. Kürzel sollen in allen passenden Ansichten funktionieren.
- Dialoge haben eine sinnvolle Start- und Mindestgröße, echtes Resize-Verhalten und
  vertikales Scrollen. Titel und Hauptaktionen dürfen nicht abgeschnitten werden.
- Kleine Fenster, Standardgröße und maximierte Ansicht prüfen; lange Inhalte und
  viele optionale Felder einbeziehen. Gantt/Tabellen dürfen Inhalte nicht verstecken.
- Keine unsichtbaren Views oder Overlays über Klickflächen liegen lassen.
  Getrennte Aktionen wie Tab-Auswahl und × erhalten eigene Buttons.
- Nach Navigation Text, Cursor, Filter und Auswahl gezielt erhalten oder zurücksetzen.
  Verhalten beim Schließen des letzten Dokuments ausdrücklich definieren und testen.
- Sprache pro App konsequent führen. Status nicht nur über Farbe vermitteln.
- Unsaved-Changes-Verhalten definieren; die gewünschte Schließlogik eines bestehenden
  Dialogs erhalten. Kein Neustart mit ungesicherten Inhalten für einen UI-Test.

## 4. Icons sind Teil des ersten nutzbaren Builds

### Motiv, Transparenz und sichtbare Größe

- Eine dauerhafte Masterquelle verwenden: für die bisherige PNG/ICNS-Pipeline
  1024 × 1024 px, quadratisch, mit echtem Alphakanal. Kein Screenshot als Master.
- Außenbereich und Ecken transparent halten, wenn das gewählte Motiv dies verlangt.
  Kein schwarzes/weißes Hintergrundquadrat, keine Halo-Ränder, keine doppelte Maske.
  „hasAlpha“ allein genügt nicht: Eckpixel und Übergänge prüfen, auf hell und dunkel ansehen.
- Dunkle Teile des Motivs erhalten. Nicht global alle schwarzen Pixel löschen.
- Die sichtbare Motivfläche entscheidet über die Dock-Größe, nicht die PNG-Abmessung.
  Unsere Startorientierung: Motiv etwa 80–90 % der Canvasbreite, zentriert;
  Schatten und optisches Gewicht berücksichtigen. Kein verbindlicher Apple-Prozentsatz.
- Das App-Icon muss im Dock in seiner sichtbaren Größe mit allen anderen Icons
  übereinstimmen: Es darf weder auffällig größer noch kleiner wirken. Gleiche
  PNG-Abmessungen allein erfüllen diese Anforderung nicht.
- Direkt neben den anderen App- und System-Icons im selben Dock bei gleicher
  Dock-Skalierung und ohne Hover-Vergrößerung vergleichen; Nori und Minuto zusätzlich
  als Referenz verwenden. Sichtbare Motivhöhe/-breite, Außenabstände und optisches
  Gewicht abstimmen. Größenkorrektur einmal am Master durchführen, anschließend
  alle Varianten neu erzeugen und den Vergleich im fertigen Build wiederholen.
- App-/Dock-Icon und transparentes Logo in Sidebar/Startansicht aus demselben Motiv
  ableiten. Ein Logo ohne Hintergrund darf eine eigene exportierte Datei haben.
- Bei neuen Icon-Composer-/Asset-Catalog-Projekten die passende aktuelle Apple-Pipeline
  verwenden. Die folgende Tabelle gilt für unsere klassische `.iconset`/`.icns`-Pipeline,
  nicht pauschal für iOS oder jede moderne Icon-Composer-Datei.

### Vollständiges klassisches macOS-Iconset

| Datei | tatsächliche PNG-Größe |
| --- | --- |
| `icon_16x16.png` | 16 × 16 px |
| `icon_16x16@2x.png` | 32 × 32 px |
| `icon_32x32.png` | 32 × 32 px |
| `icon_32x32@2x.png` | 64 × 64 px |
| `icon_128x128.png` | 128 × 128 px |
| `icon_128x128@2x.png` | 256 × 256 px |
| `icon_256x256.png` | 256 × 256 px |
| `icon_256x256@2x.png` | 512 × 512 px |
| `icon_512x512.png` | 512 × 512 px |
| `icon_512x512@2x.png` | 1024 × 1024 px |

Dateinamen folgen Apples [Iconset-Format](https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/IconSetType.html).
Aus einem validierten Set mit `iconutil --convert icns` bauen. „Invalid Iconset“
ist ein Fehler: Dateinamen, Maße und PNG-Daten prüfen; nicht eine alte ICNS weiterkopieren.
Ein eigener ICNS-Writer ist nur ein geprüfter Fallback. Vorhandene Writer nicht
ungeprüft übernehmen; Container und Darstellungen im Ergebnis kontrollieren.

### Bundle und Dock

- Die ICNS muss tatsächlich unter `Contents/Resources/` liegen; `CFBundleIconFile`
  muss auf diese Datei zeigen. Bei Asset Catalogs zusätzlich den korrekten Asset-Namen
  über `CFBundleIconName` setzen und kompilierte Assets mitliefern. Eine lose ICNS
  wird durch `CFBundleIconName` allein nicht zum Asset Catalog.
- `.app`-Name, `CFBundleName`, `CFBundleDisplayName` und `CFBundleExecutable` stimmen
  mit dem Produkt überein; die angegebene ausführbare Datei muss existieren.
  Details: [Apple Bundle-Schlüssel](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html).
- `NSApplication.shared.applicationIconImage` ersetzt kein korrektes Bundle-Icon.
  Ein Laufzeit-Override darf kein anderes Motiv liefern als Finder und beendetem Dock-Eintrag.
- Erst Ressourcen/Plist/Bibliotheken fertigstellen, dann signieren. Nach Änderungen neu signieren.
- Dock-Prüfung: korrekten Build öffnen, laufendes Icon und Namen ansehen, App beenden,
  verbleibenden angehefteten Eintrag ansehen, erneut öffnen; zusätzlich Finder und `⌘Tab`.
- Bei falschem Icon zuerst gestarteten Bundlepfad, alte Kopien, Plist, ICNS und
  Laufzeit-Override prüfen. Buildnummer regulär erhöhen; das garantiert keine Cache-Löschung.
- Cache-Reset oder Dock-Neustart erst nach belegtem Cacheproblem gezielt einsetzen.
  Nicht als Standardkorrektur, keine Bundle-ID-Änderung nur zur Cache-Umgehung.
- Ohne tatsächliche Sichtprüfung lautet das Ergebnis „Bundle geprüft, Dock noch ungeprüft“.
  Nie „Dock korrigiert“ allein aus einem erfolgreichen Build ableiten.

## 5. Daten und Fachlogik

- Nutzerdaten außerhalb von Repository und App-Bundle in Application Support speichern.
  Tests ausschließlich mit synthetischen Daten und eigenen temporären Ordnern ausführen.
- Datenformate versionieren, alte Felder kompatibel lesen und atomar speichern.
  Vor Wiederherstellung/Migration sichern; vorhandene Zieldaten nicht still überschreiben.
- Umbenennung oder Technologiewechsel braucht einen geprüften Migrationspfad.
  Stammdaten und Anhänge in Backup-/Restore-Konzept einbeziehen.
- Fehler sichtbar melden; fehlende optionale Dateimetadaten dürfen gültige Anhänge
  nicht blockieren. Dateizugriff, Größenlimits und Kopieren separat behandeln.
- Datumsfilter über lokale Kalendertage definieren: `>= startOfDay(von)` und
  `< startOfDay(bis) + 1 Kalendertag`. Keine feste 24-Stunden-Arithmetik bei Sommerzeit.
- NULL, leerer Text, Whitespace, führende Nullen und Zahlen fachlich unterscheiden.
  Deutsche Zahlen und Excel-Datums-/Formelwerte ausdrücklich berücksichtigen.
- Codeeditoren: Smart Quotes, automatische Textersetzung und Rechtschreibkorrektur
  deaktivieren. Identifier korrekt quoten; Zeilennummern aus dem Textlayout ableiten.
- Dateiimport darf bestehendes SQL nicht verändern oder automatisch ausführen.
  Vorschau, begrenztes Ergebnis und Vollanalyse unterscheiden; Limits sichtbar benennen.
- UI-Filter, Summen und Export müssen dieselbe definierte Datenmenge verwenden.
  Ergebnis-Tabs behalten ihre eigenen Daten, Filter und Sortierung.
- Sync ist kein lokales Backup. Konflikte, Offline-Verhalten, Anhänge und tatsächliche
  Verfügbarkeit testen, bevor eine Integration als vollständig funktionsfähig gilt.

## 6. Reproduzierbarer Build und Auslieferung

- Ein dokumentiertes Build-Skript pro App: aus richtigem Projektordner starten,
  Fehler abbrechen, Pfade mit Leerzeichen quoten und nur eigene Outputs bereinigen.
- Writable, appspezifische Swift-/Clang-Caches verwenden, falls Systemcaches gesperrt sind.
  Keine Systemvariablen wie zshs `status` als eigene Ergebnisvariable verwenden.
- Development und Release unterscheiden. Nutzer-Builds nach Möglichkeit optimiert
  erzeugen; Architektur und Minimum-OS stimmen mit Bibliotheken und Plist überein.
- App-Bundle enthält nur Laufzeitdateien. `.build`, Compiler-Caches, `node_modules`,
  Testdaten und überflüssige Masterbilder gehören nicht ins verteilte Paket.
- Bundlegröße, Buildcache und Fenstergröße getrennt benennen, wenn „App zu groß“ gemeint ist.
- Dynamische Bibliotheken innen zuerst signieren, dann äußeres Bundle. Signierte
  DuckDB-Erweiterungsbytes nicht nachträglich verändern.
- `plutil -lint`, Existenz/Executable-Bit der Binärdatei und
  `codesign --verify --deep --strict` auf dem fertigen Bundle prüfen.
- Lokales Ad-hoc-Signing ist kein öffentlich geprüfter Release. Developer ID,
  Notarisierung, Updateweg und zweiter Mac gehören in eine eigene Release-Etappe.
- README enthält aktuelle Funktionen, Build/Start, Datenorte, Migration, Shortcuts,
  Grenzen, Tests, Lizenz und ehrlichen Release-Status. Nach Architekturwechsel aktualisieren.

## 7. Abnahme nach jedem ausgelieferten Build

1. Geänderte Fachlogik und bekannte Regressionen gezielt automatisiert testen.
2. Fertiges Bundle prüfen und genau dieses Bundle starten; Pfad/Version kontrollieren.
3. Hauptablauf und angrenzende bisher funktionierende Aktionen in der UI durchführen.
   Bei UI-Änderungen zählen sichtbare Darstellung UND echte Klicks/Tastatureingaben.
4. Navigation, Zurückwechseln, Tab-Schließen, letzter-Datei-Zustand, Menüs und
   relevante Shortcuts prüfen. Accessibility-Einträge allein beweisen keine Bedienbarkeit.
5. Bei Layoutänderungen Resize und lange Inhalte prüfen; bei Datenänderungen Reload,
   Import/Export und betroffene Migration prüfen; bei Iconänderungen Abschnitt 4 abnehmen.
6. Pro Build knapp dokumentieren: Bundlepfad/Version, Tests, tatsächlich ausgeführte
   UI-Abläufe, Ergebnis und verbleibende ungeprüfte Punkte. Screenshots bei visuellen Änderungen.
7. Erst dann Abschluss melden. „Kompiliert“, „Tests grün“, „UI geprüft“ und
   „Release bereit“ sind unterschiedliche Aussagen.

Wenn UI-Zugriff, Signierzertifikat oder Zweitgerät fehlt, vorhandene Prüfungen
abschließen und die konkrete Lücke benennen. Keine Abnahme erfinden.

## 8. Erkenntnisse pflegen

Bei einem neuen Fehler die Chronik ergänzen: App, Symptom, belegte Ursache oder
offene Hypothese, Korrektur, Regressionstest/Prüfung und Status. Wiederkehrende
Fehler zusätzlich in diese Arbeitsregeln aufnehmen. Frühere Erfolgsmeldungen
gelten nicht als Beweis, wenn spätere Nutzerberichte sie widerlegen.


## 9 End every task with a full accounting 
 Conclude every task with:
 
- **Completed:** what was analyzed, changed, or delivered.
- **Evidence consulted:** local files, SAP objects, interfaces, DDIC metadata, standard callers, and experiments used.
- **Verification:** syntax checks, tests, read-only experiments, release checks, or inspections performed and their results.
- **Not done:** skipped edge cases, omitted tests, deferred cleanup, inaccessible evidence, or intentionally excluded work.
- **Assumptions: ** every assumption made under rule 2A.
- **Unresolved issues:** code smells, design concerns, migration risks, or technical debt noticed but left untouched to remain within scope. 

## 10. Steckbrief und überprüfbare Designentscheidungen

Für jede neue App vor dem Ausbau eine kurze `docs/APP-STECKBRIEF.md` ausfüllen:

| Feld | festzuhalten |
| --- | --- |
| Produkt | App-Name, Zweck, Zielnutzer, Hauptablauf |
| Umfang | MVP, spätere Etappen, ausdrücklich nicht zugesagte Funktionen |
| Technik | macOS-Minimum, CPU-Architektur, UI-/Engine-Technik, Abhängigkeiten |
| Identität | Bundle-ID, Binärname, Build- und installierter App-Pfad |
| Daten | Speicherort, Schema-Version, Import/Export, Backup und Migration |
| Bedienung | Sprache, Standardansicht, Menüs, Shortcuts, Schließ-/Speicherverhalten |
| Gestaltung | Referenzbilder, Fenstergrößen, Schriftgrößen, Abstände, Symbolgrößen |
| Abnahme | Kernabläufe, erwartete Ergebnisse, Grenzen, offene Annahmen |

- Designwerte in gemeinsamen Konstanten/Komponenten halten. Wiederholte lokale
  Anpassungen von Padding, Schrift und Buttonstil sollen nicht auseinanderlaufen.
- Pro zentraler Ansicht eine datierte Referenz mit synthetischen Inhalten ablegen;
  Fenstergröße und Zustand nennen. Screenshot belegt Gestaltung, kein Klickverhalten.
- Neueste Nutzerentscheidung gegen ältere Vorgaben abgleichen. Änderungen am
  Produktvertrag im Steckbrief festhalten; historische Wünsche nicht ungeprüft mischen.

## 11. App-Lebenszyklus, Persistenz und Wiederherstellung

- Fenster schließen, Dokument schließen und App beenden sind unterschiedliche Aktionen.
  Verhalten ausdrücklich definieren, einschließlich Wiederöffnen über das Dock.
- Ein Timer basiert auf gespeichertem Startzeitpunkt, nicht auf gezählten UI-Ticks.
  Schlafmodus, Mitternacht, App-Neustart und Zeitzonenwechsel dürfen Zeiten nicht
  verlieren oder doppelt buchen. Gewünschte Fortsetzung nach Neustart festlegen.
- Ungesicherte Editorzustände bei Navigation und Hintergrundarbeit erhalten.
  Vor automatisiertem Neustart prüfen, ob ein aktiver Timer oder Entwurf betroffen ist.
- Import zuerst vollständig validieren, dann übernehmen. Bei Fehler/Abbruch darf
  kein halb importierter Bestand als erfolgreich erscheinen. Konflikte über stabile IDs
  nach einer dokumentierten Regel behandeln; wiederholter Import darf nicht blind duplizieren.
- Backup/Wiederherstellung auf Vollständigkeit prüfen: Daten, Stammdaten und referenzierte
  Anhänge. Bei bewusst unvollständigen Exporten deren Umfang deutlich nennen.
- Temporäre Analyse-/Importdateien nur im eigenen Arbeitsordner aufräumen. Nach
  Absturz verwaiste Dateien beim nächsten Start erkennen, ohne fremde Dateien zu löschen.

## 12. Hintergrundarbeit, Fehler und reproduzierbare Diagnose

- Jede Analyse/Abfrage hat einen eigenen Laufzustand. Ein spät eintreffendes Ergebnis
  eines abgebrochenen oder ersetzten Laufs darf die aktuelle Ansicht nicht überschreiben.
- Während laufender Arbeit Doppelklicks, erneut starten, Quelle schließen und App beenden
  berücksichtigen. Ressourcen erst freigeben, wenn der Worker sie nicht mehr verwendet.
- Für relevante Fehler eine verständliche Meldung mit möglichem nächsten Schritt zeigen.
  Technische Details optional erreichbar machen; kein stilles Leeren der Ansicht.
- Diagnose enthält App-Version/Build, Aktion und Fehlerkategorie. Persönliche Inhalte,
  SQL-Literale und vollständige Dateipfade nicht ungeprüft protokollieren.
- Bei einem Fehler erst reproduzierbaren Fall und erwartetes Ergebnis festhalten,
  dann Ursache prüfen. Nach Korrektur denselben Fall plus angrenzenden Ablauf wiederholen.
- Eine bereits als behoben gemeldete Regression verlangt eine Ursachenanalyse;
  nicht weitere lokale Layout-Patches ohne Erklärung aufschichten.
- Beim Umbau von Architektur/Engine eine Funktionsliste vorher/nachher vergleichen.
  Datenmigration, Shortcuts und Exportfelder gehören ebenso dazu wie sichtbare Ansichten.

## 13. Konkrete Regressionen und nachvollziehbare Builds

- Die appbezogenen Abläufe aus [APP-ABNAHME.md](docs/APP-ABNAHME.md) verwenden.
  Nach jedem ausgelieferten Build Kernablauf und betroffene Nachbarfunktionen prüfen;
  bei Navigation-/Layout-Umbau alle betroffenen Zustandswechsel durchführen.
- Ein kurzer Prüfbericht kann unter `docs/validation/` abgelegt werden: Datum,
  Commit falls vorhanden, Buildnummer, Bundlepfad, macOS/Architektur, Fixture,
  Prüfschritte mit Soll/Ist und Status „bestanden / fehlgeschlagen / ungeprüft“.
- Testfall und Screenshot müssen zur ausgelieferten Version gehören. Frühere
  Testzahlen oder Bilder nicht als Nachweis für einen neuen Build verwenden.
- Nach erfolgreichem Build das Paket möglichst über einen temporären Ausgabeordner
  fertigstellen und erst nach Prüfungen veröffentlichen. Eine fehlgeschlagene Neuerstellung
  darf den letzten nutzbaren Build nicht als vermeintlich aktuellen stehen lassen.
- CI soll reproduzierbare Builds und fachliche Regressionen unterstützen. Tatsächliche
  Dock-Darstellung und native Interaktionen benötigen zusätzlich geeignete UI-Prüfungen.
