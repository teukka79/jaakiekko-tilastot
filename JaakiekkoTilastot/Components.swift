import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Logot

@MainActor
enum LogoLoader {
    private static var cache: [String: NSImage] = [:]
    private static var failed: Set<URL> = []

    /// maxPixel > 0: kuva pienennetään tarkasti (ImageIO) tähän pikselikokoon, jolloin pieni logo ei ole epätarkka.
    static func load(_ url: URL, maxPixel: Int = 0) async -> NSImage? {
        let key = "\(url.absoluteString)#\(maxPixel)"
        if let img = cache[key] { return img }
        if failed.contains(url) { return nil }
        var data: Data? = LogoDisk.read(url)
        if data == nil {
            do {
                let (d, response) = try await URLSession.shared.data(from: url)
                guard (response as? HTTPURLResponse)?.statusCode == 200, NSImage(data: d) != nil else {
                    failed.insert(url); return nil
                }
                LogoDisk.write(d, for: url)
                data = d
            } catch {
                failed.insert(url); return nil
            }
        }
        guard let data else { return nil }
        if maxPixel > 0, let scaled = downsample(data, maxPixel: maxPixel) {
            cache[key] = scaled
            return scaled
        }
        guard let img = NSImage(data: data) else { failed.insert(url); return nil }
        cache[key] = img
        return img
    }

    private static func downsample(_ data: Data, maxPixel: Int) -> NSImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int, w > maxPixel else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        // Pikselikoko 3x näyttökokoon nähden: piirretään pisteinä maxPixel/3
        let pts = CGFloat(maxPixel) / 3
        let ratio = CGFloat(cg.height) / CGFloat(max(cg.width, 1))
        return NSImage(cgImage: cg, size: NSSize(width: pts, height: pts * ratio))
    }
}

/// Joukkueen logo (NHL:n viralliset tai käyttäjän asettama URL). Jos logoa ei ole tai se ei lataudu, näytetään lyhennemerkki.
struct TeamLogoView: View {
    @Environment(AppStore.self) private var store
    let team: String
    var size: CGFloat = 28
    @State private var image: NSImage?

    var body: some View {
        let url = store.logoURL(for: team)
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                TeamBadge(name: team, abbr: store.abbr(for: team))
            }
        }
        // NHL:n logoissa on sisäinen reunus, muiden liigojen logot täyttävät koko ruudun → pienennetään niitä
        .frame(width: size * (url?.host?.contains("nhle.com") == true ? 1.0 : 0.76),
               height: size * (url?.host?.contains("nhle.com") == true ? 1.0 : 0.76))
        .frame(width: size, height: size)
        .task(id: url) {
            image = nil
            if let url { image = await LogoLoader.load(url, maxPixel: Int((size * 3).rounded())) }
        }
    }
}

// MARK: - Tähdet

struct StarsView: View {
    let value: Int
    var size: CGFloat = 14
    var onSelect: ((Int) -> Void)?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...3, id: \.self) { i in
                let star = Image(systemName: i <= value ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(i <= value ? Theme.amber : Theme.muted.opacity(0.6))
                if let onSelect {
                    Button { onSelect(i) } label: { star }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(i) tähteä")
                } else {
                    star
                }
            }
        }
    }
}

// MARK: - JSON-varmuuskopio

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Pienet apurit

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(Theme.muted)
    }
}

struct Chip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(hex: 0xCBD5E1))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color.white.opacity(0.07), in: Capsule())
    }
}

func signed(_ v: Int?) -> String {
    guard let v else { return "–" }
    return v > 0 ? "+\(v)" : "\(v)"
}

func num(_ v: Int?) -> String { v.map(String.init) ?? "–" }

func ppgString(_ v: Double?) -> String {
    guard let v else { return "–" }
    return String(format: "%.2f", v).replacingOccurrences(of: ".", with: ",")
}
