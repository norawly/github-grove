# Native WidgetKit status

Grove's native extension is in Sources/GroveWidget/. It builds for arm64 and x86_64 with a macOS 14 deployment target, uses WidgetKit and SwiftUI, and has sandbox and outbound-network entitlements.

The extension reads only the containing app's Grove settings/calendar folder, using a scoped read-only sandbox exception. It has no App Groups, authentication, tokens or access to unrelated files. Its own timeline requests the public GitHub graph, preserving an extension-local cache on failures. The containing app can request a timeline reload after configuration changes.

## Local verification on 14 October 2026

- Compiled the actual extension and embedded it in Grove.app.
- Applied a sandboxed ad-hoc signature from the extension outward.
- Verified the containing app and extension signatures.
- LaunchServices registered the app; PluginKit listed dev.norawly.grove.widget.
- macOS 27's chronod then rejected the extension's descriptors: purging instead because we shouldn't cache it ... isApple? false.
- No Apple Development or Developer ID signing identities are installed.

Consequently, **native gallery availability is blocked by signing on this machine**. Successful compilation and PluginKit registration are not claimed as successful WidgetKit installation. No system security protections were changed and no unrelated widgets or system processes were reset.

The attempted ad-hoc extension was removed from the ordinary community installation after the check. Its source and build recipe remain ready for an Apple-issued identity.

## Signed build

~~~sh
SIGNING_IDENTITY="Apple Development: your identity" INCLUDE_WIDGET=1 bash scripts/build.sh
~~~

For public distribution, use a Developer ID identity, then notarize and staple using your own Apple developer credentials. Do not commit signing credentials or certificates.

After installation, launch Grove to save a username. Add Grove using macOS's Edit Widgets gallery. Uncheck Show desktop card in Grove settings to avoid a duplicate card. The medium family is supported by the extension; newer SDK builds also declare the extra-large family.

Still to verify after signing: gallery discovery, adding the native widget, shared configuration reads, timelines, offline recovery and native desktop placement.

Apple references: [Creating a widget extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension), [widget families](https://developer.apple.com/design/human-interface-guidelines/widgets), [Apple's explanation of signing identities](https://developer.apple.com/forums/thread/776087).
