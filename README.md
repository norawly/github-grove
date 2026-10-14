# Grove

Your GitHub calendar, quietly on your Mac desktop.

Grove is a small native macOS app that puts your full contribution calendar in a calm card on your desktop. No Dock icon, no menu-bar icon, no browser engine. Just your green squares, a muted username, and a small current streak.

![Grove dark appearance](docs/preview-dark.png)

*The image above is an illustrative calendar rendered by the app itself. Demo activity is not a real person's contribution history.*

## Download & install

**macOS Ventura 13 or newer · Apple Silicon and Intel**

1. Download `Grove-0.1.0-universal.dmg` from [Releases](https://github.com/norawly/github-grove/releases).
2. Open the disk image and drag **Grove** into **Applications**.
3. Open Grove, enter your GitHub username, and choose **Save & show calendar**.
4. Drag the card to your favourite corner. Right-click it for settings.

There is also a ZIP containing the same app. You don't need a terminal, a separate Grove account, a GitHub token, or to give Grove access to your repositories.

**Community build:** the download is ad-hoc signed, not signed with an Apple Developer ID or notarized. macOS may block its first launch. After attempting to open it, use **System Settings → Privacy & Security → Open Anyway**, if offered. See [Apple's instructions](https://support.apple.com/en-us/102445). Managed Macs may prohibit this. You can also build the public source yourself.

This is an initial preview. See [verification status](docs/verification.md) for what has been tested and what still needs a desktop session.

## A quiet desktop companion

- The complete rolling calendar, including all available weeks, with month labels and Mon / Wed / Fri markers.
- Muted username and current streak, with no totals or extra dashboards.
- Soft dark, warm light, or automatic appearance. Four sizes, starting at 680 × 272 points.
- Drag to move, lock position, and reset to the top-left corner. The last position and selected display are remembered.
- Lives above wallpaper and desktop icons, below ordinary app windows. Desktop icons can be moved away from its footprint. It stays on desktop Spaces and is excluded from window cycling.
- One refresh per hour, a saved calendar offline, and refresh after wake when data is old.
- Optional slow pixel sprout. Off by default; pauses when occluded, asleep, in Low Power Mode, or when Reduce Motion is enabled.
- Optional **Start Grove when I log in**, using macOS Login Items. No installation scripts or background services are added automatically.

![Grove light appearance](docs/preview-light.png)

## Controls

| Action | How |
| --- | --- |
| Move the card | Drag anywhere on the card |
| Open settings | Double-click the card, right-click → Settings, or open Grove again |
| Refresh | Right-click → Refresh calendar (limited to once per minute) |
| Change appearance or size | Right-click → Appearance / Size |
| Keep the card in place | Right-click → Lock position |
| Enable the sprout | Right-click → Pixel companion |
| View a date's activity level | Hover a square, or use VoiceOver |
| Open your profile | Right-click → Open GitHub profile |
| Quit | Right-click → Quit Grove, or use the button in Settings |

If you close the settings window, the widget continues running. There is deliberately no tray or Dock control; reopening Grove takes you back to settings.

## What the calendar and streak mean

Grove reads the same **public contribution graph** that a signed-out visitor sees on your GitHub profile. GitHub counts contributions such as commits, pull requests, issues, and reviews; this is not a commit-only counter. Private activity appears only when you choose to show anonymized private contributions on your GitHub profile. [GitHub explains contribution visibility and timestamps here](https://docs.github.com/en/account-and-profile/concepts/contributions-on-your-profile).

The streak counts consecutive days with activity in the fetched graph, in **UTC**, matching GitHub. If today has no activity yet, yesterday's streak remains until the day ends. A streak reaching the beginning of the rolling graph is displayed with `+`, since earlier days are unknown. On an old offline snapshot the streak can fall to zero because current activity is unknown; the saved date and offline state remain visible.

GitHub serves the calendar as an HTML fragment, rather than a documented public calendar API. The parser checks that dates and levels form a valid calendar. If GitHub changes its markup or cannot be reached, Grove shows an error and keeps the last successful calendar instead of inventing activity. GitHub's own contribution updates may be delayed.

## Privacy & resources

Grove contacts `https://github.com/users/<username>/contributions` over HTTPS. It uses a fresh session with no cookies, no authentication, and no third-party relay. Opening your profile uses your default browser only when you request it. There are no analytics, ads, telemetry, auto-update checks, or repository permissions.

Your username, preferences and last calendar are kept in `~/Library/Application Support/Grove/`. Changing username clears the previous calendar. To uninstall, disable Start at login, quit Grove, remove Grove.app and optionally this folder.

The UI is one AppKit drawing view. With the companion disabled, there is no animation timer or continuous redraw loop. The optional companion draws one frame every 1.5 seconds. Refresh timers stop during sleep. Actual CPU, memory and battery measurements are pending runtime validation; "zero impact" is not claimed.

## Build from source

Install Apple's Command Line Tools (`xcode-select --install`) or Xcode. No third-party package dependencies are needed.

```sh
git clone https://github.com/norawly/github-grove.git
cd github-grove
bash scripts/test.sh
bash scripts/build.sh --package
```

The build script creates a universal `dist/Grove.app`, a DMG, a ZIP and SHA-256 checksums. It does not install or launch the app. Set `SIGNING_IDENTITY` to your own Developer ID identity to sign your own build; notarization is a separate distribution step.

The included Swift package is useful for development:

```sh
swift run GroveChecks
swift build -c release --product Grove
```

Headless commands work without showing windows or writing app preferences:

```sh
dist/Grove.app/Contents/MacOS/Grove --fetch octocat
dist/Grove.app/Contents/MacOS/Grove --render preview.png --theme dark
```

The second command uses explicitly fictional demo data. Add `--html FILE --username NAME` to render a previously downloaded public calendar. See [architecture](docs/architecture.md) and [verification](docs/verification.md).

## License

[MIT](LICENSE). Grove is an independent community project, unaffiliated with GitHub or Apple. Its optional pixel sprout and app icon are original artwork drawn in code.
