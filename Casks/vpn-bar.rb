cask "vpn-bar" do
  version "0.5.3"
  sha256 "d55e7cc2fd6094d474b4bf73c524dea9c9f346ef2722e04c7d2d1b9b7ea2e398"

  url "https://github.com/borzov/vpn-bar/releases/download/v#{version}/VPNBarApp.zip"
  name "VPN Bar"
  desc "Menu bar app for managing VPN connections on macOS"
  homepage "https://github.com/borzov/vpn-bar"

  depends_on macos: ">= :monterey"

  app "VPNBarApp.app"

  zap trash: "~/Library/Preferences/com.borzov.VPNBar.plist"
end
