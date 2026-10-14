# Verification status

This preview was prepared without installing, launching a desktop window, registering a login item, or changing the development machine's settings.

## Automated checks

The dependency-free test runner checks real behavior: username validation; calendar parsing independent of attribute order and row order; single and double quotes; table and SVG cells; failure on error pages; missing, duplicated or malformed dates; invalid activity levels; UTC leap days; today/yesterday streak behavior; streak gaps and lower bounds; full Sunday-first layout; retaining a 54th week when necessary; and cache round trips and validation.

Locally verified on 14 October 2026:

- All 11 check groups pass with zero failures.
- The real public GitHub calendar is fetched through the app's URLSession client and parses as 368 contiguous dates ending on 14 October 2026.
- The native AppKit view renders correctly offscreen in light and dark appearances; public screenshots use explicitly fictional demo data.
- Release compilation for arm64 and x86_64, merged into one universal app with a macOS 13 deployment target.
- The application bundle's ad-hoc signature and Info.plist validate.
- DMG integrity, ZIP contents and SHA-256 checksums validate.
- Source and release executable scans contain no personal filesystem paths or credentials. Local previews and build outputs are excluded from Git.

GitHub Actions repeats the source scan, checks and universal build. Its status is independent of the local verification above.

## Desktop session still required

- Fresh first launch, username save, refresh, error and offline recovery.
- No Dock/menu-bar icon, settings reopen, right-click menu, double-click, drag and lock.
- Placement on wallpaper below ordinary windows; Spaces, Show Desktop, fullscreen and Stage Manager.
- Light/dark switching, scaling, multiple displays and display disconnect/reconnect.
- Login-item registration, approval in System Settings, and successful launch after login.
- Sleep/wake, occlusion and Reduce Motion behavior.
- CPU, memory and energy use on a real idle desktop.
- VoiceOver date navigation and settings controls.
- Installation and runtime on Intel and macOS 13. Cross-compilation alone is not real-device proof.
- Gatekeeper behavior of the downloaded, ad-hoc signed community build.

Desktop testing was deliberately deferred so the user's active work would not be interrupted. These points must not be described as already runtime-verified.
