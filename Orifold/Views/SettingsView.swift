import SwiftUI

/// The app's native macOS Settings window (⌘,). Scoped to controls that already have a
/// real, working implementation elsewhere in the app — language and appearance already
/// propagate live to open documents via the existing `@AppStorage`/`onChange` wiring in
/// `ContentView`; Night Mode defaults seed newly opened documents. Deliberately does not
/// add toolbar density/label toggles or export-default pickers, since those preferences
/// have no backing behavior anywhere in the app yet — a Settings row that doesn't change
/// anything would be worse than no row at all.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("settings.tab.general", systemImage: "gearshape")
                }

            NightModeSettingsTab()
                .tabItem {
                    Label("settings.tab.nightMode", systemImage: "moon.stars")
                }
        }
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct GeneralSettingsTab: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @AppStorage("orifoldAppAppearanceMode") private var persistedAppAppearanceMode = AppAppearanceMode.system.rawValue

    private var appearanceModeBinding: Binding<AppAppearanceMode> {
        Binding(
            get: { AppAppearanceMode(rawValue: persistedAppAppearanceMode) ?? .system },
            set: { persistedAppAppearanceMode = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Picker("settings.language.label", selection: $languageManager.language) {
                ForEach(SupportedLanguage.allCases) { language in
                    Text(language.nativeName).tag(language)
                }
            }

            Picker("settings.appearance.label", selection: appearanceModeBinding) {
                ForEach(AppAppearanceMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage).tag(mode)
                }
            }
        }
        .padding(.dsXL)
    }
}

private struct NightModeSettingsTab: View {
    @AppStorage("orifoldNightModeWarmth") private var warmth = NightModeSettings.default.warmth
    @AppStorage("orifoldNightModeIntensity") private var intensity = NightModeSettings.default.intensity
    @AppStorage("orifoldNightModeDimming") private var dimming = NightModeSettings.default.dimming

    var body: some View {
        VStack(alignment: .leading, spacing: .dsMD) {
            Text("settings.nightModeDefaults.description")
                .font(.dsCaption())
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            settingsSlider(title: "contentView.nightModeControls.warmth.title", systemImage: "thermometer.sun", value: $warmth)
            settingsSlider(title: "contentView.nightModeControls.tone.title", systemImage: "circle.lefthalf.filled", value: $intensity)
            settingsSlider(title: "contentView.nightModeControls.dimming.title", systemImage: "sun.min", value: $dimming)

            Button("settings.nightModeDefaults.reset.button") {
                warmth = NightModeSettings.default.warmth
                intensity = NightModeSettings.default.intensity
                dimming = NightModeSettings.default.dimming
            }
        }
        .padding(.dsXL)
    }

    private func settingsSlider(title: LocalizedStringKey, systemImage: String, value: Binding<Double>) -> some View {
        HStack(spacing: .dsSM) {
            Image(systemName: systemImage)
                .frame(width: 18)
                .foregroundStyle(Color.dsTextTertiary)
            Text(title)
                .font(.dsCaption())
                .foregroundStyle(Color.dsTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 78, alignment: .leading)
            Slider(value: value, in: 0...1, step: 0.01)
            Text("\(Int(value.wrappedValue * 100))%")
                .font(.dsCaption())
                .foregroundStyle(Color.dsTextSecondary)
                .monospacedDigit()
                .frame(width: 42, alignment: .trailing)
        }
    }
}
