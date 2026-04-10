import SwiftUI
import ScreenFlowCore

// MARK: - GalleryView

struct GalleryView: View {
    @ObservedObject var store: ScreenshotStore
    @State private var selectedID: UUID?
    @State private var copiedID: UUID?
    @State private var thumbnailSize: CGFloat = 200
    @State private var searchText = ""

    private var filtered: [Screenshot] {
        guard !searchText.isEmpty else { return store.screenshots }
        return store.screenshots.filter {
            $0.filename.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            contentArea
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search screenshots…", text: $searchText)
                .textFieldStyle(.plain)

            Spacer()

            Label("Size", systemImage: "photo")
                .font(.caption)
                .foregroundColor(.secondary)
                .labelStyle(.iconOnly)
            Slider(value: $thumbnailSize, in: 120...340, step: 20)
                .frame(width: 90)

            Divider().frame(height: 16)

            Button(action: { store.load() }) {
                Image(systemName: "arrow.clockwise")
            }
            .help("Reload from disk")
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: Content

    private var contentArea: some View {
        Group {
            if filtered.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: thumbnailSize, maximum: thumbnailSize + 40), spacing: 14)],
                        spacing: 14
                    ) {
                        ForEach(filtered) { shot in
                            ScreenshotCard(
                                screenshot: shot,
                                thumbnailSize: thumbnailSize,
                                isSelected: selectedID == shot.id,
                                isCopied: copiedID == shot.id,
                                onTap: { select(shot) },
                                onReveal: { revealInFinder(shot) }
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.stack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(searchText.isEmpty ? "No screenshots found" : "No results for \"\(searchText)\"")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Actions

    private func select(_ shot: Screenshot) {
        selectedID = shot.id
        if ClipboardManager.copy(screenshot: shot) {
            copiedID = shot.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if copiedID == shot.id { copiedID = nil }
            }
        }
    }

    private func revealInFinder(_ shot: Screenshot) {
        NSWorkspace.shared.activateFileViewerSelecting([shot.url])
    }
}

// MARK: - ScreenshotCard

struct ScreenshotCard: View {
    let screenshot: Screenshot
    let thumbnailSize: CGFloat
    let isSelected: Bool
    let isCopied: Bool
    let onTap: () -> Void
    let onReveal: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            thumbnail
            metadata
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .onTapGesture(count: 2) { onReveal() }
        .onTapGesture(count: 1) { onTap() }
        .contextMenu {
            Button("Copy to Clipboard") { onTap() }
            Button("Show in Finder") { onReveal() }
        }
        .animation(.easeInOut(duration: 0.15), value: isCopied)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var thumbnail: some View {
        ZStack {
            ThumbnailView(
                url: screenshot.url,
                size: CGSize(width: thumbnailSize, height: thumbnailSize * 0.75)
            )
            .frame(width: thumbnailSize, height: thumbnailSize * 0.75)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Selection border
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                .frame(width: thumbnailSize, height: thumbnailSize * 0.75)

            // Copied overlay
            if isCopied {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.45))
                    .frame(width: thumbnailSize, height: thumbnailSize * 0.75)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .shadow(radius: 4)
            }
        }
    }

    private var metadata: some View {
        VStack(spacing: 2) {
            Text(screenshot.filename)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(.primary)
            Text(screenshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: thumbnailSize)
    }
}

// MARK: - ThumbnailView

/// Loads and displays a screenshot thumbnail asynchronously.
struct ThumbnailView: View {
    let url: URL
    let size: CGSize

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }
        }
        .task(id: url) { await loadThumbnail() }
    }

    @MainActor
    private func loadThumbnail() async {
        guard image == nil else { return }
        image = await Task.detached(priority: .userInitiated) {
            NSImage(contentsOf: url)
        }.value
    }
}
