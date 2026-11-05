# E2E (Maestro, Android)

Black-box flows for the Firebase-backed modules (Inventory, Library), converted from
`docs/inventory-library-manual-test.md`. Each flow cites the guide step numbers it covers.

1. Stop the dev emulators, then `melos run e2e:emulators` (own data: `firebase/.emulator-data-e2e`;
   `melos run e2e:reset` wipes only that). The app hard-codes the emulator ports: one set at a time. Stop it with
   Ctrl-C so the data is exported; killing it loses the data.
2. Run the dev app on the Android emulator once (`icueadmin [Dev + Emulators · Android]`), logged in.
3. After an `e2e:reset`, run `e2e/scripts/reset-app-session.sh`.
4. `JAVA_HOME=<JDK 21> e2e/scripts/run-all.sh` runs the whole suite in one Maestro process, in the order set in
   `e2e/maestro/config.yaml`. One flow: `maestro --device emulator-5554 test e2e/maestro/inventory/units.yaml`.

Flows run in guide order on shared data; create steps are skipped when the record already exists.

## Speed (measured on the Pixel 10 Pro XL emulator, Android 17 preview image)

- One Maestro process for the suite: a fresh process costs ~11.5 s of driver start-up, so per-flow runs lose ~8 min.
- `run-all.sh` sets the emulator animation scales to 0 (`SKIP_ANIMATIONS=0` keeps them).
- A tap by label costs ~2.5 s (two hierarchy reads of ~1 s each); a tap by screen position ~1 s; a typed entry
  ~2 s; `back` ~0.7 s. Hierarchy reads are slow on this image (a bare `uiautomator dump` takes ~2 s even on the
  launcher), so fewer commands is the only lever left in Maestro.
- `when: notVisible: X` waits 5-7 s whenever X is on screen; avoid it in new guards where a `visible` check works.
- `waitToSettleTimeoutMs` and `retryTapIfNoChange` made no measurable difference.

## Integration tests (faster than Maestro)

`apps/icueadmin/integration_test/app_test.dart` runs the same guide steps inside the app (milliseconds per step; the
only slow part is the one-time ~30 s build). Run it with the e2e emulators up:

```bash
cd apps/icueadmin && flutter test integration_test/app_test.dart -d emulator-5554 --flavor dev \
  --dart-define=ENV=dev --dart-define=FIREBASE_EMULATOR=10.0.2.2 \
  --dart-define=TEST_PHONE=<mobile number> --dart-define=TEST_OTP=<otp>
```

`TEST_PHONE` and `TEST_OTP` are only used when the app opens on the login screen (no stored session); leave them out
once signed in. Each step prints PASS or FAIL and the run continues; the test fails at the end if any step failed.
