import AppKit
import SwiftUI

/// The barcodes found on a page, wrapped so the scan-result sheet can be driven by
/// `.sheet(item:)` (an empty `barcodes` array still presents, showing the empty state).
struct BarcodeScanResults: Identifiable {
    let id = UUID()
    var barcodes: [DetectedBarcode]
}

/// Feature G4: lists the barcodes a page scan found. Each row can Copy its payload; a payload
/// that is a well-formed http(s) URL also gets an Open-link button — but the barcode payload is
/// untrusted input, so opening is gated behind an explicit confirmation that shows the FULL URL
/// and never auto-opens.
struct BarcodeScanResultSheet: View {
    let barcodes: [DetectedBarcode]
    @Environment(\.dismiss) private var dismiss
    // Read so SwiftUI re-invokes `body` on a language change (see L10n.string docs).
    @Environment(\.locale) private var locale

    /// The URL awaiting the user's explicit confirmation before opening. Never opened directly.
    @State private var pendingURL: URL?
    /// The payload most recently copied, so its row can show a transient confirmation.
    @State private var copiedPayload: String?

    var body: some View {
        VStack(alignment: .leading, spacing: .dsLG) {
            Text(L10n.string("barcode.scan.title", locale: locale))
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(Color.dsTextPrimary)

            if barcodes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: .dsSM) {
                        ForEach(Array(barcodes.enumerated()), id: \.offset) { _, barcode in
                            row(for: barcode)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }

            HStack {
                Spacer()
                Button(L10n.string("contentView.done.button", locale: locale)) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.dsXL)
        .frame(width: 380)
        .background(Color.dsSurface)
        .confirmationDialog(
            pendingURL?.absoluteString ?? "",
            isPresented: Binding(get: { pendingURL != nil }, set: { if !$0 { pendingURL = nil } }),
            titleVisibility: .visible
        ) {
            if let url = pendingURL {
                Button(L10n.string("barcode.result.openLink", locale: locale)) {
                    // Only ever reached after the user reads the full URL and confirms.
                    NSWorkspace.shared.open(url)
                    pendingURL = nil
                }
            }
            Button(L10n.string("contentView.exportSheet.cancel.button", locale: locale), role: .cancel) {
                pendingURL = nil
            }
        } message: {
            if let url = pendingURL {
                Text(url.absoluteString)
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: .dsSM) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 20))
                .foregroundStyle(Color.dsTextTertiary)
            Text(L10n.string("barcode.result.empty", locale: locale))
                .font(.system(size: 13))
                .foregroundStyle(Color.dsTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, .dsMD)
    }

    private func row(for barcode: DetectedBarcode) -> some View {
        HStack(alignment: .top, spacing: .dsSM) {
            VStack(alignment: .leading, spacing: 2) {
                Text(barcode.payload)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.dsTextPrimary)
                    .textSelection(.enabled)
                    .lineLimit(3)
                    .truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: true)
                if let symbology = barcode.symbology {
                    Text(symbology.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.dsTextTertiary)
                }
            }
            Spacer(minLength: .dsSM)

            if let url = webURL(from: barcode.payload) {
                Button {
                    // Arm the confirmation — do NOT open here.
                    pendingURL = url
                } label: {
                    Label(L10n.string("barcode.result.openLink", locale: locale), systemImage: "arrow.up.right.square")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help(L10n.string("barcode.result.openLink", locale: locale))
            }

            Button {
                copy(barcode.payload)
            } label: {
                Label(
                    L10n.string("barcode.result.copy", locale: locale),
                    systemImage: copiedPayload == barcode.payload ? "checkmark" : "doc.on.doc"
                )
                .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help(L10n.string("barcode.result.copy", locale: locale))
        }
        .padding(.dsSM)
        .background(
            RoundedRectangle(cornerRadius: .dsRadiusSm, style: .continuous)
                .fill(Color.dsCanvas)
        )
        .overlay {
            RoundedRectangle(cornerRadius: .dsRadiusSm, style: .continuous)
                .strokeBorder(Color.dsSeparator, lineWidth: 1)
        }
    }

    /// Returns a URL only for a well-formed http/https payload with a host. Everything else —
    /// plain text, `file:`, custom or dangerous schemes (`javascript:`…) — gets no Open button,
    /// so only ordinary web links are ever offered, and even then only behind confirmation.
    private func webURL(from payload: String) -> URL? {
        guard let url = URL(string: payload.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host?.isEmpty == false else {
            return nil
        }
        return url
    }

    private func copy(_ payload: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(payload, forType: .string)
        copiedPayload = payload
    }
}

extension BarcodeSymbology {
    /// The standard, brand-neutral name for each symbology. Deliberately not localized —
    /// "QR", "Aztec", "Code 128", and "PDF417" are the codes' proper names in every language.
    var displayName: String {
        switch self {
        case .qr: return "QR"
        case .aztec: return "Aztec"
        case .code128: return "Code 128"
        case .pdf417: return "PDF417"
        }
    }
}
