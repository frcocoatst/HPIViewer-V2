# HPIViewer V2.1 — Swift 5 / Xcode 15.2

AppKit-/Storyboard-Projekt, macOS 10.13+. Keine SwiftUI-Abhängigkeit.


![Owon Image](https://raw.githubusercontent.com/frcocoatst/HPIViewer-V2/main/overview.png)


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

