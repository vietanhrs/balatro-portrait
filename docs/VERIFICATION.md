# Verification — v0.2.0-alpha, 2026-11-17

Parent screenshot review accepted the redesign on 2026-11-17; source publication approved. A new APK prerelease is not published.

Godot 4.7.2 Compatibility, Linux desktop: 1793 core checks and 483 v2 checks, zero failures. Save suite 12 checks; real v1 migration 14 checks; legacy three-offer compatibility 11 checks; recovery confirmation/archive UI 7 checks, all passed. UI smoke, transaction persistence and measured visual fixture suites passed. Updated legal Practice replay completes 179 UI actions/24 wins with seven fresh-instance disk resumes and separate real loss path; not a human playthrough.

Rendered 18 route/idle/selected/scoring/receipt/shop/pack/detail/targeting images at 360×640 and 430×932 were inspected. Tested visible controls meet 48×48 logical minimum and viewport bounds; eight-card table and primary actions do not scroll. Receipt/shop/pack captures include explicitly synthetic layout fixtures, not balance evidence. Tall screens intentionally have generous whitespace. Motion uses source highlights, not full physics choreography.

Android: new debug APK upgraded installed v0.1 on isolated AOSP API35 x86_64 emulator using install -r, same certificate, no data clear. VersionCode2/name0.2.0-alpha, ARM64+x86_64, minAPI24/targetAPI36, portrait, no Internet permission; Godot notices bundled, tests/tools/private screenshots absent. Real v1 installed shop resumed; original archive SHA256 equals original installed save.

Native injected-touch seed531: selected/played high card then three jacks, won Small at196/150; cashout $5 ($4→$9); opened Tarot pack $4; force-stop restored exact options/checkpoint; targeting cancelled with Back without save mutation; Chip Etching applied +20 to c1_3; Big cleared using two pair and straight; cashout left $12; bought Side Pocket $10, capacity3, preserved after background and force-stop/resume. Separate fresh run discarded one card (3→2). Back closes overlay and opens menu without quitting. Offline Wi-Fi/data disabled. No script errors or AndroidRuntime crashes in final log.

Receipt, pack and purchased-voucher saves had byte-identical hashes across force-stop/relaunch. Native 720×1280 and tall860×1864 captures inspected; exact requested logical dimensions are covered by desktop renders. Physical ARM64/notches/broad Android versions remain untested. Two native rounds are not a full Android run.

Balance: core author supplied honest greedy seeds1–5 Practice4/5 wins and seeds1–3 Standard0/3. Standard is prominently experimental; no balance certification.
