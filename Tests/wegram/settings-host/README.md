# Settings touch fixture

This test-only app embeds the production `WegramDarkModeContentView` source to check real UIKit touch delivery inside its scroll view. It has no account context, API configuration, preference writes or network requests. Its mode and event counter are fixture state, not proof that production settings persist or that the real controller responds to system appearance changes.

The content uses the shared production `Display.WegramAppearanceSwitch`. The fixture links Display and uses the same iOS 15 deployment floor as the app; it observes appearance changes with the modern API on iOS 17+ and a compatibility callback below that. Collect fresh observations after control changes: rebuilding or checking old recordings is not a new gesture run.

Build with the local simulator configuration already generated:

```bash
build-input/bazel-9.2.0-darwin-arm64 build //Tests/wegram/settings-host:WegramSettingsTestHost --ios_multi_cpus=sim_arm64 --define=buildNumber=10000 -c dbg --disk_cache=$HOME/Library/Caches/wegram-bazel
```

Install the simulator app extracted from the target IPA on the dedicated Wegram QA simulator only. Do not use a personal account or the other project's simulator. Follow the sim-use observe → act → verify loop. Record full JSON observations for the fixture status and production control identifiers; keep screenshots and extracted bundles in ignored `build-input`.

Check ordinary light/dark row taps, following-system switch taps, horizontal drags in both directions, an out-of-bounds release, and taps while locked. A committed value change should emit one event; an out-of-bounds release or disabled control should emit none. The fixture's Lock / Unlock button changes only whether the production content accepts input.

After testing, stop the fixture and foreground the existing production app without submitting any authentication request. Actual account preferences, persistence, full navigation, accessibility service behavior and same-size WeChat screenshot comparison require separate validation.


Recorded observations can be checked with:

```bash
python3 Tests/wegram/settings-host/check_touch_evidence.py build-input
```

The verifier checks 17 saved `sim-use ui --json --no-raw` observations. It does not inject gestures and is not an account test. The `touch` series records initial light, dark row tap, switch on/off taps, drag on, out-of-bounds release, drag off, lock, disabled switch tap and disabled dark-row tap. The `fixed` series records a fresh launch, lock, disabled dark-row tap, disabled switch tap, unlock, dark-row tap and light-row tap. It requires the real fixture bundle, exact event counts/modes, switch values/geometry, hidden manual rows in system mode, and all disabled AX traits after the fix.
