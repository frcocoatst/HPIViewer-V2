import Cocoa
import CoreImage
import UniformTypeIdentifiers

private enum HPIError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

private struct HPIDocument {
    let jpeg: Data
    let mask: Data
    let version: UInt32

    init(data: Data) throws {
        let bytes = [UInt8](data)
        let signature: [UInt8] = [0x89, 0x48, 0x50, 0x49, 0x0D, 0x0A, 0x1A, 0x0A]
        guard bytes.count >= 32, Array(bytes.prefix(8)) == signature else {
            throw HPIError.invalid("Keine gültige HPI-Datei (Signatur oder Header fehlt).")
        }
        func word(_ offset: Int) -> UInt32 {
            UInt32(bytes[offset]) | (UInt32(bytes[offset + 1]) << 8) |
            (UInt32(bytes[offset + 2]) << 16) | (UInt32(bytes[offset + 3]) << 24)
        }
        version = word(8)
        func region(_ start: UInt32, _ length: UInt32, name: String) throws -> Data {
            let a = Int(start), n = Int(length)
            guard a >= 32, n > 0, a <= bytes.count, n <= bytes.count - a else {
                throw HPIError.invalid("Ungültiger Datenbereich: \(name).")
            }
            return data.subdata(in: a..<(a+n))
        }
        let jpegStart = word(12), jpegLength = word(16)
        let maskStart = word(20), maskLength = word(24)
        guard UInt64(jpegStart) + UInt64(jpegLength) <= UInt64(maskStart) else {
            throw HPIError.invalid("JPEG- und Maskenbereich überlappen.")
        }
        jpeg = try region(jpegStart, jpegLength, name: "JPEG")
        mask = try region(maskStart, maskLength, name: "PNG-Maske")
        guard jpeg.starts(with: [0xFF, 0xD8]),
              mask.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) else {
            throw HPIError.invalid("JPEG- oder PNG-Signatur ist ungültig.")
        }
    }
}

// Root view accepts Finder file/folder drops without replacing the Storyboard UI.
final class HPIDropView: NSView {
    var onDrop: (([URL]) -> Void)?
    override func awakeFromNib() {
        super.awakeFromNib()
        registerForDraggedTypes([.fileURL])
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return urls.isEmpty ? [] : .copy
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        guard !urls.isEmpty else { return false }
        onDrop?(urls)
        return true
    }
}

class ViewController: NSViewController {
    @IBOutlet weak var maskView: NSImageView!
    @IBOutlet weak var imageView: NSImageView!

    private var currentURL: URL?
    private var currentImage: NSImage?
    private var currentMask: NSImage?
    private var compositeImage: NSImage?
    private var showTransparentPreview = true
    @IBOutlet weak var previewCheckbox: NSButton!
    @IBOutlet weak var statusLabel: NSTextField!
    // Diese beiden Elemente im Interface Builder selbst anlegen und verbinden.
    @IBOutlet weak var batchProgress: NSProgressIndicator!
    @IBOutlet weak var cancelBatchButton: NSButton!

    private var activeBatch = false
    private let batchLock = NSLock()
    private var cancellationRequested = false

    private func isCancellationRequested() -> Bool {
        batchLock.lock()
        defer { batchLock.unlock() }
        return cancellationRequested
    }

    private func setCancellationRequested(_ value: Bool) {
        batchLock.lock()
        cancellationRequested = value
        batchLock.unlock()
    }

    @IBAction func cancelBatch(_ sender: Any?) {
        guard activeBatch else { return }
        setCancellationRequested(true)
        cancelBatchButton?.isEnabled = false
        statusLabel?.stringValue = "Abbruch angefordert – aktuelle Datei wird fertiggestellt…"
    }

    private func configureBatchControls() {
        batchProgress?.isIndeterminate = false
        batchProgress?.minValue = 0
        batchProgress?.doubleValue = 0
        batchProgress?.maxValue = 100
        cancelBatchButton?.isEnabled = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        maskView.imageScaling = .scaleProportionallyUpOrDown
        (view as? HPIDropView)?.onDrop = { [weak self] urls in self?.handleDroppedURLs(urls) }
        // Checkbox, Status-Label und Batch-Menü werden ausschließlich im Interface Builder angelegt.
        previewCheckbox?.state = .on
        configureBatchControls()
    }

    @IBAction func newDocument(_ sender: Any?) {
        guard !activeBatch else { return }
        currentURL = nil
        currentImage = nil
        currentMask = nil
        imageView.image = nil
        maskView.image = nil
        compositeImage = nil
        statusLabel?.stringValue = "HPI-Datei oder Ordner hierher ziehen"
        view.window?.title = "HPIViewer V2.3.2"
    }

    @IBAction func openDocument(_ sender: Any?) {
        guard !activeBatch else { return }
        let panel = NSOpenPanel()
        panel.title = "HPI-Datei öffnen"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if #available(macOS 11.0, *) {
            // UTType is optional for custom file extensions; filename filtering is
            // additionally checked below for backward compatibility.
            panel.allowedContentTypes = [.init(filenameExtension: "hpi") ?? .data]
        } else {
            panel.allowedFileTypes = ["hpi"]
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadSingle(url)
    }

    private func loadSingle(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let document = try HPIDocument(data: data)
            guard let image = NSImage(data: document.jpeg),
                  let mask = NSImage(data: document.mask), image.isValid, mask.isValid else {
                throw HPIError.invalid("JPEG oder PNG-Maske konnte nicht dekodiert werden.")
            }
            let png = try Self.maskedPNG(image: image, mask: mask)
            guard let composed = NSImage(data: png) else {
                throw HPIError.invalid("Transparente Vorschau konnte nicht geladen werden.")
            }
            currentURL = url
            currentImage = image
            currentMask = mask
            compositeImage = composed
            updatePreview()
            maskView.image = mask
            statusLabel?.stringValue = "\(url.lastPathComponent) · HPI-Version \(document.version)"
            view.window?.title = "\(url.lastPathComponent) – HPIViewer V2.3.2"
        } catch { presentError(error) }
    }

    private func updatePreview() {
        imageView.image = showTransparentPreview ? compositeImage : currentImage
    }

    @IBAction func previewChanged(_ sender: NSButton) {
        showTransparentPreview = sender.state == .on
        updatePreview()
    }

    private func handleDroppedURLs(_ urls: [URL]) {
        guard !activeBatch else { showMessage("Eine Stapelverarbeitung läuft bereits."); return }
        if urls.count == 1, urls[0].pathExtension.lowercased() == "hpi" {
            loadSingle(urls[0])
        } else {
            let files = Self.collectHPI(urls)
            if files.isEmpty { showMessage("Keine HPI-Dateien gefunden."); return }
            // Quellordner kommt direkt aus Drag & Drop; Ausgabeordner immer abfragen.
            chooseDestinationAndConvert(files)
        }
    }

    private static func collectHPI(_ urls: [URL]) -> [URL] {
        var result: [URL] = []
        let fm = FileManager.default
        for url in urls {
            var directory: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &directory) else { continue }
            if directory.boolValue {
                if let entries = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                    for case let file as URL in entries where file.pathExtension.lowercased() == "hpi" { result.append(file) }
                }
            } else if url.pathExtension.lowercased() == "hpi" { result.append(url) }
        }
        return Array(Set(result)).sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    @IBAction func batchOpen(_ sender: Any?) {
        guard !activeBatch else { return }
        let panel = NSOpenPanel()
        panel.title = "HPI-Quellordner auswählen"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        guard panel.runModal() == .OK, let source = panel.url else { return }
        let files = Self.collectHPI([source])
        guard !files.isEmpty else { showMessage("Keine HPI-Dateien im gewählten Ordner."); return }
        chooseDestinationAndConvert(files)
    }
/*
    private func chooseDestinationAndConvert(_ files: [URL]) {
        guard !activeBatch, !files.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.title = "Ausgabeordner für PNG-Dateien auswählen"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        startBatch(files, destination: destination)
    }
    */
    private func chooseDestinationAndConvert(_ files: [URL]) {
        guard !activeBatch, !files.isEmpty else { return }

        let panel = NSOpenPanel()
        panel.title = "Ausgabeordner für PNG-Dateien auswählen"
        panel.message = "Wähle einen Ausgabeordner oder erstelle einen neuen."
        panel.prompt = "Konvertieren"

        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard let window = view.window else { return }

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK,
                  let destination = panel.url else { return }

            DispatchQueue.main.async {
                self?.startBatch(files, destination: destination)
            }
        }
    }

    private func startBatch(_ files: [URL], destination: URL) {
        guard !activeBatch, !files.isEmpty else { return }
        setCancellationRequested(false)
        activeBatch = true
        batchProgress?.minValue = 0
        batchProgress?.maxValue = 100
        batchProgress?.doubleValue = 0
        batchProgress?.needsDisplay = true
        cancelBatchButton?.isEnabled = true
        statusLabel?.stringValue = "Konvertiere 0 / \(files.count)…"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var success = 0
            var failures: [String] = []
            var processed = 0
            let fm = FileManager.default

            for file in files {
                if self.isCancellationRequested() { break }
                do {
                    let doc = try HPIDocument(data: Data(contentsOf: file))
                    guard let image = NSImage(data: doc.jpeg), let mask = NSImage(data: doc.mask),
                          image.isValid, mask.isValid else {
                        throw HPIError.invalid("Bild oder Maske nicht lesbar")
                    }
                    let png = try Self.maskedPNG(image: image, mask: mask)
                    // Abbruch zwischen Dekodierung und Schreiben ebenfalls berücksichtigen.
                    if self.isCancellationRequested() { break }
                    let base = file.deletingPathExtension().lastPathComponent
                    var target = destination.appendingPathComponent(base).appendingPathExtension("png")
                    var counter = 2
                    while fm.fileExists(atPath: target.path) {
                        target = destination.appendingPathComponent("\(base)_\(counter)").appendingPathExtension("png")
                        counter += 1
                    }
                    try png.write(to: target, options: .atomic)
                    success += 1
                } catch {
                    failures.append("\(file.lastPathComponent): \(error.localizedDescription)")
                }
                processed += 1
                let completed = processed
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.activeBatch else { return }
                    self.batchProgress?.doubleValue = 100.0 * Double(completed) / Double(files.count)
                    self.batchProgress?.displayIfNeeded()
                    if !self.isCancellationRequested() {
                        self.statusLabel?.stringValue = "Konvertiere \(completed) / \(files.count)…"
                    }
                }
            }
            let cancelled = self.isCancellationRequested()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.activeBatch = false
                self.cancelBatchButton?.isEnabled = false
                self.batchProgress?.minValue = 0
                self.batchProgress?.maxValue = 100
                self.batchProgress?.doubleValue = cancelled ? 100.0 * Double(processed) / Double(files.count) : 100.0
                self.batchProgress?.needsDisplay = true
                self.statusLabel?.stringValue = cancelled
                    ? "Abgebrochen: \(processed) / \(files.count), \(success) PNG, \(failures.count) Fehler"
                    : "Abgeschlossen: \(success) PNG, \(failures.count) Fehler"
                let summary = cancelled ? "Stapelverarbeitung abgebrochen." : "Stapelverarbeitung abgeschlossen."
                let message = summary + "\n\(processed) von \(files.count) Dateien bearbeitet, \(success) PNG-Dateien erstellt, \(failures.count) Fehler." +
                    (failures.isEmpty ? "" : "\n\n" + failures.prefix(8).joined(separator: "\n"))
                // Abschlussmeldung als Sheet statt blockierendem runModal:
                // Der Fortschrittsbalken bleibt dabei sichtbar auf 100 %.
                self.view.layoutSubtreeIfNeeded()
                self.batchProgress?.displayIfNeeded()
                self.statusLabel?.displayIfNeeded()
                let alert = NSAlert()
                alert.messageText = "HPIViewer V2.3.2.2"
                alert.informativeText = message
                if let window = self.view.window {
                    alert.beginSheetModal(for: window, completionHandler: nil)
                } else {
                    alert.runModal()
                }
            }
        }
    }

    private func showMessage(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "HPIViewer V2.3.2"
        alert.informativeText = message
        alert.runModal()
    }

    @IBAction func saveDocument(_ sender: Any?) { exportPNG() }
    @IBAction func saveDocumentAs(_ sender: Any?) { exportPNG() }

    private func exportPNG() {
        guard let image = currentImage, let mask = currentMask else {
            let alert = NSAlert()
            alert.messageText = "Keine HPI-Datei geöffnet"
            alert.informativeText = "Bitte zuerst eine HPI-Datei öffnen."
            alert.runModal()
            return
        }
        let panel = NSSavePanel()
        panel.title = "PNG mit Transparenz exportieren"
        panel.nameFieldStringValue = (currentURL?.deletingPathExtension().lastPathComponent ?? "HPI-Export") + ".png"
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [.png]
        } else {
            panel.allowedFileTypes = ["png"]
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try Self.maskedPNG(image: image, mask: mask).write(to: url, options: .atomic) }
        catch { presentError(error) }
    }

    private static func cgImage(_ image: NSImage) throws -> CGImage {
        var rect = CGRect(origin: .zero, size: image.size)
        guard let result = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            throw HPIError.invalid("Bild kann nicht als CGImage gelesen werden.")
        }
        return result
    }

    private static func maskedPNG(image: NSImage, mask: NSImage) throws -> Data {
        let source = CIImage(cgImage: try cgImage(image))
        var alpha = CIImage(cgImage: try cgImage(mask))
        let extent = source.extent
        guard alpha.extent.width > 0, alpha.extent.height > 0 else {
            throw HPIError.invalid("Die Maske besitzt keine gültige Größe.")
        }
        // White mask pixels are opaque; black pixels are transparent.
        alpha = alpha.transformed(by: CGAffineTransform(
            scaleX: extent.width / alpha.extent.width,
            y: extent.height / alpha.extent.height))
        alpha = alpha.transformed(by: CGAffineTransform(
            translationX: extent.minX - alpha.extent.minX,
            y: extent.minY - alpha.extent.minY)).cropped(to: extent)
        guard let blend = CIFilter(name: "CIBlendWithMask") else {
            throw HPIError.invalid("Core Image Maskenfilter ist nicht verfügbar.")
        }
        blend.setValue(source, forKey: kCIInputImageKey)
        blend.setValue(CIImage(color: CIColor.clear).cropped(to: extent),
                       forKey: kCIInputBackgroundImageKey)
        blend.setValue(alpha, forKey: kCIInputMaskImageKey)
        guard let result = blend.outputImage,
              let cg = CIContext().createCGImage(result, from: extent),
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
            throw HPIError.invalid("PNG mit Transparenz konnte nicht erstellt werden.")
        }
        return png
    }
}
