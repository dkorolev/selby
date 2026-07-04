import SelbyCore
import SwiftUI

/// Selby's entire configuration surface: which browsers to show, their order
/// (the top one is what Return opens), and a button to make Selby the macOS
/// default browser.
struct SettingsView: View {
    @ObservedObject private var store = SettingsStore.shared

    /// Snapshot of "is Selby the macOS default browser", refreshed on appear
    /// and after the make-default request round-trips.
    @State private var isSystemDefault = false
    /// Error from the most recent make-default attempt, shown inline.
    @State private var makeDefaultError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Browsers")
                .font(.headline)
            Text("Toggle to show or hide. Drag to reorder — the picker, its 1–9 shortcuts, "
                + "and ↩ (which always opens the top browser) follow this order.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // A real List, not a Form section: on macOS only List rows are
            // draggable, and drag-reordering is this screen's core feature.
            List {
                ForEach(store.browsers) { browser in
                    let pickerIndex = pickerIndices[browser.id]
                    HStack(spacing: 8) {
                        // The row's number in the picker — exactly what the
                        // 1–9 shortcuts will hit; hidden rows have none.
                        Text(pickerIndex.map(String.init) ?? "")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 22, alignment: .trailing)
                        Image(nsImage: browser.icon)
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text(browser.name)
                        Spacer()
                        if pickerIndex == 1 {
                            // Mirrors the picker: Return opens this one.
                            Text("↩")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Toggle("", isOn: enabledBinding(for: browser))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                    }
                    .opacity(pickerIndex == nil ? 0.5 : 1)
                    .padding(.vertical, 3)
                }
                .onMove { source, destination in
                    store.moveBrowsers(fromOffsets: source, toOffset: destination)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .frame(height: listHeight)
            if store.browsers.isEmpty {
                Text("No browsers found.")
                    .foregroundStyle(.secondary)
            }

            Divider()
                .padding(.vertical, 4)

            if isSystemDefault {
                Label("Selby is your default browser", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Make Selby the default browser…") {
                    makeDefault()
                }
                Text("Selby must be the macOS default browser to catch link clicks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let makeDefaultError {
                Text(makeDefaultError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(width: 400)
        .onAppear {
            store.refresh()
            isSystemDefault = store.isSystemDefault
        }
    }

    /// Enough rows to show everything without inner scrolling, within
    /// reason — generously tall so rearranging has room to breathe.
    private var listHeight: CGFloat {
        max(280, min(CGFloat(store.browsers.count) * 32 + 20, 600))
    }

    /// Each enabled browser's 1-based position in the picker (= its digit
    /// shortcut for the first nine); hidden browsers are absent.
    private var pickerIndices: [String: Int] {
        Dictionary(uniqueKeysWithValues: store.enabledBrowsers.enumerated().map { ($1.id, $0 + 1) })
    }

    /// Two-way binding between a browser's toggle and the disabled-set.
    private func enabledBinding(for browser: Browser) -> Binding<Bool> {
        Binding(
            get: { store.isEnabled(browser) },
            set: { store.setEnabled($0, for: browser) }
        )
    }

    private func makeDefault() {
        makeDefaultError = nil
        store.makeSystemDefault { error in
            Task { @MainActor in
                if let error {
                    makeDefaultError = error.localizedDescription
                }
                isSystemDefault = store.isSystemDefault
            }
        }
    }
}
