# MachAlert — test plan and verification record

Last updated: **3 November 2026**. Baseline: **main at 3f0f0fe**, Android installation **1.0.0, build 3**.

## Latest results and their limits

| Check | Observed result |
| --- | --- |
| flutter analyze --no-pub | No issues found. |
| flutter test --no-pub --reporter expanded | **817 passed, 3 skipped**, zero reported failures. |
| Release APK | Built successfully with cloud mode and build number 3. |
| Physical Android 16 phone | Update installed, app stayed running, signed-in session and machine data were visible. |
| Cloud photo upload | **Failed:** HTTP 404 / object-not-found; configured Storage bucket is absent. |
| Live emulator rule checks | **Not verified by this run:** Firestore and Storage emulators were not running. |

Several tests in the security-rule files execute an early return when the emulator is unavailable. Those entries can be reported as passing without evaluating a rule. Therefore, neither “817 passed” nor “3 skipped” measures the number of live security assertions executed. The former claim of “709 tests proving all cloud uploads and production rules” is not a current verification result.

## Test layers

| Layer | What it establishes |
| --- | --- |
| Unit/model/provider tests | Serialization, validation, state changes, machine-count reconciliation, and utilities. |
| Widget/screen tests | Layout, form behavior, navigation, splash/onboarding state, loading/error states, branding. |
| Service and multi-screen integration tests | App logic using FakeFirebaseFirestore, fake authentication, and injected StorageUploader implementations. |
| Emulator security tests | Firestore and Storage rule decisions only when the relevant live local emulators are reachable. |
| Physical-device checks | Native plugin startup, signing/update compatibility, real authentication and network behavior. |
| Cloud workflow checks | Actual uploads, Firestore writes, deployed permissions, and multi-role behavior; must be recorded separately. |

The tests under test/integration use the Flutter widget test harness and test doubles. They are not instrumented end-to-end tests against the installed APK or evidence that a real cloud bucket exists.

## Reproducible local checks

The current environment used Flutter **3.47.6**, Dart **3.13.5**, and Windows. pubspec.yaml requires Dart **^3.13.5**. Use a supported Java runtime for Gradle and the installed Firebase emulators; the Android build here used Android Studio's JDK **25.0.3**.

~~~bash
flutter pub get
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
~~~

Dependency setup must finish successfully. On Windows, resolve symlink/Developer Mode errors and regenerate plugin registration before using --no-pub. The first build after the latest pull had stale native registration; successful flutter pub get --offline corrected it.

Useful focused suites:

~~~bash
flutter test test/integration/app_e2e_test.dart
flutter test test/screens/splash_onboarding_flow_test.dart test/navigation/auth_gate_test.dart
flutter test test/models/machine_statistics_test.dart test/screens/machine_counts_reconciliation_test.dart
flutter test test/widgets/mach_alert_branding_test.dart
flutter test test/services/storage_service_test.dart test/screens/fault_reporting_screen_test.dart
~~~

## Security rules with running emulators

firebase.json defines Firestore on **127.0.0.1:8080**, Storage on **127.0.0.1:9199**, and the Emulator UI on **127.0.0.1:4000**. It does not configure Authentication emulation.

~~~bash
firebase emulators:exec --project machalert --only firestore,storage "flutter test test/services/firestore_security_rules_test.dart test/services/fault_security_rules_test.dart test/services/storage_security_rules_test.dart"
~~~

Record that both emulators started and were reachable before interpreting the result. Examine the output for availability warnings or skips. Do not run fake-emulator authorization tokens against the cloud backend.

## Android build and update checks

Release builds require ignored android/key.properties. Use the same signing key as the installed application to preserve app data.

~~~bash
flutter build apk --release --dart-define=USE_FIREBASE_EMULATOR=false --build-number=3
flutter devices
flutter install -d <device-id> --release
~~~

The build number above reproduces this verification snapshot; increase it for a later release. Verify the installed version, startup screen, absence of a startup crash, authentication restoration, and loading of the machine inventory. The APK is build/app/outputs/flutter-apk/app-release.apk.

For physical-device debugging:

~~~bash
flutter run -d <device-id> --dart-define=USE_FIREBASE_EMULATOR=false
~~~

Default debug Android routing uses **10.0.2.2**, which is an AVD host alias and does not connect a physical phone to the development computer.

## Workflow scenarios

### A. Startup, onboarding, and authentication

- First launch shows splash, then onboarding; completing onboarding persists the preference.
- Subsequent launches restore the session or show login.
- Test email/password validation, sign-up, Google sign-in, cancellation, network errors, and logout.
- New app-created profiles use role **operator**. There is no sign-up role selector.
- Provision technician and manager roles through trusted administrative access for those demo scenarios.

### B. Fault reporting

- Select an existing machine, fault type, severity, and description of at least 10 characters.
- Submit without an image; verify the success message and actual Firestore record with the authenticated reporter UID and Open status.
- With working Storage, select an image, verify upload under fault_images/{uid}/{fileName}, then verify the report's image URL.
- When upload fails, verify no report is created by that submission, the form remains available, and removing the optional image allows a retry.
- Test history and filters using records from the selected backend.

Current cloud limitation: report images cannot be uploaded until the missing bucket is provisioned. The no-image route is supported in source and mocked tests; it is not substituted for a successful live image-upload check.

### C. Manager machines, statistics, and task assignment

- Verify manager create/edit access for machines.
- Check that Home and Reports use the same inventory and that Running + In Maintenance + Breakdown + Other / Unknown equals Total.
- Verify Operational → Running; Warning/Under Maintenance → In Maintenance; Critical → Breakdown; unknown status → Other.
- Open Maintenance → **Create Task**, assign a real technician, and verify the Pending task.
- This task-creation UI is merged and implemented; it is not a pending PR dependency.

### D. Technician maintenance

- Sign in as the assigned technician and verify only permitted tasks can be read.
- Transition Pending → In Progress → Completed. Verify the stored terminal status is **Resolved**.
- Confirm updateHistory appends notes, actor information, timestamps, and optional proof URL without replacing original assignment fields.
- With working Storage, verify maintenance_proofs/{uid}/{fileName} and taskId metadata.
- Check disallowed transitions and access by other roles.

### E. Integrated review

- Operator creates a fault; manager observes it and creates/assigns a task; technician records repair progress; manager reviews the history.
- Inspect machine, fault, and maintenance records independently. Do not assume a maintenance status update automatically changes the other two documents.
- Verify actual backend permissions with rules deployed to the intended environment.

## Open validation items

- Cloud Storage provisioning, report-photo upload, and maintenance-proof upload.
- Live emulator security evaluation for this revision.
- Full cloud operator/manager/technician walkthrough.
- Non-Android Firebase configuration and device testing.
- Planned features such as push notifications and predictive analytics are outside the currently implemented test coverage.

Use [Firebase verification](firebase-verification.md) for the storage diagnosis and [the demo guide](DEMO_GUIDE.md) for retained showcase accounts and preparation.
