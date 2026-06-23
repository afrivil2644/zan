import SwiftUI

/// Browsable list of recent dictations and transforms with their text.
struct HistorySectionView: View {
    @EnvironmentObject var history: HistoryStore
    @State private var showAll = false

    private let collapsedCount = 3
    private let expandedCap = 30

    private var visible: [HistoryEntry] {
        showAll ? Array(history.entries.prefix(expandedCap))
                : Array(history.entries.prefix(collapsedCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "Recent activity", systemImage: "clock.arrow.circlepath")
                Spacer()
                if !history.entries.isEmpty {
                    Button("Clear") { history.clear() }
                        .font(.caption2)
                        .buttonStyle(.link)
                }
            }

            if history.entries.isEmpty {
                Text("Your dictations and transforms will show up here.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(visible) { entry in
                    HistoryRow(entry: entry)
                }

                if history.entries.count > collapsedCount {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { showAll.toggle() }
                    } label: {
                        if showAll {
                            Label("Show less", systemImage: "chevron.up")
                        } else {
                            Label("Show all (\(history.entries.count))", systemImage: "chevron.down")
                        }
                    }
                    .font(.caption2)
                    .buttonStyle(.link)

                    if showAll && history.entries.count > expandedCap {
                        Text("Showing the latest \(expandedCap).")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

struct HistoryRow: View {
    let entry: HistoryEntry
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: entry.kind == .dictation ? "mic.fill" : "wand.and.stars")
                    .font(.caption2)
                    .foregroundStyle(.tint)
                Text(entry.title).font(.caption.weight(.medium))
                Spacer()
                Text(entry.date, style: .time)
                    .font(.caption2).foregroundStyle(.secondary)
                Button {
                    expanded.toggle()
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption2)
                }
                .buttonStyle(.plain)
            }

            Text(entry.output)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(expanded ? nil : 2)
                .textSelection(.enabled)

            if expanded {
                if !entry.input.isEmpty {
                    Text(entry.kind == .transform ? "From:" : "Raw:")
                        .font(.caption2).foregroundStyle(.tertiary)
                    Text(entry.input)
                        .font(.caption2).foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
                HStack {
                    Spacer()
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(entry.output, forType: .string)
                    }
                    .font(.caption2).buttonStyle(.link)
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.windowBackgroundColor).opacity(0.5)))
    }
}
