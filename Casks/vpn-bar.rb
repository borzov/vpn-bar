cask "vpn-bar" do
  version "0.8.0"
  sha256 "2be875ed69f20deda2858a931102030f43d7efa933eb2e89bf112bb7d44213dc"

  url "https://github.com/borzov/vpn-bar/releases/download/v#{version}/VPNBarApp.zip"
  name "VPN Bar"
  desc "Menu bar app for managing VPN connections on macOS"
  homepage "https://github.com/borzov/vpn-bar"

  depends_on macos: ">= :monterey"

  # ZIP archive structure: VPNBarApp.zip -> VPNBarApp.app/Contents/...
  # Homebrew Cask expects the app bundle in the root of the archive
  app "VPNBarApp.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/VPNBarApp.app"],
                   sudo: false
  end

  caveats <<~EOS
    This app is not signed with an Apple Developer certificate.
    When installed via Homebrew, xattr -cr is applied automatically after installation.
    If you installed from ZIP or still see "damaged" on first launch, run:
      sudo xattr -cr /Applications/VPNBarApp.app
    (or ~/Applications/VPNBarApp.app if using the default Homebrew appdir)
  EOS

  zap trash: "~/Library/Preferences/com.borzov.VPNBar.plist"
end
