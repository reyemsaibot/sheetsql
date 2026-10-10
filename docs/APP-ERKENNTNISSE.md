# Fehler und Erkenntnisse aus unseren Apps

Stand: 10.10.2026. Rückblick auf die verfügbaren Verläufe von Nori, Minuto,
SheetSQL und DataScope sowie README, Build-Skripte, Icon-Skripte und Quellstellen.
Dies ist die Sammlung der dort nachvollziehbaren Fehler und Erkenntnisse,
kein Nachweis, dass jedes historische Problem oder jede Behebung vollständig erfasst ist.
Keine App wurde für diese Dokumentationsaufgabe neu getestet oder verändert.

## Die größte Prozesskorrektur

Wir haben zu oft „Build erfolgreich“ oder „Tests erfolgreich“ mit einer funktionierenden
Oberfläche gleichgesetzt. Wiederholte Nutzerberichte über unsichtbare Buttons,
unklickbare Tabs und fehlende Dock-Icons zeigen, dass diese Abnahme nicht ausreichte.
Ein Modelltest prüft einen Zustandswechsel, aber nicht, ob der Nutzer den auslösenden
Button sehen und anklicken kann. Künftig braucht jeder betroffene Ablauf beides.

## Icons, Namen und App-Pakete

| App / Beobachtung | Erkenntnis / künftig erforderliche Prüfung |
| --- | --- |
| Minuto: Dock-Icon mehrfach weiterhin generisch, obwohl ein neues Icon gemeldet wurde. | Ressourcen im fertigen Paket, Plist, gestarteten Pfad und tatsächliches Dock prüfen. Alte angeheftete App-Kopie von aktuellem Build unterscheiden. |
| Nori: Nach dem Beenden erschien ein anderes Logo im Dock. | Laufzeit-Icon und Bundle-Icon waren nicht konsistent. Das Bundle muss das richtige Motiv auch ohne laufenden Prozess liefern. |
| Nori: Sidebar-Logo passte nicht zum App-Icon; später störte der quadratische Hintergrund innerhalb der App. | Gemeinsames Motiv verwenden; transparentes UI-Logo getrennt vom gestalteten Dock-Icon ableiten. |
| Nori und SheetSQL: Dock-Icon wirkte im Vergleich zu den anderen Apps zu groß. | Nicht nur 1024-px-Dateigröße prüfen: Motivfläche, Transparenzrand und optisches Gewicht im selben Dock vergleichen. |
| SheetSQL: Schwarzes undurchsichtiges Außenquadrat und unpassende Größe. | Echtes Alpha im Außenbereich, Ecken und Kantenglättung prüfen; Varianten und Bundle aus korrigiertem Master neu erzeugen. |
| SheetSQL: Laufzeit-PNG und ICNS wurden an unterschiedlichen Stellen korrigiert. | Alle Icon-Verwendungen inventarisieren. Ein korrekter PNG-Override kann eine falsche ICNS bei laufender App verdecken. |
| SheetSQL: Dockname blieb SheetQL nach Umbenennung. | App-Dateiname, Binärname, Plist und UI-Texte zusammen aktualisieren. Technische interne Namen dürfen bei Bedarf bestehen bleiben. |
| Minuto: Kundenzeit war nur ein Arbeitstitel, blieb aber in Assets und Datenpfaden. | Sichtbare Namen bereinigen; Datenpfad mit Migration ändern, nicht nur umbenennen. |
| DataScope: Nach mehreren Icon-Korrekturen meldete der Nutzer weiterhin ein fehlendes Dock-Icon. | Behebung war durch Bundle-/Signaturprüfungen allein nicht belegt. Zum Erhebungszeitpunkt im anderen Chat noch in Bearbeitung; nicht als abgeschlossen führen. |
| 10.10.2026, DataScope: Das Dock zeigte weiter das generische Platzhaltericon. | Der eigene ICNS-Writer lieferte keinen praktisch bestätigten Dock-Container; zusätzlich verwies `CFBundleIconName` zeitweise auf keinen Asset-Katalog. DataScope wurde auf die Nori-Pipeline mit `AppIcon.appiconset`, kompiliertem `Assets.car` und `tiff2icns` umgestellt. Der neue Bundle-Build (5) wurde gestartet. Direkter Dock-Zugriff über die vorhandene UI-Automation lief in einen Timeout; die tatsächliche Dock-Sichtprüfung bleibt offen. |
| 10.10.2026, DataScope: Der Platzhalter blieb nach dem Bundle-Wechsel sichtbar. | Vergleich mit Nori zeigte den fehlenden Laufzeit-Override: DataScope setzte `NSApplication.shared.applicationIconImage` beim Prozessstart nicht. Build 6 lädt nun `AppIcon.icns` aus `Bundle.main` und setzt genau dieses Bild für die laufende Dock-Kachel. Bundle, Tests und Neustart geprüft; die vorhandene UI-Automation kann die Dock-Leiste weiterhin nicht lesen. |
| DataScope und SheetSQL: `iconutil` meldete wiederholt `Invalid Iconset`. | Exakte Dateinamen und reale Pixelmaße kontrollieren. Nicht bloß Existenz einer alten ICNS als Erfolg werten. |
| DataScope: Ein direkter `sips`-Export nach ICNS scheiterte. | Einen echten validierten Iconset-Konverter verwenden; Dateiendung ist kein Containerformat. |
| DataScope: Eigener ICNS-Writer mit verschiedenen Repräsentationen wurde eingesetzt. | Writer ist ein Fallback, kein Beweis für Finder-/Dock-Kompatibilität. Insbesondere kleine und Retina-Darstellungen praktisch prüfen. |
| Nori: TIFF-Zusammenbau warnte vor unterschiedlichen logischen Bildgrößen. | Warnung untersuchen; Pixel und Punkte sind verschieden. Korrekte Iconset-Pipeline bevorzugen und Ergebnis kontrollieren. |
| DataScope: Signaturprüfung meldete fehlende Ressourcen trotz erwarteter Signatur. | Bundle erst vollständig aufbauen, danach signieren und prüfen; nach jeder Ressourcenänderung neu signieren. |
| DataScope: Startversuch scheiterte mit `kLSNoExecutableErr`. | `CFBundleExecutable` gegen tatsächliche ausführbare Datei prüfen. Der Verlauf belegt den Fehler, nicht abschließend seine Ursache. |
| Historische Dock-Korrekturen nutzten neue Bundle-IDs, Buildnummern und Cache-Resets. | Keine Dauerlösung: ID beeinflusst App-Identität und Daten/Integration; Buildnummer garantiert keinen Cache-Reset. Erst Ursache und richtigen Bundlepfad feststellen. |

## Oberfläche und Interaktion

| App / Fehler oder wiederholte Korrektur | Erkenntnis / Regression prüfen |
| --- | --- |
| SheetSQL: Maximierter Ergebnis-Tab ließ sich weder schließen noch zur Konsole zurückwechseln. | Unsichtbarer Editor, Overlays und Scrollcontainer können Klicks abfangen. Bedingtes Rendering, getrennte Buttons und echte Mausklicks prüfen. Mehrere historische Korrekturen reichten zunächst nicht. |
| SheetSQL: Speichern, Laden, Verlauf und Ausführen verschwanden nach Layoutänderungen. | Aktionen waren teilweise im Accessibility-Baum, aber optisch unsichtbar. Aktionsleiste bei jedem Zustandswechsel sichtbar prüfen. |
| SheetSQL: Zusätzliche „Tab schließen“-/„Zur Konsole“-Buttons duplizierten vorhandene Tab-Aktionen. | Bestehende ×- und Konsolenflächen funktionsfähig machen; keine Ersatzbedienung ohne Not hinzufügen. |
| SheetSQL: Zeilennummern stimmten nach mehrzeiligem Einfügen nicht. | Native Textlayout-Geometrie statt geschätzter Zeilenhöhe verwenden; Paste, Scrollen und Zeilenumbrüche testen. |
| SheetSQL: Tabellen-/Spalten-Icons, Chevron und Texte waren uneinheitlich ausgerichtet. | Gemeinsame Sidebar-Zeilen und feste Icon-/Textausrichtung verwenden, Hoverzustände einbeziehen. |
| SheetSQL: Nach dem Schließen der letzten Datei fehlte der erwartete Startbildschirm. | Workspace-/Tab-/Auswahlzustand gemeinsam modellieren. Spätere Wünsche und Dokumentation unterscheiden sich teils; aktuellen Produktvertrag prüfen. |
| Nori: Neuer Task-Dialog und Edit-Dialog liefen auseinander; alter Quick-Task-Code blieb ungenutzt. | Gemeinsamen Editor verwenden. Nach Zusammenführung doppelte Views, Zustände und Aufrufe entfernen. |
| Nori: Mit optionalen Feldern wurde der obere Dialogbereich samt Titel abgeschnitten. | Scrollcontainer und Fenstergeometrie strukturell korrigieren; viele Optionen plus kleine Fenster testen. |
| Nori: Dialog wurde als flexibel beschrieben, war aber nicht tatsächlich resizeable. | SwiftUI-Frames ersetzen keine native Fensterkonfiguration. Resize am realen Fenster ausführen. |
| Nori: Reminder-Glocke wurde unanklickbar oder zeigte den gesetzten Zeitpunkt nicht mehr. | Visuelle Vereinfachung darf Auswahl und Statusanzeige nicht entfernen. Glocke, Popover, Datum/Uhrzeit und Speichern gemeinsam testen. |
| Nori: Datum war nach optischer Anpassung nicht mehr anklickbar. | Klickfläche unabhängig vom Text gestalten; gesamte Datumsfläche mit Maus prüfen. |
| Nori: Titelschrift änderte sich trotz SwiftUI-Modifier nicht wie gemeldet. | Bei AppKit-Textfeldern die native Schrift setzen und sichtbares Ergebnis kontrollieren. Spätere Vorgabe war maximal 30 pt; nicht frühere 44 pt verallgemeinern. |
| Nori: Notes, Comments, Related Information und Zeiterfassung wurden mehrfach an falschen Stellen angeordnet. | Gewünschte Reihenfolge als Layoutvertrag festhalten; neue optionale Abschnitte dürfen sie nicht verschieben. |
| Nori: Optionale Due-Date-/Reminder-Felder hatten redundante Checkboxen. | Add-Menü steuert Sichtbarkeit; nicht einen zweiten Aktivierungsschritt einbauen. Entfernen und Datenwirkung klar definieren. |
| Nori: Settings und neue Objekte fehlten zunächst in der macOS-Menüleiste. | Menübefehle und Shortcuts gehören zum ersten nutzbaren Build. |
| Nori: `⌘N` funktionierte nicht im Kanban; weitere Kürzel waren ansichtsabhängig. | Appweite Commands statt lokalem View-Fokus; verschiedene Ansichten testen. |
| Nori: Permanente Suche blieb trotz Wunsch nach Lupen-Popover sichtbar. | Tatsächliche UI nach Änderung ansehen; Suche per Maus und Kürzel öffnen, Enter/Esc prüfen. |
| Nori: Kanban-Spalten wurden abgeschnitten, Abstände und Inhaltsbreiten waren uneinheitlich. | Keine feste Höhe für wachsenden Inhalt; gemeinsame Ränder, Mindestbreiten und definierte Scrollzuständigkeit. |
| Nori: Gantt-Datumslabels überlappten oder Monatsende war abgeschnitten. | Randabstand, Labelpositionen und verfügbare Breite testen, einschließlich Monats-/Jahreswechsel. |
| Nori: Gantt verhielt sich bei kleinen Fenstern schlecht und begann am unerwünschten Projektstart. | Geometrie und fachlichen Startpunkt getrennt definieren; Task-Klicks sowie Sortierung nach Fälligkeit prüfen. |
| Nori: Karten waren mit Notes, Checklisten und Subtask-Informationen überladen. | Übersicht enthält nur benötigte Zusammenfassung; Details bleiben im Editor. Neueste Nutzerwünsche entscheiden über sichtbare Felder. |
| Mehrere Apps: Symbolaktionen hatten zunächst keine eindeutigen Labels/Tooltips; Sprachen waren gemischt. | Barrierefreiheit und sprachliche Konsistenz mit jeder neuen Aktion mitführen. |

## Daten, Filter und Integration

| App / Problem oder wichtige Erkenntnis | Künftige Umsetzung / Prüfung |
| --- | --- |
| Minuto: Von 06.10. bis 06.10. zeigte mehr als diesen Tag. | Halboffenes Tagesintervall mit lokalem Kalender; Mitternacht, gleicher Tag, umgekehrte Grenzen und Sommerzeit prüfen. |
| Minuto: Kalender zeigte die vorhandenen Zeiten nicht wie erwartet. | Gewählten Monat, Aggregation, Wochentagsausrichtung und Navigation gegen synthetische Einträge prüfen. Datenverlust nicht ohne Beleg annehmen. |
| Minuto: Abrechnungsticket und Jira-Ticket wurden nicht konsequent getrennt; CSV enthielt das Abrechnungsticket zunächst nicht. | Getrennte fachliche Felder, Stammdatenzuordnung, Statuswechsel und Export zusammen prüfen. |
| Minuto: Abschließen/Abrechnen funktionierte zeitweise nicht wie erwartet. | Fehlende Zuordnung sichtbar behandeln; neueste Regel erlaubt gegebenenfalls Abschluss ohne Zuordnung. Keine ältere Einschränkung ungeprüft wieder einführen. |
| Minuto: Wechsel von Kundenzeit zu Minuto und später von WebKit/React zu SwiftUI. | Daten vor/neben Technologiewechsel erhalten; Altordner kopieren, bestehende Zieldaten schützen, Migration testen. Aktuelle README statt alter React-Aufräumtipps verwenden. |
| Nori: Datierte Inbox-Tasks ohne Projekt fehlten in Woche/Upcoming/Planned. | Globale Filter über alle geeigneten Tasks ausführen; Inbox nicht versehentlich ausschließen. |
| Nori: Änderung von Projekt/Parent/Blocked by/Milestone betrifft voneinander abhängige Auswahlfelder. | Gültige Optionen neu bestimmen; Hierarchien und Zuordnung ohne Datenverlust prüfen. Nur passende offene Tasks zur Auswahl anbieten. |
| Nori: Farbauswahl war nicht überall konsistent; Kalender sollte Projektfarben verwenden. | Persistierte Projektfarbe durch alle Ansichten führen; alte gespeicherte Farben kompatibel lesen. |
| Nori: Dateianhangstest schrieb vor Anlage des temporären Verzeichnisses. | Testfixture vollständig anlegen, bevor Dateien geschrieben werden; Cleanup separat behandeln. |
| Nori: `contentTypeKey` löste beim Anhangsimport `kLSDataUnavailableErr` aus. | Optionale Metadaten robust behandeln; Dateityp mit geeignetem Fallback bestimmen. Gültigen Dateiimport nicht von Launch-Services-Metadaten abhängig machen. |
| Nori: Backups/Anhänge/Sync wurden erweitert, aber vollständige UI-/Zweitgeräteprüfung blieb offen. | Wiederherstellung samt Dateien, Aufbewahrung und Konflikte unabhängig testen; reine Modelltests nicht als vollständigen Sync-Nachweis melden. |
| Nori: iCloud-Key-Value-Store wurde als Backup bezeichnet, aber keine Finder-Datei existiert. | Speichermechanismus und lokale Backup-Dateien korrekt erklären; Sync und Backup unterscheiden. |
| Nori: URL-Capture-Unterstützung wurde mit Outlook-/Mail-Automatisierung verbunden. | Empfangslogik beweist keine funktionierende Mailintegration. Übergabe, URL-Kodierung, Links und Anhänge Ende zu Ende in tatsächlicher Quell-App prüfen. |
| SheetSQL: Smart Quotes machten SQL-Anführungszeichen ungültig. | Automatische Textkorrekturen im Codeeditor abschalten; Identifier und Literale unterscheiden, Sonderzeichen testen. |
| SheetSQL: Neue Datei sollte bestehendes SQL erhalten. | Import, Auswahl und Query-Ausführung trennen; Cursor-Einfügung und Schließen dürfen SQL nicht unbeabsichtigt ersetzen. |
| SheetSQL: „Komplette Tabelle im Tab“ steht einem dokumentierten 10.000-Zeilen-Limit gegenüber. | Vollständigkeit nur bei entsprechender Implementierung behaupten. Vorschau, geladenes Ergebnis und Quelldaten explizit unterscheiden. |
| SheetSQL: Sortierung/Filter/CSV und Ergebnis-Tabs wurden schrittweise ergänzt. | Jeder Tab braucht eigenen Zustand; Export benutzt die ausgewählte Sicht. Neuabfrage darf alte Tabs nicht ungewollt verändern. |
| DataScope: Rohwerte, NULL, leerer Text, Whitespace und führende Nullen haben unterschiedliche Bedeutung. | Keine automatische Typumwandlung ohne fachliche Regel. Deutsche Zahlen und Excel-Zelltypen mit eigenen Fixtures prüfen. |
| DataScope: Vorschau ist auf 100 Zeilen begrenzt, Kennzahlen betreffen den vollen Import. | Diese beiden Datenmengen konsequent trennen; Abbruch und rechenintensive Analyse dürfen UI nicht blockieren. |
| DataScope: Eine Million synthetische Zeilen wurden schnell verarbeitet. | Einzelmessung mit Hardware/Datenform nennen; keine allgemeine Leistungsgarantie für echte Arbeitsmappen ableiten. |

## Build, Wartbarkeit und Kommunikation

| Beobachtung | Konsequenz |
| --- | --- |
| Swift-6-Fehler: Capture von `self` in parallelem Code; Zugriff auf nicht-Sendable-Monitor aus `deinit`. | Isolation und Objektlebensdauer gezielt gestalten; früh mit dem tatsächlichen Swift-6-Compiler bauen. |
| Nori: `self` vor vollständiger Initialisierung; neues `attachments`-Argument fehlte in einem Aufruf; fehlendes `try`. | Modell-/API-Änderungen durch alle Aufrufstellen führen, throwing APIs explizit behandeln, kleine Schritte kompilieren. |
| Minuto: Mehrere Variablen unter einem `@State` führten zu Compilerfehlern. | Property-Wrapper pro Deklaration verwenden; nicht zur Platzersparnis komprimieren. |
| Gesperrte Swift-/Clang-Caches meldeten unter anderem „unable to load standard library“. | Erst tatsächlichen Cache-Schreibfehler prüfen, appspezifischen writable Cache setzen; nicht SDK-Neuinstallation vermuten. |
| zsh: eigene Variable `status` war read-only; macOS `find` unterstützte `-printf` nicht. | Shell-/BSD-Kompatibilität beachten und taskbezogene Variablennamen verwenden. |
| DataScope: Downloads scheiterten an DNS/Netzwerk. | Setup und Offline-Build trennen, Downloads fixieren und Prüfsummen prüfen; Umgebungsfehler nicht als App-Defekt behandeln. |
| Minuto: sehr breite Suche in Application Support verursachte viele Zugriffsfehler. | Bekannte appbezogene Pfade gezielt prüfen; keine unnötige Vollsuche in geschützten Datenordnern. |
| Nori: Nutzer sagte „App sehr groß“; sowohl Fenstergeometrie als auch Paket-/Cachegröße waren relevant. | Konkreten Befund nennen: Fenstermaße, Bundlegröße und Entwicklungsartefakte getrennt. |
| Mehrere Apps: Code wuchs zu großen Einzeldateien, alte Views/Assets blieben liegen. | Nach einer Funktionsetappe aufteilen und unbenutzten Code entfernen, ohne Daten-/Migrationspfade versehentlich zu löschen. |
| Mehrere Apps teilen den Workspace; zusätzliche Git-Repositories liegen darunter. | Git-Root und Änderungen prüfen; keine pauschalen Commits/Pushes von Nachbarprojekten oder Nutzerdaten. |
| Alte README-/TODO-Texte können nach einem Technologiewechsel überholt sein. | Aktuellen Quellcode und Build als Grundlage nehmen; Dokumentation mit jeder relevanten Änderung abgleichen. |
| „Signatur valide“ wurde teilweise wie „fertig für alle Macs“ formuliert. | Ad-hoc-Signatur, Developer ID, Notarisierung, Intel/Apple Silicon und Zweitgerätetest getrennt ausweisen. |
| Wiederholte Erfolgsmeldungen wurden durch Nutzerberichte widerlegt. | Status mit tatsächlicher Prüfung begründen; keine Hypothese als bestätigte Ursache oder Behebung darstellen. |

## Noch offene Qualitätsarbeit am Erhebungszeitpunkt

- **Alle Apps:** öffentliche Releases, Developer-ID/Notarisierung und zweiter Mac sind
  nicht durch diese Erhebung abgenommen. Accessibility und End-to-End-Tests gezielt ausbauen.
- **Nori:** echtes Xcode-UI-Test-Target und praktische iCloud-Konfliktprüfung über zwei Macs.
  Der Verlauf meldet zuletzt 24 bestandene Tests; diese Zahl ist historisch, hier nicht neu gemessen.
- **Minuto:** laut aktueller TODO Aufteilung von `Minuto.swift`, Tests für Stammdaten,
  Export/Restore/Migration, Schema-Version und CI. Aktueller Build ist nativ; alte React-TODOs
  nicht mehr als aktuellen Arbeitsauftrag behandeln.
- **SheetSQL:** README, letzte-Datei-Verhalten und „komplette Tabelle“-Anforderung abgleichen;
  Sitzungs-/Tab-Persistenz und Limits bewusst entscheiden. Sicht-/Klickregressionen absichern.
- **DataScope:** Dock-Icon im laufenden parallelen App-Chat noch beanstandet; weitere Etappen
  laut `docs/PLAN.md`, Crash-Aufräumen und Intel-/Zweitgerätetest noch offen.

## Quellen und Pflege

Ausgewertete App-Chats, mit den Titeln zum Zeitpunkt der Erhebung:

- „Projekt-App nach Things erstellen“ — `01a115af-8d1b-7141-8703-55e51c36a004`
- „Minuto“ — `01a0d2be-9f5c-77f3-af9a-b4c890f25395`
- „Excel-SQL-Analyse-App erstellen“ — `01a11806-6541-7671-b4fc-3589d24f0c23`
- „Data Profiling für Mac planen“ — `01a11b90-cc34-7751-aa68-741938119f89`

Quellabgleich: README und `scripts/build-app.sh` von Nori, SheetSQL und DataScope;
Nori-Icon-Skripte; DataScope `scripts/make-icon.swift`; Minuto `build.sh`, `Info.plist`,
`TODO.md` und relevante Stellen in `Minuto.swift`. Die App-Chats sind veränderlich;
spätere Änderungen können die hier dokumentierten offenen Punkte bereits erledigt haben.

Technische Referenzen für die Arbeitsregeln:

- [Apple: klassisches Iconset-Format](https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/IconSetType.html)
- [Apple: Bundle-/Icon-/Namensschlüssel](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html)
- [Apple: aktuelle App-Icon-Gestaltung](https://developer.apple.com/design/human-interface-guidelines/app-icons)

Neue Erkenntnis jeweils ergänzen als: Datum → App → Symptom → belegte Ursache/offene
Hypothese → Korrektur → Regressionprüfung → Status. Nur wiederverwendbare Regeln in
`AGENTS.md` aufnehmen; projektspezifische Designentscheidungen in der jeweiligen App halten.
