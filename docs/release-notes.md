Grove 0.2.0 replaces the original card with a compact GitHub-coloured calendar: only the muted username, streak and complete graph remain.

Removed mascot/animation loop, icon, separator, month/day labels, legend, timestamps and status footer. The default card is 624 × 126 points. Drag release settles into a desktop grid slot with a short 0.25-second ease-out transition; Reduce Motion disables it. Fixed the tooltip-owner lifetime crash on hover.

The universal DMG/ZIP provides the desktop card for macOS 13+. It is ad-hoc signed, not Apple-notarized.

A real WidgetKit extension is included in the source and compiles. On the development Mac, macOS rejects its ad-hoc signature for gallery use; an Apple-issued identity is still needed. The community download must not be described as an installed native WidgetKit widget.

13 automated check groups pass. The compact design, real calendar and initial top-left placement were inspected on the desktop; the user confirmed grid snapping. Login, battery, Intel runtime and signed native-widget operation remain unverified.

Source: https://github.com/norawly/github-grove
