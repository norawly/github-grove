# Verification status

## Automated

13 check groups pass: username validation; unordered table/SVG parsing; quote variants; error pages; missing/duplicate/invalid dates and levels; UTC leap days; today/yesterday streaks and lower bounds; full-year layout including a 54th column; cache round trips; grid anchoring/idempotence; and bounds on smaller or secondary displays.

Universal desktop-card and WidgetKit-extension compilation, ad-hoc signature verification and native AppKit PNG rendering pass locally. Native PluginKit registration passed, but the macOS 27 widget-gallery descriptor check rejected the ad-hoc extension. See native-widget.md.

GitHub Actions separately repeats the source scan, checks, installer build and optional native-extension compilation.

## Desktop session, 14 October 2026

- Installed Grove in Applications; entered the GitHub username and loaded the real public calendar.
- Reproduced a 0.1.0 crash on hover, identified the tooltip-owner lifetime error from its stack, and changed tooltip ownership to the retained view.
- Installed the compact 0.2.0 design and inspected the actual window using macOS accessibility and screenshots.
- Confirmed initial top-left position and saved preferences.
- The user manually confirmed that drag release snaps to the grid, then requested a smoother transition. The final implementation adds a 0.25-second AppKit ease-out transition, without a spring.
- During an idle sample of the compact version, the process used approximately 40 MB resident memory and reported 0.0% CPU. This is a sample, not a battery benchmark.

## Remaining checks

- User confirmation of the final smoother snap transition.
- Login registration and successful launch after a real login.
- Sleep/wake, display reconnect, Stage Manager and fullscreen interactions.
- Battery measurements over a longer session.
- Runtime on Intel and macOS 13; cross-compilation alone does not prove those platforms.
- Native-widget gallery, configuration and timeline behavior after an Apple-issued signature is available.

The UI automation tool can inspect the desktop-level card, but cannot route pointer actions to its non-key desktop window; direct drag/hover confirmation comes from the user. Automated tests are distinguished from those manual checks.
