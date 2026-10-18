import Selby2Core
import SwiftUI

/// Tracks "is Selby2 the macOS default browser" for the Settings window.
@MainActor
final class DefaultBrowserStatus: ObservableObject {
    @Published var isDefault = false
    @Published var error: String?

    func refresh() {
        isDefault = DefaultBrowser.isSelby2
    }

    func makeDefault() {
        error = nil
        DefaultBrowser.makeSelby2 { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.error = error?.localizedDescription
                self.refresh()
            }
        }
    }
}

/// The whole configuration surface: which browsers to show, their order
/// (the top one is what Return opens), and the make-default button.
public struct SettingsView: View {
    @ObservedObject private var store: SettingsStore
    @StateObject private var status = DefaultBrowserStatus()

    public init(store: SettingsStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Browsers").font(.headline)
            Text("Toggle to show or hide. Drag to reorder: the picker, its 1–9 shortcuts, "
                + "and ↩ (which opens the top browser) follow this order. "
                + "Private and Incognito entries start hidden.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // A List, not a Form: on macOS only List rows are draggable.
            List {
                ForEach(store.browsers) { browser in
                    row(browser, pickerIndex: pickerIndices[browser.id])
                }
                .onMove { source, destination in
                    store.move(fromOffsets: source, toOffset: destination)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .frame(height: listHeight)
            if store.browsers.isEmpty {
                Text("No browsers found.").foregroundStyle(.secondary)
            }

            Divider().padding(.vertical, 4)

            if status.isDefault {
                Label("Selby2 is your default browser", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Make Selby2 the default browser…") { status.makeDefault() }
                Text("Selby2 must be the macOS default browser to catch link clicks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let error = status.error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(width: 400)
        .onAppear {
            store.refresh()
            status.refresh()
        }
    }

    private func row(_ browser: Browser, pickerIndex: Int?) -> some View {
        HStack(spacing: 8) {
            // The row's number in the picker, which is its digit shortcut.
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
                Text("↩").font(.caption).foregroundStyle(.secondary)
            }
            Toggle("", isOn: visibleBinding(for: browser))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
        .opacity(pickerIndex == nil ? 0.5 : 1)
        .padding(.vertical, 3)
    }

    /// Tall enough to show everything without inner scrolling, within reason.
    private var listHeight: CGFloat {
        max(280, min(CGFloat(store.browsers.count) * 32 + 20, 600))
    }

    /// Each visible browser's 1-based picker position; hidden ones are absent.
    private var pickerIndices: [String: Int] {
        Dictionary(uniqueKeysWithValues: store.visibleBrowsers.enumerated().map { ($1.id, $0 + 1) })
    }

    private func visibleBinding(for browser: Browser) -> Binding<Bool> {
        Binding(get: { store.isVisible(browser) }, set: { store.setVisible($0, browser) })
    }
}
