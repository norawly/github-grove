# Architecture

Grove uses Swift, AppKit, Foundation and ServiceManagement. The source has no package dependencies. Minimum deployment target: macOS 13.

`GroveCore` validates usernames, requests GitHub's public HTML calendar, parses its dated contribution cells, validates contiguous dates and levels, computes UTC streaks, and maps dates to Sunday-first week columns. It accepts both current table markup and older rect markup without relying on attribute order, tooltip contents, or CSS names.

`CalendarView` draws the card and every cell using AppKit paths and system fonts. One view keeps the drawing tree small. VoiceOver can read individual dates and activity levels. The same view renders the preview PNGs in a bitmap context without creating a window.

`AppController` owns one non-key, borderless desktop window. Its level is one above the desktop-icon level and below the normal-window level. The widget is stationary, joins desktop Spaces, and is excluded from window cycling. These flags require desktop testing with Stage Manager and Show Desktop on supported macOS versions; compilation does not prove those interactions.

`SettingsController` owns a normal native settings window. First launch shows setup. Subsequent launches reopen settings. `LSUIElement` and the accessory activation policy omit Dock and menu-bar icons. Start at login is explicitly opted into via `SMAppService.mainApp`.

The refresh timer runs hourly with ten minutes' scheduling tolerance. Waking only triggers a request if the snapshot is missing or older than an hour. Requests are also limited to once per minute. Fetches use a 30-second request timeout and 45-second resource timeout. One fetch is in flight at a time. Changing username cancels the old request and clears the old cache; cancelled responses cannot overwrite another user's calendar.

The optional animation timer runs at 1.5 seconds per frame with scheduling tolerance. It is removed while the widget is occluded, while screens sleep, or when Reduce Motion or Low Power Mode is enabled. Changes to the power and accessibility state are observed. The default is no animation. No web view, embedded browser, server, login helper executable or notification service is used.

Local JSON files are written atomically, with owner-only file permissions. On reading the cache, dates, levels, username and continuity are validated again. Public source and installers never include a cached personal calendar or user settings.

The universal build links a static core separately for arm64 and x86_64, merges the executables with lipo, strips debug symbols, bundles the icon and Info.plist, and applies an ad-hoc signature. GitHub Actions repeats the tests and build on macOS. Developer ID signing and notarization require the distributor's Apple credentials and are not part of the community preview.
