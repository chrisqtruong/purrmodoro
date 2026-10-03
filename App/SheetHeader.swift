import SwiftUI

/// Title on the left, Done on the right, on one line. Used at the top of each sheet.
struct SheetHeader<Title: View>: View {
    let done: () -> Void
    @ViewBuilder let title: Title

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            title
            Spacer(minLength: 0)
            Button("Done", action: done)
                .font(.rounded(.body, weight: .semibold))
                .foregroundStyle(Theme.caramel)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.card, in: Capsule())
                .buttonStyle(SquishStyle())
        }
        .padding(.top, 12)
    }
}

extension Text {
    /// The big title style for sheets.
    func sheetTitle() -> some View {
        font(.system(size: 30, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

/// The notebook's name, which she can tap to rename ("Sarah's notebook").
struct NotebookTitle: View {
    static let fallback = "Focus notebook"
    static let maxLength = 24

    @AppStorage("notebookName") private var name = ""
    @State private var editing = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        if editing {
            TextField(Self.fallback, text: $draft)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .tint(Theme.caramel)
                .focused($focused)
                .submitLabel(.done)
                .textInputAutocapitalization(.sentences)
                .padding(.bottom, 4)
                .overlay(alignment: .bottom) {
                    Capsule().fill(Theme.caramel).frame(height: 2)
                }
                .onChange(of: draft) { _, text in
                    if text.count > Self.maxLength { draft = String(text.prefix(Self.maxLength)) }
                }
                .onSubmit(commit)
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { commit() }
                }
                .task { focused = true }
        } else {
            Button {
                Haptics.tap()
                draft = name
                editing = true
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(name.isEmpty ? Self.fallback : name).sheetTitle()
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.inkSoft.opacity(0.7))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(name.isEmpty ? Self.fallback : name). Rename")
        }
    }

    /// Saves the new name; an empty name brings back the default.
    private func commit() {
        guard editing else { return }
        name = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        editing = false
    }
}
