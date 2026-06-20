import Foundation
import UIKit

// MARK: - PDF Data Models

struct PDFSection {
    var title: String?
    var rows: [PDFRow]
    init(title: String? = nil, rows: [PDFRow]) {
        self.title = title
        self.rows = rows
    }
}

struct PDFRow {
    let label: String
    let value: String
    var isHighlight: Bool = false
    var valueColor: UIColor?
    init(_ label: String, _ value: String, highlight: Bool = false, color: UIColor? = nil) {
        self.label = label
        self.value = value
        self.isHighlight = highlight
        self.valueColor = color
    }
}

extension String {
    var csvEscaped: String {
        guard contains(",") || contains("\"") || contains("\n") else { return self }
        return "\"" + replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

// MARK: - ReportExportService

final class ReportExportService {
    static let shared = ReportExportService()
    private init() {}

    // MARK: - PDF Generation

    func generatePDF(title: String, periodLabel: String, sections: [PDFSection]) -> URL? {
        let W: CGFloat = 595.2, H: CGFloat = 841.8, M: CGFloat = 44
        let CW = W - M * 2

        let fmt = UIGraphicsPDFRendererFormat()
        fmt.documentInfo = [
            kCGPDFContextTitle as String: title,
            kCGPDFContextAuthor as String: "FinTrack"
        ] as [String: Any]

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: W, height: H),
            format: fmt
        )

        let data = renderer.pdfData { ctx in
            var y: CGFloat = 0
            var pageNum = 0

            func newPage() {
                ctx.beginPage()
                pageNum += 1
                let c = ctx.cgContext
                c.setFillColor(UIColor.systemBlue.cgColor)
                c.fill(CGRect(x: 0, y: 0, width: W, height: 82))
                pdfText(c, "FINTRACK", x: M, y: 12, font: UIFont.systemFont(ofSize: 10, weight: .semibold), color: UIColor.white.withAlphaComponent(0.65))
                pdfText(c, title, x: M, y: 30, font: UIFont.boldSystemFont(ofSize: 20), color: .white)
                let sub = "\(periodLabel) · \(Date().formatted(date: .abbreviated, time: .omitted))"
                pdfText(c, sub, x: M, y: 58, font: UIFont.systemFont(ofSize: 10), color: UIColor.white.withAlphaComponent(0.7))
                y = 98
            }

            func footerPage() {
                let c = ctx.cgContext
                c.setFillColor(UIColor.systemGray5.cgColor)
                c.fill(CGRect(x: 0, y: H - 32, width: W, height: 32))
                pdfText(c, "FinTrack · Personal Finance", x: M, y: H - 22, font: UIFont.systemFont(ofSize: 9), color: .secondaryLabel)
                let pg = "Page \(pageNum)"
                let pgW = pg.size(withAttributes: [.font: UIFont.systemFont(ofSize: 9)]).width
                pdfText(c, pg, x: W - M - pgW, y: H - 22, font: UIFont.systemFont(ofSize: 9), color: .secondaryLabel)
            }

            func checkBreak(_ need: CGFloat) {
                if y + need > H - 50 { footerPage(); newPage() }
            }

            newPage()

            for section in sections {
                let c = ctx.cgContext
                if let t = section.title {
                    checkBreak(34)
                    c.setFillColor(UIColor.systemGray5.cgColor)
                    c.fill(CGRect(x: M, y: y, width: CW, height: 28))
                    pdfText(c, t.uppercased(), x: M + 8, y: y + 8, font: UIFont.systemFont(ofSize: 10, weight: .bold), color: .secondaryLabel)
                    y += 32
                }
                for (i, row) in section.rows.enumerated() {
                    checkBreak(28)
                    c.setFillColor((i % 2 == 0 ? UIColor.systemBackground : UIColor.systemGray6).cgColor)
                    c.fill(CGRect(x: M, y: y, width: CW, height: 26))
                    let lf = UIFont.systemFont(ofSize: 11, weight: row.isHighlight ? .semibold : .regular)
                    pdfText(c, row.label, x: M + 8, y: y + 7, font: lf, color: .label)
                    let vf = UIFont.systemFont(ofSize: 11, weight: .semibold)
                    let vc = row.valueColor ?? UIColor.label
                    let vw = row.value.size(withAttributes: [.font: vf]).width
                    pdfText(c, row.value, x: M + CW - vw - 8, y: y + 7, font: vf, color: vc)
                    y += 26
                }
                y += 12
            }
            footerPage()
        }

        let fname = title.lowercased().replacingOccurrences(of: " ", with: "_").appending(".pdf")
        return writeData(data, filename: fname)
    }

    private func pdfText(_ ctx: CGContext, _ text: String, x: CGFloat, y: CGFloat, font: UIFont, color: UIColor) {
        NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
            .draw(at: CGPoint(x: x, y: y))
    }

    // MARK: - CSV

    func writeCSV(_ content: String, filename: String) -> URL? {
        guard let data = content.data(using: .utf8) else { return nil }
        return writeData(data, filename: filename.hasSuffix(".csv") ? filename : filename + ".csv")
    }

    // MARK: - Share

    @MainActor
    func share(url: URL) {
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        var top = root
        while let p = top.presentedViewController { top = p }
        if let pop = vc.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        top.present(vc, animated: true)
    }

    // MARK: - Private

    private func writeData(_ data: Data, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do { try data.write(to: url, options: .atomic); return url } catch { return nil }
    }
}
