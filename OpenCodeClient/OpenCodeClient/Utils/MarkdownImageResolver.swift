import Foundation

enum MarkdownImageResolver {
    private static let maxResolvedImageCharacters = 80_000_000
    private static let maxResolvedMarkdownCharacters = 80_000_000
    
    /// Image extensions that should be fetched as binary content
    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "tif", "heic", "heif", "ico", "svg"
    ]
    
    private static let imageRegex = try! NSRegularExpression(
        pattern: #"!\[([^\]]*)\]\(([^)]+)\)"#,
        options: []
    )
    
    /// Resolve image references in markdown text by fetching them via the API.
    /// - Parameters:
    ///   - text: The markdown text
    ///   - markdownFilePath: The path of the markdown file being rendered (for resolving relative paths). Can be nil for chat messages.
    ///   - workspaceDirectory: The workspace root directory
    ///   - fetchContent: Async closure that fetches FileContent for a given path
    /// - Returns: The markdown text with image URLs resolved to data URIs
    static func resolveImages(
        in text: String,
        markdownFilePath: String? = nil,
        workspaceDirectory: String?,
        fetchContent: (String) async throws -> FileContent
    ) async -> String {
        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let matches = imageRegex.matches(in: text, range: fullRange)
        
        guard !matches.isEmpty else { return text }
        let protected = imageSyntaxProtectedRanges(in: text)
        
        var result = text
        // Process matches in reverse order to maintain correct string indices
        for match in matches.reversed() {
            if Task.isCancelled { return text }

            guard let matchRange = Range(match.range, in: text),
                  !protected.contains(where: { $0.overlaps(matchRange) }),
                  !isEscapedImageStart(matchRange.lowerBound, in: text),
                  let altRange = Range(match.range(at: 1), in: text),
                  let urlRange = Range(match.range(at: 2), in: text) else { continue }
            
            let alt = String(text[altRange])
            let rawUrl = String(text[urlRange]).trimmingCharacters(in: .whitespaces)
            
            // Skip if already a data URI or has a scheme
            if rawUrl.hasPrefix("data:") || rawUrl.contains("://") { continue }
            
            // Determine the extension
            let ext = (rawUrl as NSString).pathExtension.lowercased()
            guard !ext.isEmpty, imageExtensions.contains(ext) else { continue }
            
            // Resolve relative path (same rule reused for link routing; see below).
            let resolvedPath = resolveRelativeReference(
                rawUrl,
                markdownFilePath: markdownFilePath,
                workspaceDirectory: workspaceDirectory
            )

            do {
                let content = try await fetchContent(resolvedPath)
                guard let base64Data = content.content, !base64Data.isEmpty else { continue }
                
                // Clean base64 (remove whitespace)
                let cleaned = base64Data
                    .replacingOccurrences(of: "\n", with: "")
                    .replacingOccurrences(of: "\r", with: "")
                    .replacingOccurrences(of: " ", with: "")

                guard cleaned.count <= maxResolvedImageCharacters else { continue }

                let mimeType = mimeType(for: ext)
                let dataUri = "data:\(mimeType);base64,\(cleaned)"
                
                let replacement = "![\(alt)](\(dataUri))"
                guard let matchRange = Range(match.range, in: result) else { continue }
                let nextCount = result.count - result[matchRange].count + replacement.count
                guard nextCount <= maxResolvedMarkdownCharacters else { continue }
                result.replaceSubrange(matchRange, with: replacement)
            } catch is CancellationError {
                return text
            } catch {
                continue
            }
        }
        
        return result
    }

    /// Resolve a relative reference (image src or link href) against the markdown
    /// file's own directory, then make it workspace-relative. Mirrors the path
    /// semantics of Native Preview so Web Preview links/images resolve identically.
    /// - A path starting with `/` is treated as absolute (only workspace-normalized).
    /// - Otherwise it is resolved against the markdown file's directory, including
    ///   `../` parent traversal, then workspace-normalized and `./`-stripped.
    static func resolveRelativeReference(
        _ rawReference: String,
        markdownFilePath: String?,
        workspaceDirectory: String?
    ) -> String {
        var resolvedPath = rawReference
        if let mdPath = markdownFilePath, !rawReference.hasPrefix("/") {
            let mdDir = (mdPath as NSString).deletingLastPathComponent
            resolvedPath = (mdDir as NSString).appendingPathComponent(rawReference)
        }

        // PathNormalizer.normalize (called inside) collapses `.` / `..` segments
        // purely by string, so `../images/x.png` resolves without touching disk.
        resolvedPath = PathNormalizer.resolveWorkspaceRelativePath(resolvedPath, workspaceDirectory: workspaceDirectory)

        if resolvedPath.hasPrefix("./") { resolvedPath = String(resolvedPath.dropFirst(2)) }
        return resolvedPath
    }

    private struct OpenFence {
        let marker: Character
        let length: Int
        let quoteDepth: Int
    }

    private static func imageSyntaxProtectedRanges(in text: String) -> [Range<String.Index>] {
        let fences = fencedCodeRanges(in: text)
        let indented = indentedCodeRanges(in: text)
        return fences + indented + inlineCodeRanges(in: text, avoiding: fences + indented)
    }

    private static func fencedCodeRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var open: OpenFence?
        var openStart: String.Index?
        var index = text.startIndex
        while index < text.endIndex {
            let lineEnd = text[index...].firstIndex(of: "\n") ?? text.endIndex
            let parsed = quoteAndContent(text[index..<lineEnd])
            if let fence = open {
                if parsed.depth < fence.quoteDepth {
                    if let start = openStart {
                        ranges.append(start..<index)
                    }
                    open = nil
                    openStart = nil
                    continue
                }
                let closerContent = quoteAndContent(text[index..<lineEnd], maxDepth: fence.quoteDepth).content
                if isClosingFence(closerContent, open: fence) {
                    let end = lineEnd < text.endIndex ? text.index(after: lineEnd) : text.endIndex
                    if let start = openStart {
                        ranges.append(start..<end)
                    }
                    open = nil
                    openStart = nil
                    index = end
                    continue
                }
                index = lineEnd < text.endIndex ? text.index(after: lineEnd) : text.endIndex
                continue
            }
            if let marker = openingFence(parsed.content) {
                open = OpenFence(marker: marker.char, length: marker.length, quoteDepth: parsed.depth)
                openStart = index
            }
            index = lineEnd < text.endIndex ? text.index(after: lineEnd) : text.endIndex
        }
        if let start = openStart {
            ranges.append(start..<text.endIndex)
        }
        return ranges
    }

    private static func quoteAndContent(_ line: Substring, maxDepth: Int = Int.max) -> (depth: Int, content: Substring) {
        var index = line.startIndex
        var depth = 0
        while index < line.endIndex, depth < maxDepth {
            var spaces = 0
            var cursor = index
            while cursor < line.endIndex, line[cursor] == " ", spaces < 3 {
                spaces += 1
                cursor = line.index(after: cursor)
            }
            guard cursor < line.endIndex, line[cursor] == ">" else { break }
            depth += 1
            cursor = line.index(after: cursor)
            if cursor < line.endIndex, line[cursor] == " " {
                cursor = line.index(after: cursor)
            }
            index = cursor
        }
        var content = line[index...]
        if content.last == "\r" {
            content = content.dropLast()
        }
        return (depth, content)
    }

    private static func leadingSpaces(_ content: Substring, max: Int) -> (count: Int, rest: Substring) {
        var count = 0
        var index = content.startIndex
        while index < content.endIndex, content[index] == " ", count < max {
            count += 1
            index = content.index(after: index)
        }
        return (count, content[index...])
    }

    private static func openingFence(_ content: Substring) -> (char: Character, length: Int)? {
        let (_, rest) = leadingSpaces(content, max: 3)
        guard let char = rest.first, char == "`" || char == "~" else { return nil }
        var length = 0
        var index = rest.startIndex
        while index < rest.endIndex, rest[index] == char {
            length += 1
            index = rest.index(after: index)
        }
        guard length >= 3 else { return nil }
        if char == "`", rest[index...].contains("`") { return nil }
        return (char, length)
    }

    private static func isClosingFence(_ content: Substring, open: OpenFence) -> Bool {
        let (_, rest) = leadingSpaces(content, max: 3)
        guard let char = rest.first, char == open.marker else { return false }
        var length = 0
        var index = rest.startIndex
        while index < rest.endIndex, rest[index] == char {
            length += 1
            index = rest.index(after: index)
        }
        guard length >= open.length else { return false }
        return rest[index...].allSatisfy { $0 == " " || $0 == "\t" }
    }

    private static func indentedCodeRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var index = text.startIndex
        var atBlockBoundary = true
        var codeStart: String.Index?
        while index < text.endIndex {
            let lineEnd = text[index...].firstIndex(of: "\n") ?? text.endIndex
            let parsed = quoteAndContent(text[index..<lineEnd])
            let next = lineEnd < text.endIndex ? text.index(after: lineEnd) : text.endIndex
            if parsed.depth > 0 {
                if let start = codeStart {
                    ranges.append(start..<index)
                    codeStart = nil
                }
                atBlockBoundary = false
                index = next
                continue
            }
            let content = parsed.content
            let blank = content.allSatisfy { $0 == " " || $0 == "\t" }
            let indented = leadingSpaces(content, max: 4).count == 4
            if codeStart != nil {
                if blank || indented {
                    index = next
                    continue
                }
                ranges.append(codeStart!..<index)
                codeStart = nil
            }
            if atBlockBoundary, !blank, indented {
                codeStart = index
                atBlockBoundary = false
                index = next
                continue
            }
            atBlockBoundary = blank
            index = next
        }
        if let start = codeStart {
            ranges.append(start..<text.endIndex)
        }
        return ranges
    }

    private static func inlineCodeRanges(in text: String, avoiding fences: [Range<String.Index>]) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var index = text.startIndex
        while index < text.endIndex {
            if let fence = fences.first(where: { $0.contains(index) }) {
                index = fence.upperBound
                continue
            }
            if text[index] != "`" || hasOddPrecedingBackslash(index, in: text) {
                index = text.index(after: index)
                continue
            }
            let openerEnd = backtickRunEnd(in: text, from: index)
            let length = text.distance(from: index, to: openerEnd)
            if let closer = closingBacktickRun(in: text, from: openerEnd, length: length, avoiding: fences) {
                let end = text.index(closer, offsetBy: length)
                ranges.append(index..<end)
                index = end
            } else {
                index = openerEnd
            }
        }
        return ranges
    }

    private static func backtickRunEnd(in text: String, from start: String.Index) -> String.Index {
        var index = start
        while index < text.endIndex, text[index] == "`" {
            index = text.index(after: index)
        }
        return index
    }

    private static func closingBacktickRun(
        in text: String,
        from start: String.Index,
        length: Int,
        avoiding fences: [Range<String.Index>]
    ) -> String.Index? {
        var index = start
        while index < text.endIndex {
            if fences.contains(where: { $0.contains(index) }) {
                return nil
            }
            if text[index] == "`" {
                let end = backtickRunEnd(in: text, from: index)
                if text.distance(from: index, to: end) == length {
                    return index
                }
                index = end
                continue
            }
            index = text.index(after: index)
        }
        return nil
    }

    private static func isEscapedImageStart(_ index: String.Index, in text: String) -> Bool {
        hasOddPrecedingBackslash(index, in: text)
    }

    private static func hasOddPrecedingBackslash(_ index: String.Index, in text: String) -> Bool {
        var backslashes = 0
        var cursor = index
        while cursor > text.startIndex {
            let previous = text.index(before: cursor)
            guard text[previous] == "\\" else { break }
            backslashes += 1
            cursor = previous
        }
        return backslashes % 2 == 1
    }

    private static func mimeType(for fileExtension: String) -> String {
        switch fileExtension {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "svg":
            return "image/svg+xml"
        default:
            return "image/\(fileExtension)"
        }
    }
}
