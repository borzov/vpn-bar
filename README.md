# VPN Bar
VPN Bar is a native macOS application that lives in the menu bar and provides quick access to VPN connection management. The app automatically detects all configured VPN connections on your system and allows you to connect or disconnect with a single click.

## Screenshots

<table>
<tr>
<td align="center">
<a href="Files/screen-1.png" target="_blank">
<img src="Files/screen-1.png" alt="Screenshot 1" width="300"/>
</a>
</td>
<td align="center">
<a href="Files/screen-2.png" target="_blank">
<img src="Files/screen-2.png" alt="Screenshot 2" width="300"/>
</a>
</td>
<td align="center">
<a href="Files/screen-3.png" target="_blank">
<img src="Files/screen-3.png" alt="Screenshot 3" width="300"/>
</a>
</td>
</tr>
</table>

*Click on an image to view full size*

## Key Features

- **VPN Status Indication** — the menu bar icon shows whether there's an active VPN connection
  - Semi-transparent gray icon when no connection is active
  - Colored shield icon when VPN is connected
- **Quick Toggle** — left-click the icon to toggle the active VPN connection
- **Global Hotkeys** — configurable keyboard shortcut to toggle VPN from any application
- **Notifications** — system notifications when VPN connects or disconnects
- **Convenient Menu** — right-click opens a menu with all available VPN connections
- **Visual Indicators** — each VPN in the menu displays a status icon (connected/disconnected)
- **Flexible Settings** — configure refresh interval, notifications, and display options
- **Multilingual** — supports English, Russian, and Chinese (Simplified)
- **Lightweight** — minimal system resource usage

## Installation

### Using Homebrew

Install VPN Bar via [Homebrew](https://brew.sh/):

```bash
brew tap borzov/vpn-bar https://github.com/borzov/vpn-bar
brew install --cask vpn-bar
```

By default, Homebrew installs apps to `~/Applications`. To install to `/Applications` instead:

```bash
brew install --cask --appdir="/Applications" vpn-bar
```

To update:
```bash
brew upgrade --cask vpn-bar
```

**Note:** The Cask applies `xattr -cr` automatically after installation, so extra steps are usually not needed for first launch. **Homebrew is the recommended installation method** to avoid manual quarantine removal.

If the app is still blocked or shows "damaged" after `brew install --cask vpn-bar`, run `sudo xattr -cr /Applications/VPNBarApp.app` (or `~/Applications/VPNBarApp.app`) and, if macOS shows a security message, go to **System Settings → Privacy & Security** and click **Open Anyway**.

### Manual Installation

1. Download the latest version from [Releases](https://github.com/borzov/vpn-bar/releases)
2. Extract the `VPNBarApp.zip` archive
3. Drag `VPNBarApp.app` to your Applications folder
4. Launch the application from Applications

**Note:** The technical name remains `VPNBarApp.app`, but it displays as "VPN Bar" in the system.

**Note:** On first launch, macOS may request permission to access the network extension. Allow access for the app to work correctly.

**Note:** If macOS shows a security warning, open **System Settings** → **Privacy & Security** and click **Open Anyway** next to the message about the app.

### App doesn't start or no process appears

If the app does not start and no process appears in Activity Monitor, try the following.

#### Installation via Homebrew (recommended)

The Cask applies `xattr -cr` after installation. If the app still does not start:

- Check for quarantine: `xattr -l /Applications/VPNBarApp.app` (or `~/Applications/VPNBarApp.app`). If `com.apple.quarantine` is present, run: `sudo xattr -cr /Applications/VPNBarApp.app`
- Open **System Settings → Privacy & Security** and, if there is a message about a blocked app, click **Open Anyway**

#### Manual installation from ZIP

Before the **first** launch, run:

```bash
sudo xattr -cr /Applications/VPNBarApp.app
```

If macOS still blocks the app, open **System Settings → Privacy & Security** and click **Open Anyway**.

#### Running from Terminal for diagnosis

If the process still does not appear:

```bash
/Applications/VPNBarApp.app/Contents/MacOS/VPNBarApp
```

Watch stderr. Alternatively: `open /Applications/VPNBarApp.app` and, if it crashes, check **Console.app** or run:

```bash
log show --predicate 'processImagePath contains "VPNBar"' --last 5m
```

#### Requirements

- macOS 12.0 (Monterey) or later. On Intel Macs, a universal (x86_64) build is required; recent releases provide it.

#### App runs but nothing is visible

This app is **menu bar only**: there is no window and no Dock icon. Look for the icon on the **right side of the menu bar** (near the clock, Wi‑Fi, battery).

## Usage

### Basic Actions

- **Left-click the icon** — toggles the active VPN connection (or the first available if none are active)
- **Right-click the icon** — opens the menu with VPN connections list
- **Click a VPN in the menu** — connects or disconnects the selected VPN
- **Hotkey** — configurable keyboard shortcut to toggle VPN from any application

### Settings

Open the menu and select "Settings" to access app preferences:

#### General
- **Status Update Interval** — configure how often the app checks VPN connection status (recommended: 10-15 seconds)
- **Notifications** — enable/disable system notifications when VPN connects or disconnects
- **Display** — show connection name in tooltip when hovering over the icon
- **Launch at Login** — automatically start the app at system login (macOS 13+)

#### Hotkeys
- **Toggle VPN** — set a global hotkey for quick VPN toggling
- Enhanced shortcut recording interface with visual modifier display and validation

#### About
- App information, version, and author
- Brief functionality description
- Direct link to the GitHub repository

## System Requirements

- macOS 12.0 (Monterey) or later
- Configured VPN connections in the system

## Auto-Start

To automatically launch the app at login:

1. Open **System Settings**
2. Go to **Users & Groups**
3. Select the **Login Items** tab
4. Click the **+** button and add `VPNBarApp.app` (displays as "VPN Bar")

## Development

The application is built with Swift and follows Apple's guidelines for native macOS app development.

### Building from Source

```bash
swift build -c release
./Scripts/package_app.sh
```

### Creating a Release

Releases are created automatically when pushing a tag in the `v*` format (e.g., `v0.6.0`):

```bash
# After finishing work on a version
git tag v0.6.0
git push origin v0.6.0
```

GitHub Actions will automatically:
- Build the application
- Create the .app bundle
- Package it into a ZIP archive
- Create a GitHub Release with the attached archive
