# Firebase and Android verification

Last checked: **3 November 2026**. Repository baseline: `main` at `3f0f0fe`, with local Android network, signing, and Google sign-in setup.

## Current state

| Component | Evidence / status |
| --- | --- |
| Android app | Version `1.0.0`, build `3`, installed and running on a physical Android 16 phone. |
| Firebase project | `machalert`; Android package `com.example.mach_alert`. |
| Firebase Core | Initialized in `lib/main.dart` with `DefaultFirebaseOptions.currentPlatform`. |
| Authentication | Email/password and Google sign-in implemented; a real signed-in session reached the dashboard and survived the app update. |
| Cloud Firestore | Services implemented; machine data rendered on the physical phone. This is not a complete live validation of every write workflow. |
| Cloud Storage | Upload code implemented, but cloud uploads are blocked by missing backend setup. See below. |
| Other platforms | `firebase_options.dart` currently supports Android only. Other platform folders do not establish working Firebase support. |

## Confirmed cause of the report-photo error

The phone logged `object-not-found`, HTTP `404`, and “The server has terminated the upload session” while uploading a report image. `StorageServiceException` maps that response to “The requested storage file was not found.”

Read-only project checks on 3 November 2026 found:

- The configured bucket, `machalert.firebasestorage.app`, does **not** exist: the Cloud Storage bucket lookup returned HTTP `404`.
- Listing this project's buckets returned an empty list.
- The Firebase Storage API returned HTTP `403` with a message that it has not been used or is disabled.
- Cloud Billing reported `billingEnabled: false`.

This is a missing cloud storage setup, not evidence that the selected photo disappeared from the phone. The app uploads a selected photo **before** calling `FaultService.addFault()`. If that upload fails, that submission does not save the report. Removing the optional image bypasses Storage and lets the form attempt the normal Firestore report write.

The same missing bucket also blocks maintenance proof-image uploads. An App Check placeholder-token warning appears in the phone logs, but the confirmed upload failure is the missing bucket; do not disable access controls to address it.

## Completing cloud photo setup

1. Open [MachAlert Storage](https://console.firebase.google.com/project/machalert/storage). The project owner must approve and configure billing before provisioning Cloud Storage. Firebase requires the **Blaze** plan for this service; see the [official bucket and billing requirements](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024).
2. Complete Storage setup, select the intended bucket location, and verify the bucket's actual name. Match it in `lib/firebase_options.dart` and the downloaded `android/app/google-services.json`; a configured bucket name alone does not create the bucket.
3. Review and deploy this repository's `storage.rules`, including the Firestore cross-service permissions required by the role lookups. Do not replace them with public read/write rules.
4. If app configuration changed, rebuild and update the phone using the same signing key.
5. Test an operator report with an image, confirm the Firestore record and image URL, then test a technician's maintenance proof separately.

Billing and bucket provisioning have **not** been changed as part of this verification.

## Cloud and emulator modes

- Debug defaults route Firestore to `10.0.2.2:8080` and Storage to `10.0.2.2:9199` on Android. This address is for an Android Virtual Device, not a physical phone.
- For a physical phone, use `flutter run -d <device-id> --dart-define=USE_FIREBASE_EMULATOR=false`.
- Release builds select cloud mode by default. The installed build also supplied `USE_FIREBASE_EMULATOR=false` explicitly.
- `firebase.json` configures Firestore and Storage emulators only. Authentication still uses the configured cloud project; the current interactive demo is not completely offline.

## Build and verification record

The verified local toolchain was Flutter `3.47.6`, Dart `3.13.5`, Gradle `9.3.1`, AGP `9.1.0`, Kotlin `2.4.0`, and Android Studio's JDK `25.0.3`. The APK declares minimum Android API `24` and target API `36`.

```bash
flutter pub get
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter build apk --release --no-pub --dart-define=USE_FIREBASE_EMULATOR=false --build-number=3
```

- Analysis: no issues found.
- Flutter test runner: **817 passed, 3 skipped**. No Firebase emulators were running for this run. Some security tests return early when emulators are unavailable, so the passing count does not establish that cloud uploads or security rules were exercised. See [the test plan](END_TO_END_TEST_PLAN.md).
- Release APK: built, installed as an update, and checked running with the signed-in session and machine data intact.
- Initial build 2 had stale generated Android plugin registration after an interrupted Windows dependency setup. A successful `flutter pub get --offline` regenerated the missing JNI and Shared Preferences registrations; build 3 passed the device startup check.

## Signing and Google sign-in

Release builds require ignored `android/key.properties`. This local assignment installation uses the existing development key so updates retain app data; it is not a Play Store signing setup. Keep private signing files out of Git.

This build's SHA-1 (`B7:92:4A:3F:67:37:EC:1F:C8:92:77:AA:D3:9C:1C:11:08:A7:6F:79`) was added to the existing Firebase Android app, and `google-services.json` was refreshed. Other computers or upload keys need their own registered fingerprint. See [Firebase's Google sign-in setup](https://firebase.google.com/docs/auth/android/google-signin).

The main Android manifest declares Internet permission for release builds and the launcher label is **MachAlert**.

## Demo identities

Keep the three showcase identities and credentials in [the demo guide](DEMO_GUIDE.md). Read-only Firebase Authentication lookups on 3 November 2026 found no accounts for `operator@machalert.test`, `technician@machalert.test`, or `manager@machalert.test` in `machalert`. Their setup status must therefore be shown as **not provisioned**, not pre-seeded. No accounts or passwords were changed during this audit.
