import AppKit
import UniformTypeIdentifiers

/// Service for exporting clipboard items
@MainActor
final class ExportService {
    static let shared = ExportService()

    private init() {}

    /// Export links to a text file
    func exportLinks(items: [ClipItem], format: ExportFormat) {
        let links = items.filter { $0.contentType == .link }

        guard !links.isEmpty else {
            showAlert(title: "No links to export", message: "There are no links in your clipboard history.")
            return
        }

        let content: String
        switch format {
        case .csv:
            content = generateCSV(from: links)
        case .text:
            content = generateText(from: links)
        case .json:
            content = generateJSON(from: links)
        }

        saveToFile(content: content, format: format)
    }

    /// Export all items to a file
    func exportAll(items: [ClipItem], format: ExportFormat) {
        guard !items.isEmpty else {
            showAlert(title: "No items to export", message: "There are no items in your clipboard history.")
            return
        }

        let content: String
        switch format {
        case .csv:
            content = generateCSV(from: items)
        case .text:
            content = generateText(from: items)
        case .json:
            content = generateJSON(from: items)
        }

        saveToFile(content: content, format: format)
    }

    // MARK: - Format Generators

    private func generateCSV(from items: [ClipItem]) -> String {
        var lines = ["Type,Content,Source App,Date"]

        for item in items {
            let type = item.contentType.displayName
            let content = (item.plainText ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            let source = item.sourceAppName ?? "Unknown"
            let date = ISO8601DateFormatter().string(from: item.createdAt)

            lines.append("\"\(type)\",\"\(content)\",\"\(source)\",\"\(date)\"")
        }

        return lines.joined(separator: "\n")
    }

    private func generateText(from items: [ClipItem]) -> String {
        items.compactMap { item -> String? in
            guard let text = item.plainText else { return nil }

            if item.contentType == .link {
                if let title = item.linkTitle, !title.isEmpty {
                    return "\(title)\n\(text)"
                }
                return text
            }

            return text
        }.joined(separator: "\n\n")
    }

    private func generateJSON(from items: [ClipItem]) -> String {
        let data = items.map { item -> [String: Any] in
            var dict: [String: Any] = [
                "type": item.contentType.rawValue,
                "createdAt": ISO8601DateFormatter().string(from: item.createdAt),
                "sourceApp": item.sourceAppName ?? "Unknown"
            ]

            if let text = item.plainText {
                dict["content"] = text
            }

            if let title = item.linkTitle {
                dict["title"] = title
            }

            return dict
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }

        return "[]"
    }

    // MARK: - File Operations

    private func saveToFile(content: String, format: ExportFormat) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Clipboard Items"
        savePanel.nameFieldStringValue = "clipboard-export.\(format.fileExtension)"
        savePanel.allowedContentTypes = [format.contentType]
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    self.showAlert(title: "Export Failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Export Format

enum ExportFormat: String, CaseIterable {
    case text = "Text"
    case csv = "CSV"
    case json = "JSON"

    var fileExtension: String {
        switch self {
        case .text: return "txt"
        case .csv: return "csv"
        case .json: return "json"
        }
    }

    var contentType: UTType {
        switch self {
        case .text: return .plainText
        case .csv: return .commaSeparatedText
        case .json: return .json
        }
    }
}
