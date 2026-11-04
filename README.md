# HPIViewer V2.1 — Swift 5 / Xcode 15.2

AppKit-/Storyboard-Projekt, macOS 10.13+. Keine SwiftUI-Abhängigkeit.

## Funktionen
- **File → Open… (⌘O)**: Einzelne HPI-Datei laden.
- **File → Save… (⌘S)**: transparentes PNG exportieren.
- **File → New (⌘N)**: Vorschau leeren.
- **Transparente Vorschau**: links zwischen Original-JPEG und zusammengesetztem PNG wechseln; rechts die PNG-Maske.
- **Drag & Drop**: einzelne `.hpi` auf das Fenster ziehen; mehrere Dateien oder Ordner starten Batch-Export.
- **File → HPI-Ordner konvertieren… (⇧⌘B)**: Quellordner wählen, dann Ausgabeordner; rekursiv alle `.hpi` in PNG umwandeln.
- Bestehende PNG-Dateien werden **nicht überschrieben**; stattdessen `_2`, `_3` usw. angehängt. Bei gleichnamigen Quelldateien wird ebenfalls ein eindeutiger Name erzeugt.

## Technischer Aufbau
HPI-Header: 32 Bytes, Signatur + Little-Endian-Felder für JPEG- und PNG-Positionen/Längen. JPEG und PNG werden dekodiert und mit `CIBlendWithMask` kombiniert (weiß = deckend). Batch-Verarbeitung läuft in einer Hintergrund-Queue; Statusaktualisierungen erfolgen im Main Thread.

## Test
1. Projekt in Xcode 15.2 öffnen und starten.
2. `demo/50thann4.hpi` öffnen und Vorschau mit Checkbox umschalten.
3. PNG exportieren, Transparenz in Vorschau prüfen.
4. Den Ordner `demo` über ⇧⌘B batch-konvertieren; Ausgabeordner separat auswählen.
5. Datei und Ordner aus Finder ins Hauptfenster ziehen.

## Hinweise
- Projekt wurde auf Linux statisch erstellt; Xcode-Build und AppKit-Laufzeitverhalten müssen auf macOS geprüft werden.
- Bei sehr großen Ordnern werden alle Dateipfade zunächst gesammelt. Batch-Fortschritt zeigt verarbeitete Dateien, kein Abbruch-Button.
- Die Konvertierung flacht die Verzeichnisstruktur in einen Ausgabeordner ab.
- Für App-Sandbox-Betrieb sind zusätzliche Security-Scoped-URL-/Bookmark-Maßnahmen zu prüfen; das bestehende Projekt ist nicht für Sandbox konfiguriert.


## Storyboard Edition – manuell im Interface Builder ergänzen

Es werden **keine Bedienelemente und keine Menüeinträge programmatisch erzeugt**.
Das bestehende Storyboard enthält weiterhin die zwei ImageViews; die übrigen Elemente bitte im IB ergänzen:

1. **Check Box** unter den Bildansichten platzieren. Titel: `Transparente Vorschau`, Initial State: **On**. Vom View Controller das Outlet `previewCheckbox` verbinden und unter Sent Actions `previewChanged:` (Value Changed) verbinden.
2. **Label** (nicht editierbares NSTextField) daneben platzieren. Starttext: `HPI-Datei oder Ordner hierher ziehen`. Outlet `statusLabel` verbinden.
3. Unter **File** einen Menüpunkt `HPI-Ordner konvertieren…` ergänzen; dessen Action mit dem View Controller `batchOpen:` verbinden. Tastenkürzel optional **Shift-Command-B**. Der Menüpunkt muss den View Controller als Target erreichen (z. B. über First Responder, falls die Responder Chain passt, oder explizite Verbindung).
4. Constraints für Checkbox und Label im IB anlegen; die vorhandenen ImageViews sind unten bereits mit 42 pt Abstand zum Fensterrand beschränkt.

**Vorhandene Outlets**: `imageView`, `maskView`. **Neue Outlets**: `previewCheckbox`, `statusLabel`. **Neue Actions**: `previewChanged:`, `batchOpen:`.

Ohne die beiden neuen Outlet-Verbindungen kann die Statusanzeige leer bleiben; die Funktionen für Laden und Batch-Konvertierung arbeiten unabhängig davon.


## V2.3 – Fortschritt und Abbrechen (Storyboard / manuelle IB-Verkabelung)

Die Benutzeroberfläche wird nicht programmatisch ergänzt. Füge im bestehenden
`Main.storyboard` zwei Steuerelemente selbst ein:

1. **Progress Indicator** aus der Object Library, im Attributes Inspector
   **Style = Bar** (nicht Spinner) und **Indeterminate = aus**. Verbinde
   ihn mit dem Outlet `batchProgress` des `ViewController`.
2. **Push Button** mit Titel **Abbrechen**. Verbinde ihn mit dem Outlet
   `cancelBatchButton` und die Action mit `cancelBatch:` im `ViewController`.

Die bereits vorhandenen Outlets `previewCheckbox`, `statusLabel`, `imageView`
und `maskView` bleiben unverändert. Das Menü `batchOpen:` bleibt ebenfalls.

**Layout-Vorschlag:** Unterhalb der beiden Bildansichten eine zusätzliche
Zeile für die Fortschrittsleiste vorsehen; rechts daneben den Abbrechen-Button.
Setze die Leading/Trailing-Constraints zur jeweiligen Bildansicht bzw. zum
Button und einen Abstand von 8–12 pt. Die Statuszeile darunter belassen.
Falls der Platz nicht reicht, Fenster-Mindesthöhe entsprechend erhöhen.

**Ablauf:** Die Leiste beginnt bei 0, ihr Maximum entspricht der Anzahl
der gefundenen HPI-Dateien. Nach jeder verarbeiteten Datei steigt der Wert
um eins. `Abbrechen` signalisiert einen kooperativen Abbruch: Eine laufende
Datei wird gegebenenfalls noch verarbeitet; danach werden keine weiteren
Dateien konvertiert. Bereits erzeugte PNG-Dateien bleiben erhalten.
Am Ende erscheint eine Zusammenfassung mit Anzahl erfolgreicher Dateien,
Fehlern und bearbeiteten Dateien. Die Leiste bleibt auf dem letzten Stand.

**Wichtig:** Die neuen Outlets sind optional eingebunden (`?.`), sodass das
Projekt auch vor dem manuellen Verkabeln starten kann; die Anzeige und der
Abbrechen-Button funktionieren erst nach der IB-Verbindung.

**Test:** Ordner mit mehreren HPI-Dateien auswählen, Zielordner angeben,
Fortschritt beobachten, Abbrechen während der Verarbeitung drücken und
anschließend einen zweiten Batch starten.

**Build-Status:** Statische Prüfung, kein tatsächlicher Xcode-Build in dieser Umgebung.


## Fortschrittsanzeige – Korrektur V2.3.1

Der NSProgressIndicator arbeitet nun immer mit minValue=0 und maxValue=100.
Die Anzeige wird nach jeder Datei prozentual berechnet. Vor dem Abschlussdialog
wird die Darstellung aktualisiert. Bei Abbruch bleibt der erreichte Prozentsatz
stehen. Keine neuen Outlets oder Storyboard-Änderungen erforderlich.


## V2.3.2
- Finder-Drop eines Ordners: direkte Konvertierung in den automatisch angelegten Unterordner `HPI_Export` ohne erneute Ordnerauswahl.
- Menü-Stapelverarbeitung: Quell- und Zielordner bleiben frei wählbar.
- Fortschritt 0–100 Prozent; bei regulärem Abschluss vor der Abschlussmeldung auf 100 Prozent.
- Abschlussmeldung als nicht blockierendes Window-Sheet.
- Storyboard und bestehende Outlets/Actions unverändert.

## V2.3.3 – Ausgabeordner bei Drag & Drop
Beim Ablegen eines Ordners wird der Quellordner direkt übernommen. Der Ausgabeordner wird stets über einen Ordnerauswahldialog abgefragt; bei Abbruch erfolgt keine Konvertierung. Der Menüweg fragt weiterhin Quell- und Ausgabeordner ab.
