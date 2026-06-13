# Crash and exit diagnostics (Portivo Transporter)

Use this runbook when the app appears to crash, close unexpectedly, or stop after sitting idle (~5 minutes or any duration).

## 1. Fixed reproduction script

Record:

- Build: `flutter run` (debug), `flutter build apk --release`, or TestFlight/APK artifact.
- Flow: idle home vs trip detail (map visible) vs marketplace vs chat — **same sequence every time**.
- Foreground vs background; network (Wi‑Fi / cellular).

Note **wall-clock time** from launch to exit.

## 2. Android: logcat around exit

With the device USB-connected:

```bash
adb logcat -c
adb logcat *:W flutter:V AndroidRuntime:E ActivityManager:I libc:F *:S
```

Reproduce the issue, then capture:

- Lines containing **`FATAL EXCEPTION`**, **`AndroidRuntime`**, **`SIGSEGV`**, **`lowmemorykiller`**, **`LOW_MEMORY`**.
- **Memory kill**: Look for `lowmemorykiller`, `KILL`, `OOM`, `Exceeded memtrack`.

Save full buffer if needed:

```bash
adb logcat -d > logcat-export.txt
```

Tombstones (debuggable/device-dependent):

```bash
adb shell ls /data/tombstones
```

## 3. iOS: device logs

- Xcode → **Window → Devices and Simulators** → select device → **Open Console**.
- Filter for **JetsamEvent**, **`SIGKILL`**, **`terminated`**, process name (**Runner**).

Or Console.app streaming from the physical device.

## 4. Flutter verbose run

```bash
cd Portivo-Transporter-App
flutter run --verbose -d <deviceId>
```

Keep the terminal scrollback; save the **last ~200 lines** before the process disappears.

## 5. Classify the failure

| What you see | Likely category | Next step |
|--------------|-----------------|-----------|
| Dart stack / FlutterError | Dart / Flutter code | symbolicated stack → fix Dart |
| Tombstone native stack (libc, okhttp, GLES) | Native / plugin | Plugin version/OS |
| Jetsam / `memorystatus` kill | RAM pressure | Profile memory (below) |
| No crash log; app disappears in background only | Lifecycle / OEM | Battery / background restrictions |

## 6. Memory profiling (10+ minutes)

1. Run: `dart run dart_devtools` or `flutter pub global run devtools` (or Flutter attach → DevTools).
2. Connect to the running app (**Memory** tab).
3. Run the **same reproduction flow** as log capture for **≥10 minutes**.
4. Watch **RSS** / process memory and Dart heap; screenshot if growth is steep.

Interpretation:

- Steady heap + rising RSS → natives (maps, graphics, caches).
- Dart heap climbs → leaked listeners, undisposed subscriptions, cached lists/images.

---

## Automated crash reporting

Third-party crash reporting is not bundled in this app. Use platform logs, Flutter/Dart DevTools, and your own backend or analytics if you need production crash telemetry.
