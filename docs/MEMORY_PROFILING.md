# Memory profiling (soak testing)

Recommended when investigating exits after prolonged use or suspected OOM (out-of-memory kills).

## When to profile

- App closes after minutes of foreground use without a clear Dart crash.
- Android logcat shows **lowmemorykiller**, **KILL**, **LOW_MEMORY**.
- iOS shows **Jetsam** / memory pressure Termination Reason.

## Steps (Flutter DevTools)

1. Run the app on a real device (preferred) or emulator.

   ```bash
   flutter run -d <deviceId>
   ```

2. Start DevTools (VS Code/Android Studio Flutter plugin, or command line):

   ```bash
   dart devtools
   ```

3. Open the **Memory** page for your isolate (`main.dart` isolate).

4. Follow a **repeatable soak script** (example):

   - Cold start → log in → home tab idle **5 min**
   - Open trip detail with map → back
   - Marketplace list → scroll → open one vehicle post → back
   - Notifications screen → back
   - Repeat or leave on home **additional 10+ minutes**

5. Record:

   - Dart heap at T+0, T+5min, T+15min  
   - Any large spike when opening/closing maps or chat  

6. If RSS grows outside Dart heap, suspect **Google Maps**, **decoded images**, or **large in-memory collections** — align with fixes (caps, eviction, paging).

## Low-RAM regression

Repeat the same script on an **Android API 34+ emulator with 2048 MiB RAM** and monitor for Earlier termination vs a high-memory device.
