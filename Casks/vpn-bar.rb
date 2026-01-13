cask "vpn-bar" do
  version "0.6.0"
  sha256 "b78951b88a1d51f0dac4067834d500ac16a91a0dbceefb7fb120782ed02bcd45"

  url "https://github.com/borzov/vpn-bar/releases/download/v#{version}/VPNBarApp.zip"
  name "VPN Bar"
  desc "Menu bar app for managing VPN connections on macOS"
  homepage "https://github.com/borzov/vpn-bar"

  depends_on macos: ">= :monterey"

  app "VPNBarApp.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/VPNBarApp.app"],
                   sudo: false
  end

  caveats <<~EOS
    This app is not signed with an Apple Developer certificate.
    If you see "damaged" error on first launch, run:
      sudo xattr -cr /Applications/VPNBarApp.app
  EOS

  zap trash: "~/Library/Preferences/com.borzov.VPNBar.plist"
end
