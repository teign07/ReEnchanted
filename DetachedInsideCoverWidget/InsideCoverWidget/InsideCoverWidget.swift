import WidgetKit
import SwiftUI
import UIKit

struct InsideCoverEntry: TimelineEntry {
    let date: Date
    let state: InsideCoverState
    let image: UIImage?
}

struct InsideCoverProvider: TimelineProvider {
    func placeholder(in context: Context) -> InsideCoverEntry {
        InsideCoverEntry(date: Date(), state: .fallback, image: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (InsideCoverEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<InsideCoverEntry>) -> Void) {
        let entry = entry()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func entry() -> InsideCoverEntry {
        InsideCoverEntry(date: Date(), state: InsideCoverStore.load(), image: InsideCoverStore.loadImage())
    }
}

struct InsideCoverWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: InsideCoverEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            background
            LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.82)], startPoint: .top, endPoint: .bottom)
            content
                .padding(family == .systemSmall ? 12 : 16)
        }
        .overlay(alignment: .topTrailing) {
            Image(systemName: MoonPhaseCalendar.phase(on: entry.date).symbolName)
                .font(.system(size: family == .systemSmall ? 11 : 13, weight: .semibold))
                .foregroundStyle(.yellow.opacity(0.85))
                .shadow(color: .black.opacity(0.6), radius: 2)
                .padding(family == .systemSmall ? 8 : 10)
                .accessibilityLabel(MoonPhaseCalendar.phase(on: entry.date).name)
        }
        .containerBackground(.clear, for: .widget)
        .widgetURL(URL(string: entry.state.openURL))
    }

    @ViewBuilder
    private var background: some View {
        if let image = entry.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            EnchantedPageBackground()
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 5 : 8) {
            Text(entry.state.title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)

            Text(family == .systemSmall ? entry.state.block : entry.state.day)
                .font(family == .systemSmall ? .headline : .title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            if family != .systemSmall {
                Text(entry.state.note)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(3)
            }

            Spacer(minLength: 2)

            if !entry.state.practice.isEmpty {
                Label(entry.state.practice, systemImage: "wand.and.stars")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.94))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } else if !entry.state.next.isEmpty {
                Label(entry.state.next, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if family == .systemLarge {
                Divider().overlay(.white.opacity(0.35))
                Text(entry.state.practicePrompt.isEmpty ? entry.state.now : entry.state.practicePrompt)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(4)
            }
        }
    }
}

struct InsideCoverWidget: Widget {
    let kind = "InsideCoverWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: InsideCoverProvider()) { entry in
            InsideCoverWidgetView(entry: entry)
        }
        .configurationDisplayName("ReEnchanted")
        .description("A living page from ReEnchanted: schedule, practice, note, and generated scene art.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
