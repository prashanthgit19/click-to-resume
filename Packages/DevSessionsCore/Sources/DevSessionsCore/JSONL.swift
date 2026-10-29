import Foundation

func readJSONLHead(of url: URL, maxBytes: Int = 262_144) throws -> String {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    let data = try handle.read(upToCount: maxBytes) ?? Data()
    return String(decoding: data, as: UTF8.self)
}

func parseJSONLines(_ text: String) -> [[String: Any]] {
    text
        .split(separator: "\n", omittingEmptySubsequences: true)
        .compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
                return nil
            }
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
}

func messageText(from content: Any?) -> String? {
    if let text = content as? String {
        return text
    }

    if let blocks = content as? [[String: Any]] {
        let texts = blocks.compactMap { block -> String? in
            guard block["type"] as? String == "text" else {
                return nil
            }
            return block["text"] as? String
        }
        let joined = texts.joined(separator: " ")
        return joined.isEmpty ? nil : joined
    }

    if let blocks = content as? [Any] {
        let texts = blocks.compactMap { block -> String? in
            guard let block = block as? [String: Any],
                  block["type"] as? String == "text" else {
                return nil
            }
            return block["text"] as? String
        }
        let joined = texts.joined(separator: " ")
        return joined.isEmpty ? nil : joined
    }

    return nil
}

func normalizedTitle(_ raw: String?) -> String? {
    guard let raw else { return nil }
    let collapsed = raw
        .split(whereSeparator: { $0.isWhitespace })
        .joined(separator: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !collapsed.isEmpty else { return nil }
    return String(collapsed.prefix(100))
}

func isSubstantivePrompt(_ raw: String) -> Bool {
    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return false }

    let wrappers = [
        "<environment_context>",
        "<user_instructions>",
        "<system-reminder>",
        "<ide_opened_file>",
        "<local-command-caveat>",
        "<local-command-stdout>",
        "<command-name>",
        "<command-message>",
        "<bash-input>",
        "<user-prompt-submit-hook>"
    ]
    if wrappers.contains(where: { text.hasPrefix($0) }) {
        return false
    }
    return true
}

func firstSubstantivePrompt(from content: Any?) -> String? {
    guard let text = messageText(from: content) else { return nil }
    guard isSubstantivePrompt(text) else { return nil }
    return normalizedTitle(text)
}

func projectName(for path: String) -> String {
    let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
    if standardized == "/" {
        return "/"
    }
    let name = URL(fileURLWithPath: standardized).lastPathComponent
    return name.isEmpty ? standardized : name
}

func modificationDate(of url: URL) -> Date? {
    if let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
       let date = values.contentModificationDate {
        return date
    }
    let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
    return attributes?[.modificationDate] as? Date
}

/// Returns `.jsonl` files directly inside the immediate subdirectories of `root`.
/// Pi, Oh My Pi, and Claude Code use one directory level as a project bucket.
func recentJSONLFiles(in root: URL, cutoff: Date) -> [(url: URL, modified: Date)] {
    let fileManager = FileManager.default
    guard let buckets = try? fileManager.contentsOfDirectory(
        at: root,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    var files: [(URL, Date)] = []

    for bucket in buckets {
        let isDirectory = (try? bucket.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        guard isDirectory else { continue }

        guard let bucketFiles = try? fileManager.contentsOfDirectory(
            at: bucket,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            continue
        }

        for file in bucketFiles where file.pathExtension.lowercased() == "jsonl" {
            let values = try? file.resourceValues(
                forKeys: [.isRegularFileKey, .contentModificationDateKey]
            )
            guard values?.isRegularFile == true else { continue }
            guard let modified = values?.contentModificationDate ?? modificationDate(of: file) else {
                continue
            }
            guard modified >= cutoff else { continue }
            files.append((file, modified))
        }
    }

    return files.sorted { $0.1 > $1.1 }
}
