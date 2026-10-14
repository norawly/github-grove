# Architecture

Swift, AppKit, Foundation, WidgetKit and SwiftUI, without third-party dependencies.

GroveCore validates usernames, parses GitHub's dated HTML cells, validates calendar continuity, computes UTC streaks, maps the entire year to week columns, defines GitHub colour palettes and snaps desktop-card positions to complete display-local slots.

CalendarView is one native drawing view. It renders only the username, streak and calendar. No continuous rendering or mascot timer exists. Tooltip strings remain retained by the live view: passing temporary NSString owners was the cause of the 0.1.0 hover crash. The same view renders preview PNGs without showing windows.

AppController owns a non-key, borderless window above the wallpaper/desktop-icon layer and below ordinary windows. It joins desktop Spaces and is excluded from window cycling. Drag release snaps to slots anchored at the visible display's top left. An AppKit animation context moves the window in 0.25 seconds using ease-out; Reduce Motion disables the transition. Position is saved after the transition ends.

SettingsController handles username, appearance, size, card visibility, snapping, locking and optional macOS login startup. LSUIElement and the accessory activation policy omit Dock and menu-bar icons.

The desktop card refreshes hourly with scheduling tolerance, requests after wake only when data is old, and limits manual refresh to once per minute. A changed username cancels the old fetch and clears its cache. JSON data is written atomically with owner-only permissions. Saved-data timestamps and errors are available through tooltips rather than persistent calendar labels.

GroveWidget is a separate sandboxed WidgetKit extension with an hourly timeline, the same public graph client, a private offline cache and scoped read-only access to Grove's settings folder. This component is compiled separately and must be signed with an Apple-issued identity before native-gallery operation can be validated. The ad-hoc gallery rejection observed on the development Mac is documented in native-widget.md.

Universal app builds compile arm64 and x86_64, merge with lipo, strip debug symbols and bundle the icon/Info.plist. The normal community package excludes the native extension. INCLUDE_WIDGET=1 embeds it before final packaging, signing the extension before the containing app. Signing credentials and local diagnostics are never included in source or installers.
