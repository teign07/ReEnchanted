#!/usr/bin/env swift
// Renders PDF pages to PNG for visual proofing, using the system PDFKit.
//
//   xcrun swift scripts/render_pdf_pages.swift sheet PDF OUT.png [FIRST] [COUNT] [COLUMNS]
//       A contact sheet: COUNT pages from FIRST (1-based), laid out in a grid.
//   xcrun swift scripts/render_pdf_pages.swift page PDF OUT.png PAGE [WIDTH]
//       One page at WIDTH pixels (default 1100).
//
// Proofing aid only. Nothing here is part of the app or the print pipeline.

import AppKit
import PDFKit

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func image(of page: PDFPage, width: CGFloat) -> NSImage {
    let box = page.bounds(for: .trimBox).isEmpty ? page.bounds(for: .mediaBox) : page.bounds(for: .trimBox)
    let size = NSSize(width: width, height: width * box.height / box.width)
    return page.thumbnail(of: size, for: .trimBox)
}

func writePNG(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:]) else { fail("could not encode \(path)") }
    do { try data.write(to: URL(fileURLWithPath: path)) } catch { fail("\(error)") }
}

let args = CommandLine.arguments
guard args.count >= 4, let document = PDFDocument(url: URL(fileURLWithPath: args[2])) else {
    fail("usage: render_pdf_pages.swift sheet|page PDF OUT.png ...")
}

switch args[1] {
case "page":
    let number = args.count > 4 ? Int(args[4]) ?? 1 : 1
    let width = args.count > 5 ? CGFloat(Double(args[5]) ?? 1100) : 1100
    guard let page = document.page(at: number - 1) else { fail("no page \(number) of \(document.pageCount)") }
    writePNG(image(of: page, width: width), to: args[3])
case "sheet":
    let first = args.count > 4 ? max(1, Int(args[4]) ?? 1) : 1
    let count = args.count > 5 ? Int(args[5]) ?? 12 : 12
    let columns = args.count > 6 ? Int(args[6]) ?? 4 : 4
    let pages = (first..<min(document.pageCount + 1, first + count)).compactMap { document.page(at: $0 - 1) }
    guard !pages.isEmpty else { fail("no pages from \(first); document has \(document.pageCount)") }
    let cell: CGFloat = 360, gap: CGFloat = 14, label: CGFloat = 22
    let rendered = pages.map { image(of: $0, width: cell) }
    let cellHeight = rendered.map(\.size.height).max() ?? cell
    let rows = Int(ceil(Double(rendered.count) / Double(columns)))
    let canvas = NSSize(width: CGFloat(columns) * (cell + gap) + gap,
                        height: CGFloat(rows) * (cellHeight + gap + label) + gap)
    let sheet = NSImage(size: canvas)
    sheet.lockFocus()
    NSColor(white: 0.55, alpha: 1).setFill()
    NSRect(origin: .zero, size: canvas).fill()
    for (index, pageImage) in rendered.enumerated() {
        let column = CGFloat(index % columns), row = CGFloat(index / columns)
        let x = gap + column * (cell + gap)
        let y = canvas.height - (row + 1) * (cellHeight + gap + label)
        pageImage.draw(in: NSRect(x: x, y: y, width: pageImage.size.width, height: pageImage.size.height))
        ("p\(first + index)" as NSString).draw(at: NSPoint(x: x, y: y + cellHeight + 3),
            withAttributes: [.font: NSFont.boldSystemFont(ofSize: 13), .foregroundColor: NSColor.white])
    }
    sheet.unlockFocus()
    writePNG(sheet, to: args[3])
    print("\(document.pageCount) pages; sheet of \(pages.count)")
default:
    fail("unknown mode \(args[1])")
}
