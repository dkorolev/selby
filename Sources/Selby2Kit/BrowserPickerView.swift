import Selby2Core
import SwiftUI

/// The picker's content: the clicked URL above one row per browser. Keys
/// are handled by `PickerPanel`; this view handles hover and click.
struct BrowserPickerView: View {
    @ObservedObject var model: PickerModel
    /// Cap so the panel always fits its screen; the list scrolls past it.
    let maxListHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            urlHeader
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(model.browsers.enumerated()), id: \.element.id) { index, browser in
                            row(browser, index: index).id(browser.id)
                        }
                    }
                }
                // Hug the content, never exceed the screen-derived cap.
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxHeight: maxListHeight)
                .onChange(of: model.selection) { _, selection in
                    if model.browsers.indices.contains(selection) {
                        proxy.scrollTo(model.browsers[selection].id)
                    }
                }
            }
            footer
        }
        .padding(6)
        .frame(minWidth: 230, maxWidth: 320, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1))
    }

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

    /// Build identity plus the always-reachable door into Settings: a
    /// crowded menu bar can hide the globe icon, but not the picker.
    private var footer: some View {
        VStack(spacing: 2) {
            Divider().padding(.horizontal, 4)
            HStack {
                Text("Selby2 \(BuildInfo.label)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    model.requestSettings()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Selby2 Settings")
            }
            .frame(height: 16)
            .padding(.horizontal, 10)
            .padding(.top, 1)
            .padding(.bottom, 3)
        }
    }

    private func row(_ browser: Browser, index: Int) -> some View {
        let isSelected = index == model.selection
        let secondary = isSelected ? Color.white.opacity(0.85) : Color.secondary
        return HStack(spacing: 8) {
            Image(nsImage: browser.icon)
                .resizable()
                .frame(width: 20, height: 20)
            Text(browser.name)
                .lineLimit(1)
            Spacer(minLength: 12)
            if index == model.defaultIndex {
                Text("↩").font(.caption).foregroundStyle(secondary)
            }
            if index < 9 {
                Text("\(index + 1)").font(.caption.monospacedDigit()).foregroundStyle(secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.accentColor : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture { model.choose(index) }
        .onHover { hovering in
            if hovering { model.hover(index) }
        }
    }
}
