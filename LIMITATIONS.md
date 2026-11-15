# Limitations and verification boundaries

- Prototype, not a full Balatro clone or official port; no complete content parity.
- Debug APK signature/portrait/ABI checks and API35 x86_64 emulator smoke passed. Physical ARM64 devices, notches and broad Android-version coverage remain untested. Emulator SwiftShader failed shader uniform limits; host Intel graphics worked.
- A legal seed-1 151-action replay completes all 24 rounds through the UI with autosave/resume checks. This is automated, not a manual human playthrough. Human balance and accessibility remain unverified.
- One local versioned run save; no cloud sync, migration from other games, or metaprogression. Backup may recover the previous successful action after corruption. SHA256 detects accidental corruption, not adversarial tampering.
- Temp-file write, flush, validated readback and same-directory rename protect normal interrupted writes. Godot does not provide an explicit directory fsync here; sudden storage/power failure durability is not guaranteed.
- Android safe areas and minimum touch sizes require device-size verification, not assumptions from a portrait viewport.
- Debug APKs are development builds, not Play Store-ready releases.
