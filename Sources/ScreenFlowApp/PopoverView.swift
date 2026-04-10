import SwiftUI
import ServiceManagement
import ScreenFlowCore

// MARK: - PopoverView

struct PopoverView: View {
    @ObservedObject var store: ScreenshotStore
    let openGallery: () -> Void

    @State private var copiedID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            screenshotList
            footer
        }
        .frame(width: 320, height: 400)
    }

    private var header: some View {
        HStack {
            Text("ScreenFlow")
                .font(.headline)
            Spacer()
            Button("Gallery →", action: openGallery)
                .buttonStyle(.borderless)
                .font(.subheadline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var screenshotList: some View {
        Group {
            if store.screenshots.isEmpty {
                Text("No screenshots yet")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(store.screenshots.prefix(8)) { shot in
                            PopoverRow(
                                screenshot: shot,
                                isCopied: copiedID == shot.id,
                                onTap: { copy(shot) }
                            )
                            if shot != store.screenshots.prefix(8).last {
                                Divider().padding(.leading, 70)
                            }
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                LaunchAtLoginToggle()
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private func copy(_ screenshot: Screenshot) {
        guard ClipboardManager.copy(screenshot: screenshot) else { return }
        copiedID = screenshot.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedID == screenshot.id { copiedID = nil }
        }
    }
}

// MARK: - PopoverRow

struct PopoverRow: View {
    let screenshot: Screenshot
    let isCopied: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ThumbnailView(url: screenshot.url, size: CGSize(width: 56, height: 42))
                    .frame(width: 56, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 2) {
                    Text(screenshot.filename)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(screenshot.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isCopied {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isCopied ? Color.accentColor.opacity(0.08) : Color.clear)
        .animation(.easeInOut(duration: 0.2), value: isCopied)
    }
}

// MARK: - LaunchAtLoginToggle

struct LaunchAtLoginToggle: View {
    @State private var isOn = (SMAppService.mainApp.status == .enabled)

    var body: some View {
        Toggle("Launch at Login", isOn: $isOn)
            .toggleStyle(.checkbox)
            .font(.caption2)
            .onChange(of: isOn) { enabled in
                do {
                    if enabled {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    isOn = !enabled
                }
            }
    }
}
