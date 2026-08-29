# Development and release guide

## Requirements

- macOS and Xcode with the iOS 17 SDK or later.
- Swift 5 language mode as configured by the project.
- iOS 17 or later deployment target.
- Physical iPhone for Bluetooth/AirPods routing tests.
- Stereo AirPods for the bilateral pure-tone workflow.

No third-party Swift package is required.

## Open and build

1. Open `SNRLab.xcodeproj` in Xcode.
2. Select the **SNRLab** target.
3. In **Signing & Capabilities**, enable automatic signing and select a team.
4. Replace the development bundle ID `com.example.SNRLab` with a unique ID.
5. Select a simulator for UI-only work or a physical iPhone for audio-route work.
6. Build with **Product → Build** or run with **Product → Run**.

A free Personal Team can install a development build on the owner's devices.
App Store distribution requires Apple Developer Program membership.

## Command-line source check

The source can be type-checked without changing the Xcode project:

```bash
mkdir -p /tmp/snrlab-swift-module-cache /tmp/snrlab-clang-module-cache
env \
  SWIFT_MODULECACHE_PATH=/tmp/snrlab-swift-module-cache \
  CLANG_MODULE_CACHE_PATH=/tmp/snrlab-clang-module-cache \
  xcrun --sdk iphoneos swiftc \
    -typecheck \
    -target arm64-apple-ios17.0 \
    -module-name SNRLab \
    -parse-as-library \
    -module-cache-path /tmp/snrlab-swift-module-cache \
    $(find SNRLab -name '*.swift' -print | sort)
```

An empty successful output means type-checking completed. This is not a substitute
for an Xcode build, asset processing, code signing, or device tests.

## Test configurations

### Simulator

Appropriate for layout, navigation, persistence, charts, language text, and much
of the numerical logic. Do not use it as evidence for AirPods routing, microphone
behavior, output amplitude, or physical-device timing.

### Physical iPhone without AirPods

Appropriate for microphone and general audio tests. The bilateral pure-tone setup
should remain gated because it requires an AirPods-named stereo route.

### Physical iPhone with AirPods

Required for the intended end-to-end screening workflow. Verify:

- route name and channel count;
- audible left/right channel assignment;
- interruptions, reconnect, and route-change pause;
- practice and randomized trials;
- results persistence after relaunch;
- independent left/right Personalized Audio filters.

Do not conduct acoustic safety or calibration tests by subjective listening alone.

## Coding conventions

- Keep shared domain values in `Models.swift`, not view-local dictionaries.
- Persist raw trials before adding new summary-only metrics.
- Keep pure-tone and speech-in-noise units separate.
- Include the unit/reference in every public label.
- Any clinical-looking visualization must preserve the uncalibrated warning.
- Route all session changes through `AudioSessionManager`.
- Keep channel-specific processing explicit; never average ears unless a metric is
  explicitly defined as an average.
- Mark unvalidated constants as heuristics in code and documentation.
- Add backward-compatible decoding or a migration when stored models change.

## Adding a test

1. Define Codable input/trial/result models.
2. Implement numerical logic separately from SwiftUI where possible.
3. Add a workflow view with clear setup, progress, interruption, and completion
   states.
4. Save both raw observations and derived summaries through `AppModel`.
5. Add result/history rendering.
6. Document units, reference, assumptions, stopping rules, and uncertainty.
7. Add deterministic unit tests and device tests.

## Changing the audio graph

When adding or reconnecting AVAudio nodes:

- stop the engine first;
- preserve channel formats and sample rates;
- inspect headroom after summing or boosting;
- verify bypass and comparison paths share intended gain;
- test route changes and interruptions;
- render offline measurements where possible;
- retest on physical hardware.

Apple describes `AVAudioEngine` as a real-time graph of attached audio nodes:
[AVAudioEngine documentation](https://developer.apple.com/documentation/avfaudio/avaudioengine).

## Release configuration checklist

The checked-in project remains a development MVP. Before App Store upload:

- [ ] Active Apple Developer Program organization or individual team.
- [ ] Permanent unique bundle identifier.
- [ ] Marketing version 1.0 and monotonically increasing build number.
- [ ] Distribution certificate/profile managed by Xcode.
- [ ] Final display name and App Store name availability.
- [ ] Final app icon and launch experience.
- [ ] Public privacy-policy URL and in-app privacy link.
- [ ] Public support URL/contact method.
- [ ] Accurate App Privacy answers based on the release binary.
- [ ] Health/measurement methodology and limitation notes for review.
- [ ] Screenshots for required devices and localizations.
- [ ] English and Spanish metadata reviewed by fluent speakers.
- [ ] Age rating, category, territories, price, copyright, and content rights.
- [ ] Music source/license evidence retained.
- [ ] Microphone permission copy reviewed.
- [ ] Accessibility and Dynamic Type pass.
- [ ] Automated tests and supported-device matrix pass.
- [ ] Archive validation and TestFlight external test.
- [ ] Legal, product-liability, privacy, and regulatory review appropriate to the
  intended claims and regions.

Apple requires an App Store Connect app record before uploading a build. The
record includes the name, primary language, bundle ID, and SKU:
[App Store Connect app-record instructions](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app).

## Version-control hygiene

The repository includes `.gitignore` rules for Xcode user state, DerivedData,
archives, exported apps, macOS metadata, and temporary audio. Do not commit:

- personal Apple Account information;
- provisioning profiles or private keys;
- device identifiers unless explicitly required and protected;
- test records containing identifiable user names;
- derived build artifacts.

## Licensing

Application code and documentation are currently all rights reserved; see
[`../COPYRIGHT.md`](../COPYRIGHT.md). A public GitHub repository is not
automatically open source. Add an explicit open-source license only after the
copyright owner chooses its terms.

Bundled music has separate CC0/public-domain notes in
[`../SNRLab/Resources/DemoMusic/LICENSE.md`](../SNRLab/Resources/DemoMusic/LICENSE.md).
