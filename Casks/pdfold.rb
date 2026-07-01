cask "pdfold" do
  version :latest
  sha256 :no_check

  url "https://github.com/udhawan97/PDFold/releases/latest/download/pdFold.zip"
  name "pdFold"
  desc "Native macOS workspace for organizing documents into PDF workflows"
  homepage "https://github.com/udhawan97/PDFold"

  depends_on macos: :sonoma

  app "pdFold.app"

  uninstall quit: "com.ud.PDFold"

  zap trash: [
    "~/.pdfold",
    "~/Library/Application Support/pdFold",
    "~/Library/Caches/com.ud.PDFold",
    "~/Library/Preferences/com.ud.PDFold.plist",
    "~/Library/Saved Application State/com.ud.PDFold.savedState",
  ]
end
