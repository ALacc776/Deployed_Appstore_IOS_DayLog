//
//  JournalDocumentRenderer.swift
//  Jour
//
//  Created by andapple on 2/10/2026.
//

import UIKit

/// Renders journal entries into human-readable documents (PDF and Word-compatible RTF)
/// Used by both manual export and the automatic iCloud Drive backup
enum JournalDocumentRenderer {
    // MARK: - Page Layout

    /// US Letter page size in points
    private static let pageSize = CGSize(width: 612, height: 792)

    /// Margin around the printable area
    private static let margin: CGFloat = 54

    /// Largest size a photo is drawn at inside the PDF
    private static let maxPhotoSize = CGSize(width: 320, height: 320)

    // MARK: - Public Methods

    /// Generates a paginated PDF of the given entries, including photo thumbnails
    /// - Parameters:
    ///   - entries: Entries to include
    ///   - streak: Streak information for the header
    /// - Returns: PDF data
    static func pdfData(entries: [JournalEntry], streak: JournalStreak) -> Data {
        let content = attributedJournal(entries: entries, streak: streak, includePhotos: true)
        let pageRect = CGRect(origin: .zero, size: pageSize)
        let textRect = pageRect.insetBy(dx: margin, dy: margin)

        let textStorage = NSTextStorage(attributedString: content)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "DayLog Journal",
            kCGPDFContextCreator as String: "DayLog"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        return renderer.pdfData { context in
            var pageNumber = 0
            var laidOutGlyphs = 0

            // Add one text container per page until every glyph has been placed
            repeat {
                let container = NSTextContainer(size: textRect.size)
                container.lineFragmentPadding = 0
                layoutManager.addTextContainer(container)
                let glyphRange = layoutManager.glyphRange(for: container)

                context.beginPage()
                pageNumber += 1
                layoutManager.drawBackground(forGlyphRange: glyphRange, at: textRect.origin)
                layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: textRect.origin)
                drawPageNumber(pageNumber, in: pageRect)

                // Stop if nothing fit on this page to avoid an endless loop
                guard glyphRange.length > 0 else { break }
                laidOutGlyphs = NSMaxRange(glyphRange)
            } while laidOutGlyphs < layoutManager.numberOfGlyphs
        }
    }

    /// Generates an RTF document that opens in Word, Pages, and the Files app
    /// - Parameters:
    ///   - entries: Entries to include
    ///   - streak: Streak information for the header
    /// - Returns: RTF data
    static func rtfData(entries: [JournalEntry], streak: JournalStreak) throws -> Data {
        let content = attributedJournal(entries: entries, streak: streak, includePhotos: false)
        return try content.data(
            from: NSRange(location: 0, length: content.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    // MARK: - Private Methods

    /// Builds the styled journal text shared by every document format
    private static func attributedJournal(entries: [JournalEntry], streak: JournalStreak, includePhotos: Bool) -> NSAttributedString {
        let output = NSMutableAttributedString()

        let titleFont = UIFont(name: "HelveticaNeue-Bold", size: 26) ?? .boldSystemFont(ofSize: 26)
        let dayFont = UIFont(name: "HelveticaNeue-Bold", size: 16) ?? .boldSystemFont(ofSize: 16)
        let metaFont = UIFont(name: "HelveticaNeue", size: 10) ?? .systemFont(ofSize: 10)
        let bodyFont = UIFont(name: "HelveticaNeue", size: 12) ?? .systemFont(ofSize: 12)
        let categoryFont = UIFont(name: "HelveticaNeue-Medium", size: 12) ?? .systemFont(ofSize: 12, weight: .medium)

        let ink = UIColor.black
        let muted = UIColor.darkGray

        func paragraph(spacingBefore: CGFloat = 0, spacingAfter: CGFloat = 0) -> NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.paragraphSpacingBefore = spacingBefore
            style.paragraphSpacing = spacingAfter
            style.lineSpacing = 2
            return style
        }

        func append(_ text: String, font: UIFont, color: UIColor = ink, style: NSParagraphStyle = paragraph()) {
            output.append(NSAttributedString(string: text, attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: style
            ]))
        }

        // Header
        let headerDateFormatter = DateFormatter()
        headerDateFormatter.dateStyle = .long
        headerDateFormatter.timeStyle = .short

        append("DayLog Journal\n", font: titleFont, style: paragraph(spacingAfter: 4))
        let entryCount = "\(entries.count) \(entries.count == 1 ? "entry" : "entries")"
        let bestStreak = "Best streak \(streak.longest) \(streak.longest == 1 ? "day" : "days")"
        append("Exported \(headerDateFormatter.string(from: Date()))  ·  \(entryCount)  ·  \(bestStreak)\n",
               font: metaFont, color: muted, style: paragraph(spacingAfter: 12))

        // Entries grouped by day, newest day first
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }

        let dayFormatter = DateFormatter()
        dayFormatter.dateStyle = .full
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        for day in grouped.keys.sorted(by: >) {
            append("\(dayFormatter.string(from: day))\n", font: dayFont, style: paragraph(spacingBefore: 16, spacingAfter: 6))

            let dayEntries = (grouped[day] ?? []).sorted { $0.date < $1.date }
            for entry in dayEntries {
                var meta = entry.time ?? timeFormatter.string(from: entry.date)
                if let placeName = entry.location?.placeName, !placeName.isEmpty {
                    meta += "  ·  \(placeName)"
                }
                append("\(meta)\n", font: metaFont, color: muted, style: paragraph(spacingBefore: 6))

                if let category = entry.category, !category.isEmpty {
                    append("\(category)\n", font: categoryFont)
                }

                let text = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    append("\(text)\n", font: bodyFont, style: paragraph(spacingAfter: 4))
                }

                if let photoFilename = entry.photoFilename {
                    if includePhotos, let image = PhotoManager.shared.loadPhoto(filename: photoFilename) {
                        let attachment = NSTextAttachment()
                        let thumbnail = image.resized(to: maxPhotoSize)
                        attachment.image = thumbnail
                        attachment.bounds = CGRect(origin: .zero, size: thumbnail.size)
                        output.append(NSAttributedString(attachment: attachment))
                        append("\n", font: bodyFont, style: paragraph(spacingAfter: 6))
                    } else {
                        append("📷 Photo\n", font: metaFont, color: muted)
                    }
                }
            }
        }

        if entries.isEmpty {
            append("No entries yet.\n", font: bodyFont, color: muted)
        }

        return output
    }

    /// Draws a centered page number in the bottom margin
    private static func drawPageNumber(_ number: Int, in pageRect: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.gray
        ]
        let label = "\(number)" as NSString
        let size = label.size(withAttributes: attributes)
        let origin = CGPoint(x: pageRect.midX - size.width / 2, y: pageRect.maxY - margin / 2 - size.height / 2)
        label.draw(at: origin, withAttributes: attributes)
    }
}
