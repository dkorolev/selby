import SelbyCore
import SwiftUI

/// The picker's content: the clicked URL (context) above one row per browser.
/// Keyboard events are handled by `PickerPanel`; this view handles hover and
/// click, and renders the selection.
struct BrowserPickerView: View {
    @ObservedObject var model: PickerModel
    /// Cap on the browser-list height so the panel always fits the screen it
    /// opens on; the list scrolls when there are more rows than fit.
    let maxListHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            urlHeader
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(model.browsers.enumerated()), id: \.element.id) { index, browser in
                            row(browser, index: index)
                                .id(browser.id)
                        }
                    }
                }
                // Hug the content height (a bare ScrollView would greedily
                // fill maxListHeight even for two rows), but never exceed the
                // screen-derived cap.
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxHeight: maxListHeight)
                .onChange(of: model.selection) { _, newSelection in
                    // Keep keyboard navigation visible when the list scrolls.
                    if model.browsers.indices.contains(newSelection) {
                        proxy.scrollTo(model.browsers[newSelection].id)
                    }
                }
            }
            footer
        }
        .padding(6)
        .frame(minWidth: 230, maxWidth: 320, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    /// The first clicked URL, middle-truncated — enough context to decide
    /// which browser it deserves. Bursts show how many more URLs ride along.
    @ViewBuilder
    private var urlHeader: some View {
        if let url = model.urls.first {
            let extra = model.urls.count - 1
            Text(extra > 0 ? "\(url.absoluteString)  (+\(extra) more)" : url.absoluteString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 4)
        }
    }

    /// Short git SHA baked into Info.plist by scripts/build.sh; "dev" when
    /// running outside a built bundle (e.g. `swift run`).
    private var buildSHA: String {
        Bundle.main.object(forInfoDictionaryKey: "SelbyGitSHA") as? String ?? "dev"
    }

    /// Identity line plus the always-reachable door into Settings — menu-bar
    /// icons can be hidden by a crowded menu bar, but the picker cannot.
    private var footer: some View {
        VStack(spacing: 2) {
            Divider().padding(.horizontal, 4)
            HStack(alignment: .center) {
                Text("Selby, \(buildSHA)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    model.requestSettings()
                } label: {
                    // Sized like the text so both center on the same line.
                    Image(systemName: "gearshape.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Selby Settings")
            }
            .frame(height: 16)
            .padding(.horizontal, 10)
            .padding(.top, 1)
            .padding(.bottom, 3)
        }
    }

    private func row(_ browser: Browser, index: Int) -> some View {
        let isSelected = index == model.selection
        return HStack(spacing: 8) {
            Image(nsImage: browser.icon)
                .resizable()
                .frame(width: 20, height: 20)
            Text(browser.name)
                .lineLimit(1)
            Spacer(minLength: 12)
            if index == model.defaultIndex {
                Text("↩")
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
            }
            if index < 9 {
                Text("\(index + 1)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { model.choose(index) }
        .onHover { hovering in
            // shouldHonorHover keeps a row that spawned under the stationary
            // cursor from stealing the selection before Enter lands.
            if hovering, model.shouldHonorHover() { model.selection = index }
        }
    }
}
