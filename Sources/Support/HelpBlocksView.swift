import SwiftUI

/// One numbered instruction, with optional indented follow-ups.
struct HelpStep {
    let text: String
    var details: [String] = []
}

/// Building blocks for long-form help screens. Every string is a key in the screen's strings table.
enum HelpBlock {
    case paragraph(String)
    case heading(String)
    case terms([(term: String, detail: String)])
    case steps([HelpStep])
    case bullets([String])
    case notes([String])
    /// Literal text such as SMS examples; shown monospaced and never translated.
    case example(String)
}

/// Renders help blocks inside a card, matching the SMS report information sheet.
struct HelpBlocksView: View {
    let blocks: [HelpBlock]
    let table: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                if index > 0 { Divider() }
                blockView(block)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func text(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: table)
    }

    @ViewBuilder
    private func blockView(_ block: HelpBlock) -> some View {
        switch block {
        case .paragraph(let key):
            Text(text(key))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        case .heading(let key):
            Text(text(key))
                .font(.subheadline.weight(.semibold))
        case .terms(let terms):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(terms, id: \.term) { item in
                    (Text(text(item.term)).fontWeight(.semibold) + Text(": ") + Text(text(item.detail)))
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        case .steps(let steps):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .background(Color(uiColor: .tertiarySystemFill), in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(text(step.text))
                            ForEach(step.details, id: \.self) { detail in
                                Text(text(detail)).foregroundStyle(.secondary)
                            }
                        }
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(.secondary)
                        Text(text(item))
                    }
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        case .notes(let notes):
            VStack(alignment: .leading, spacing: 6) {
                Label(text("Notes"), systemImage: "info.circle")
                    .font(.caption.weight(.semibold))
                ForEach(notes, id: \.self) { note in
                    Text(text(note))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        case .example(let literal):
            Text(verbatim: literal)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}

/// A titled group of help blocks, used by the long-form help screens.
struct HelpSection: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let blocks: [HelpBlock]
}

/// Scrollable help document: an intro, then one headed card per section.
/// `title` and section texts are keys in `table`.
struct HelpDocumentView<Footer: View>: View {
    let navigationTitle: LocalizedStringKey
    let intro: String
    let sections: [HelpSection]
    let table: String
    @ViewBuilder var footer: Footer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(Bundle.main.localizedString(forKey: intro, value: nil, table: table))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)

                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Label(
                            Bundle.main.localizedString(forKey: section.title, value: nil, table: table),
                            systemImage: section.symbol
                        )
                        .font(.headline)
                        HelpBlocksView(blocks: section.blocks, table: table)
                    }
                }

                footer
            }
            .padding()
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .navigationTitle(navigationTitle)
    }
}
