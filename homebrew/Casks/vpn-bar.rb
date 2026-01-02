cask "vpn-bar" do
  version "0.5.2"
  sha256 "SHA256_PLACEHOLDER"

  url "https://github.com/borzov/VPNBarApp/releases/download/v#{version}/VPNBarApp.zip"
  name "VPN Bar"
  desc "Menu bar app for managing VPN connections on macOS"
  homepage "https://github.com/borzov/VPNBarApp"

  depends_on macos: ">= :monterey"

  app "VPNBarApp.app"

  zap trash: "~/Library/Preferences/com.borzov.VPNBar.plist"
end
