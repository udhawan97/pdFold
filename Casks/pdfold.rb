cask "pdfold" do
  version :latest
  sha256 :no_check

  url "https://github.com/udhawan97/pdFold/releases/latest/download/pdFold.zip"
  name "pdFold"
  desc "Local-first workspace for organizing documents into PDF workflows"
  homepage "https://github.com/udhawan97/pdFold"

  depends_on macos: :sonoma

  app "pdFold.app"

  postflight do
    [
      "#{staged_path}/pdFold.app",
      "#{appdir}/pdFold.app",
    ].each do |app_path|
      next unless File.exist?(app_path)

      system_command "/usr/bin/xattr",
                     args:         ["-cr", app_path],
                     print_stderr: false
    end
  end

  uninstall quit: "com.ud.PDFold"

  zap trash: [
    "~/.pdfold",
    "~/Library/Application Support/pdFold",
    "~/Library/Caches/com.ud.PDFold",
    "~/Library/Preferences/com.ud.PDFold.plist",
    "~/Library/Saved Application State/com.ud.PDFold.savedState",
  ]

  caveats <<~EOS
    pdFold release builds are ad-hoc signed and not notarized yet.
    This cask removes download quarantine after installation so macOS can open
    the app like the one-line installer does. Fully silent Gatekeeper installs
    require a Developer ID signed and notarized release.
  EOS
end
