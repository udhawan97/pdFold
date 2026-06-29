import SwiftUI
import AppKit

struct AppIconMark: View {
    var size: CGFloat = 44

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .shadow(color: .black.opacity(0.10), radius: size * 0.10, x: 0, y: size * 0.05)
    }
}

struct AppIconButton: View {
    var size: CGFloat = 24
    @State private var isPresented = false

    var body: some View {
        Button { isPresented.toggle() } label: {
            AppIconMark(size: size)
        }
        .buttonStyle(.plain)
        .help("About PDFold")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            AppAboutPopover(isPresented: $isPresented)
        }
    }
}

struct AppAboutPopover: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: .dsLG) {
            HStack(spacing: .dsMD) {
                AppIconMark(size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text("PDFold")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.dsTextPrimary)
                    Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0")")
                        .font(.dsCaption())
                        .foregroundStyle(Color.dsTextTertiary)
                }
            }

            Text("Here to fix the tiny PDF annoyances macOS somehow left as character-building exercises.")
                .font(.dsBody())
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 240)

            Text("Combine, annotate, reorder, and export documents — without the ceremony.")
                .font(.dsCaption())
                .foregroundStyle(Color.dsTextTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 240)

            HStack {
                Spacer()
                Button("Close") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(.dsLG)
        .frame(width: 272)
        .background(Color.dsSurface)
    }
}

struct GuideButton: View {
    var autoShow = false
    @State private var isPresented = false
    @AppStorage("PDFold.hasSeenGuidePopover") private var hasSeenGuidePopover = false

    var body: some View {
        Button {
            isPresented.toggle()
            hasSeenGuidePopover = true
        } label: {
            Image(systemName: "questionmark.circle")
        }
        .help("Show quick guide")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            GuidePopover(isPresented: $isPresented)
        }
        .onAppear {
            guard autoShow, !hasSeenGuidePopover else { return }
            hasSeenGuidePopover = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                isPresented = true
            }
        }
    }
}

private struct GuidePopover: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: .dsXL) {
            HStack(spacing: .dsMD) {
                AppIconMark(size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text("PDFold")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.dsTextPrimary)
                    Text("A calmer way to assemble PDFs.")
                        .font(.dsCaption())
                        .foregroundStyle(Color.dsTextSecondary)
                }
            }

            VStack(alignment: .leading, spacing: .dsMD) {
                GuideStep(icon: "plus.circle",
                          title: "Add files",
                          detail: "Drop documents into the window or use the add button.")
                GuideStep(icon: "square.stack.3d.down.right",
                          title: "Arrange pages",
                          detail: "Expand a source file, select pages, then drag thumbnails up or down.")
                GuideStep(icon: "highlighter",
                          title: "Annotate",
                          detail: "Highlight, add notes, draw, or place your signature.")
                GuideStep(icon: "square.and.arrow.up",
                          title: "Export",
                          detail: "Export a clean PDF or save the editable workspace.")
            }

            HStack {
                Spacer()
                Button("Got it") { isPresented = false }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.dsAccent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.dsLG)
        .frame(width: 310)
        .background(Color.dsSurface)
    }
}

private struct GuideStep: View {
    var icon: String
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: .dsSM) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.dsAccent)
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.dsTextPrimary)
                Text(detail)
                    .font(.dsCaption())
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
