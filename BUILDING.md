# Build and test

Use Godot **4.7.2 stable**, matching export templates, and preferably OpenJDK 17. The Compatibility renderer is selected. The logical canvas is 360×640 with EXPAND aspect, portrait.

```sh
GODOT=/path/to/godot-4.7.2 tools/run-checks.sh
```

The check wrapper isolates HOME and XDG directories so destructive save recovery tests cannot touch your ordinary game save. It imports the project and executes save roundtrip, validation, corruption recovery, and deterministic continuation tests. It also runs core rules, UI layout, and full-run UI persistence replay suites.

## Android
Follow the official [Godot Android export guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html). Obtain the Android SDK only from Google and JDK only from its vendor; pin download versions and verify vendor checksums. Review and accept applicable licenses yourself before SDK installation. Never blindly pipe `yes` into legal prompts.

The prebuilt APK route uses platform-tools, build-tools 35.0.1 and platform android-35. Godot's full documented setup also includes NDK 28.1.13356709 and CMake 3.10.2.4988404; these may be required by custom/Gradle exports. Configure `export/android/android_sdk_path` and `export/android/java_sdk_path` in a dedicated Godot editor configuration. With isolated XDG_DATA_HOME, provide matching templates in `godot/export_templates/4.7.2.stable/`. Keep SDK, JDK, AVDs, credentials, signing keys, and APK outputs outside version control.

```sh
mkdir -p build
godot --headless --path . --export-debug Android build/velvet-circuit-debug.apk
apksigner verify --verbose build/velvet-circuit-debug.apk
aapt dump badging build/velvet-circuit-debug.apk
sha256sum build/velvet-circuit-debug.apk
```

Preset package: `org.vietanhrs.velvetcircuit`; ARM64 and x86_64, debug signing, no Internet permission. Debug signing is for development, not a stable production identity. No Play Store publication is configured.

Use a newly created isolated x86_64 emulator only, targeting its explicit `adb -s emulator-PORT` serial. Test launch, card selection, play/discard, shop, Android Back, background/resume, force-stop/relaunch, offline operation, and logcat crash absence. Do not install on physical devices without separate permission. Record actual commands and results; desktop tests do not prove Android behavior.
