# HPIViewer V2.4 — Bedienungsanleitung

macOS-App zum Anzeigen und Konvertieren von **Hemera Photo-Objects (`.hpi`)**. Erstellt mit **Swift 5, AppKit und Storyboard** für Xcode 15.2 (Deployment Target macOS 10.13).

## Was zeigt das Programm?

Eine HPI-Datei enthält ein JPEG-Farbbild und eine PNG-Maske. Im Hauptfenster befindet sich links das Farbbild bzw. die transparente Vorschau und rechts die Schwarz-Weiß-Maske. **Weiß** in der Maske bedeutet deckend, **Schwarz** transparent. Die Checkbox **Transparent Preview** schaltet die linke Ansicht zwischen dem ursprünglichen JPEG und dem zusammengesetzten Bild mit Transparenz um. Unter der rechten Ansicht stehen Dateiname und HPI-Version bzw. Meldungen zum Batch-Vorgang.

## 1. Einzelne HPI-Datei öffnen

1. **File → Open…** (`⌘O`) wählen und eine `.hpi`-Datei auswählen; alternativ eine einzelne HPI-Datei aus dem Finder auf das Fenster ziehen.
2. Das linke Bild und die rechte Maske prüfen.
3. Mit **Transparent Preview** zwischen Original und transparenter Darstellung wechseln.
4. **File → Save…** (`⌘S`) wählen, Namen und Speicherort bestimmen und das zusammengesetzte Bild als **PNG mit Transparenz** speichern.
5. **File → New** (`⌘N`) leert die Vorschau.

Hinweis: `Save…` speichert die zusammengesetzte PNG-Datei, nicht die ursprüngliche HPI-Datei. Ohne geladenes Bild ist kein sinnvoller Export möglich.

## 2. Einen ganzen Ordner konvertieren (Menü)

1. **File → HPI-Ordner konvertieren…** (`⇧⌘B`) aufrufen.
2. Im ersten Dialog den **Quellordner** mit HPI-Dateien auswählen.
3. Im zweiten Dialog den **Ausgabeordner** auswählen. Dort lässt sich über die macOS-Ordnerauswahl auch ein **neuer Ordner erstellen**.
4. Nach Bestätigung beginnt die Konvertierung. Die Dateien werden auch in Unterordnern des Quellordners gesucht.
5. Den **Fortschrittsbalken (0–100 %)** und den Statustext beobachten.
6. Nach Abschluss zeigt ein Dialog die Anzahl bearbeiteter Dateien, erstellter PNGs und Fehler. Bei normalem Abschluss steht der Balken auf **100 %**.

## 3. Einen Ordner per Drag & Drop konvertieren

1. Den Quellordner aus dem Finder direkt auf das Programmfenster ziehen.
2. **Der Quellordner wird nicht erneut abgefragt.** Es erscheint nur der Dialog zur Auswahl des **Ausgabeordners**.
3. Ausgabeordner auswählen oder neu erstellen und **Konvertieren** bestätigen.
4. Die Stapelverarbeitung läuft wie oben beschrieben.

Werden mehrere HPI-Dateien gemeinsam auf das Fenster gezogen, startet ebenfalls die Stapelverarbeitung mit Auswahl des Ausgabeordners. Wird die Ausgabeordnerauswahl abgebrochen, startet keine Konvertierung.

## 4. Fortschritt und Abbrechen

- Der Fortschrittsbalken zeigt den **prozentualen Anteil bearbeiteter Dateien**, nicht die Anzahl direkt als Wert. Beispiel: Bei 13 Dateien entspricht eine bearbeitete Datei etwa 7,7 %.
- **Cancel Batch / Abbrechen** fordert den Abbruch an. Eine gerade bearbeitete Datei kann noch fertiggestellt werden; danach stoppt die Verarbeitung.
- Bereits erzeugte PNG-Dateien bleiben erhalten. Bei Abbruch bleibt die Fortschrittsanzeige auf dem erreichten Stand, nicht auf 100 %.
- Der Abschlussdialog fasst Erfolge und Fehler zusammen. Nach dessen Schließen kann ein weiterer Batch gestartet werden.

## 5. Speicherverhalten und Hinweise

- Die exportierten Bilder werden als `.png` in den gewählten Ausgabeordner geschrieben.
- Existiert ein Dateiname bereits, wird er nicht überschrieben: Die App ergänzt beispielsweise `_2`, `_3` usw.
- Bei der Stapelverarbeitung werden alle Ergebnisse **direkt im Ausgabeordner** abgelegt; die ursprüngliche Unterordnerstruktur wird nicht übernommen.
- Defekte oder nicht lesbare HPI-Dateien werden als Fehler gezählt; die Verarbeitung der übrigen Dateien wird fortgesetzt.
- Für eine große Zahl von Dateien kann die Verarbeitung einige Zeit dauern. Währenddessen lässt sich über **Abbrechen** ein kontrollierter Stopp anfordern.

## 6. Bedienelemente und Tastenkürzel

| Bedienung | Wirkung |
| --- | --- |
| `⌘O` / File → Open… | Einzelne HPI-Datei öffnen |
| `⌘S` / File → Save… | Aktuelles Bild als transparentes PNG speichern |
| `⌘N` / File → New | Bildansichten zurücksetzen |
| `⇧⌘B` / File → HPI-Ordner konvertieren… | Quell- und Ausgabeordner wählen, Batch starten |
| Einzelne `.hpi` auf Fenster ziehen | Datei direkt öffnen |
| Ordner auf Fenster ziehen | Quellordner übernehmen, Ausgabeordner abfragen, Batch starten |
| Transparent Preview | Linke Bildansicht umschalten |
| Cancel Batch / Abbrechen | Laufende Stapelverarbeitung kontrolliert stoppen |

## 7. Beispiel und Test

Im Projektordner `demo` liegt die Beispieldatei `50thann4.hpi`. Öffne sie zunächst einzeln, schalte die transparente Vorschau um und exportiere eine PNG-Datei. Teste anschließend den Batch-Vorgang mit einem Ordner, der mehrere `.hpi`-Dateien enthält, und prüfe, ob die Fortschrittsanzeige bei normalem Abschluss 100 % erreicht.

## 8. Technische Hinweise für die Weiterentwicklung

- Die Benutzeroberfläche wird im **Interface Builder** gepflegt; die Bildansichten, Checkbox, Statusanzeige, Fortschrittsleiste und Abbrechen-Schaltfläche sind per Outlets/Actions verbunden.
- Die Batch-Konvertierung läuft im Hintergrund, Status- und Fortschrittsanzeigen werden auf dem Main Thread aktualisiert.
- Der Ausgabeordner wird mit einem **asynchronen `NSOpenPanel` als Sheet** abgefragt; das Anlegen neuer Ordner ist erlaubt.
- Die HPI-Daten bestehen aus einem 32-Byte-Header sowie JPEG- und PNG-Maskendaten. Für die Zusammensetzung wird Core Image verwendet.
- Die mitgelieferte Version wurde hier nicht mit Xcode auf macOS gebaut. Bei weiteren Änderungen bitte in Xcode 15.2 kompilieren und die IB-Verbindungen prüfen.
