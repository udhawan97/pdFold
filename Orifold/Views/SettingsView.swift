import SwiftUI

/// The app's native macOS Settings window (⌘,). Scoped to controls that already have a
/// real, working implementation elsewhere in the app — language and appearance already
/// propagate live to open documents via the existing `@AppStorage`/`onChange` wiring in
/// `ContentView`. Deliberately does not add toolbar density/label toggles, export-default
/// pickers, or Document Comfort defaults, since those preferences have no backing behavior
/// (or, for Document Comfort, already have their own dedicated toolbar popover) — a
/// Settings row that doesn't change anything would be worse than no row at all.
struct SettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("orifoldAppAppearanceMode") private var persistedAppAppearanceMode = AppAppearanceMode.system.rawValue
    @State private var updateController = UpdateController.shared

    private var appearanceModeBinding: Binding<AppAppearanceMode> {
        Binding(
            get: { AppAppearanceMode(rawValue: persistedAppAppearanceMode) ?? .system },
            set: { persistedAppAppearanceMode = $0.rawValue }
        )
    }

    private var locale: Locale { languageManager.effectiveLocale }

    var body: some View {
        Form {
            Picker(L10n.string("settings.language.label", locale: locale), selection: $languageManager.language) {
                ForEach(SupportedLanguage.allCases) { language in
                    Text(language.nativeName).tag(language)
                }
            }

            Picker(L10n.string("settings.appearance.label", locale: locale), selection: appearanceModeBinding) {
                ForEach(AppAppearanceMode.allCases) { mode in
                    Label(mode.title(locale: locale), systemImage: mode.systemImage).tag(mode)
                }
            }

            updatesSection
        }
        .padding(.dsXL)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var updatesSection: some View {
        @Bindable var controller = updateController

        Toggle(isOn: $controller.automaticChecksEnabled) {
            Text(L10n.string("settings.updates.automatic.label", locale: locale))
        }
        .help(L10n.string("settings.updates.automatic.help", locale: locale))

        // Check button and status are stacked vertically, and the status text is allowed
        // to wrap, so a long "update available" line lays out on its own row(s) within the
        // fixed-width Settings window instead of bleeding past its right edge.
        VStack(alignment: .leading, spacing: .dsSM) {
            HStack(spacing: .dsSM) {
                Button(L10n.string("settings.updates.checkNow.button", locale: locale)) {
                    Task { await updateController.checkForUpdates(userInitiated: true) }
                }
                .disabled(updateController.phase.isBusy)

                // The animated spinner is the only motion here; Reduce Motion drops it and
                // relies on the disabled button + "Checking…" text to convey progress.
                if updateController.phase.isBusy && !reduceMotion {
                    ProgressView().controlSize(.small)
                }
            }

            updateStatusView
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: updateController.phase)
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch updateController.phase {
        case .checking:
            statusText(L10n.string("settings.updates.status.checking", locale: locale))
        case .upToDate:
            statusText(L10n.format("settings.updates.status.upToDate", updateController.currentVersionString, locale: locale))
        case let .updateAvailable(update):
            VStack(alignment: .leading, spacing: .dsXS) {
                Text(L10n.format("settings.updates.status.available", update.version, locale: locale))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: .dsMD) {
                    Button(L10n.string("settings.updates.action.releaseNotes", locale: locale)) {
                        updateController.openReleaseNotes()
                    }
                    .buttonStyle(.link)
                    Button(L10n.string("update.action.openDownloadPage", locale: locale)) {
                        updateController.openDownloadPage()
                    }
                    .buttonStyle(.link)
                }
            }
        case .failed:
            statusText(L10n.string("settings.updates.status.failed", locale: locale))
        case .idle, .downloading, .readyToInstall:
            EmptyView()
        }
    }

    /// Secondary status line that wraps instead of overflowing the fixed-width window.
    private func statusText(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
