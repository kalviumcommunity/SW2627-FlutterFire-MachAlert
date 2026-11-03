# 🏭 MachAlert

> **Real-time machine fault reporting and maintenance monitoring using Flutter and Firebase.**

**Current snapshot — 3 November 2026:** `main` at `3f0f0fe`; Android version
`1.0.0`, build `3`, installed and running on a physical phone. Authentication,
machine data, onboarding, reporting, and maintenance workflows are implemented.
**Cloud photo uploads are currently blocked:** the configured Storage bucket does
not exist and project billing is disabled. Reports can be submitted without the
optional photo through the form's photo-free path. See [Firebase verification](docs/firebase-verification.md) for
the diagnosis, setup steps, and limits of the latest checks.

MachAlert is a mobile application designed to help manufacturing teams report machine faults immediately, monitor machine conditions, maintain fault history, and coordinate maintenance activities without waiting for end-of-shift review meetings.

---

## 📌 Problem Statement

A manufacturing company operates multiple production lines, but machine inspections and breakdown events are only captured during shift-end review meetings.

Because faults are not recorded and communicated immediately, recurring machine problems may go unnoticed until they cause:

- Unplanned machine downtime
- Repeated breakdowns
- Delayed maintenance
- Reduced production efficiency
- Missed production targets

The current process is largely **reactive** rather than proactive.

---

## 💡 Our Solution

MachAlert provides a mobile-based system where machine issues can be reported and monitored in real time.

Instead of waiting until the end of a shift, an operator can report a machine problem immediately through the app.

The reported data is stored using Firebase and can be viewed by the relevant users.

### Basic Workflow

```text
Machine Problem
      ↓
Operator notices fault
      ↓
Reports through MachAlert
      ↓
Fault stored in Firestore
      ↓
Manager / Technician sees update
      ↓
Maintenance action is taken
      ↓
Machine issue is resolved
```

---

## 🎯 Project Objectives

The main objectives of MachAlert are to:

- Enable immediate machine fault reporting
- Maintain digital machine fault history
- Reduce delay between fault detection and maintenance
- Provide real-time updates using Firebase
- Help managers monitor machine conditions
- Help technicians track maintenance work
- Provide a foundation for future recurring-fault detection and predictive maintenance

---

## 👥 User Roles

### 👷 Operator

Operators are responsible for using and inspecting machines.

They can:

- Login to the application
- View machines
- Report machine faults
- Enter fault severity
- Add fault descriptions
- Upload machine/fault images
- View submitted reports

### 👨‍🔧 Technician

Technicians handle machine maintenance.

They can:

- View reported faults
- View assigned maintenance tasks
- Update maintenance status
- Add repair notes
- Mark issues as resolved

### 👨‍💼 Manager

Managers monitor the overall production environment.

They can:

- View machines
- Monitor reported faults
- View machine condition/status
- Track maintenance activities
- Search and filter reports
- Monitor real-time updates

---

## ✨ Implemented Features

These features exist in the app. Backend-dependent features still require the
corresponding Firebase service and permissions; cloud image uploads are not yet
operational in the current project.

### Authentication

- User Sign Up
- User Login
- Google Sign-In
- User Logout
- Persistent Login
- Authentication State Handling
- Role-based application access

### Machine Management

- Machine List
- Machine Details
- Machine Status
- Machine Fault History

### Fault Reporting

- Select Machine
- Fault Type
- Severity
- Fault Description
- Image Upload
- Server Timestamp
- Real-time Fault Updates

### Maintenance

- Maintenance Task List
- Task Status
- Technician Assignment
- Maintenance Notes
- Resolved Fault Tracking

### Application Experience

- Splash Screen
- First-launch onboarding saved with Shared Preferences
- Bottom Navigation
- Shared machine statistics on Home and Reports
- Form Validation
- Loading Indicators
- Error Handling
- SnackBars and Dialogs
- Search and Filtering

---

## 🚀 Future Scope

Future extensions beyond the current app include:

- Recurring Fault Detection
- Automated Alerts
- Push Notifications
- Downtime Analytics
- Predictive Maintenance
- Machine Learning
- IoT Sensor Integration
- Real-time temperature and vibration monitoring

---

## 🛠️ Tech Stack

| Technology | Purpose |
|---|---|
| Flutter | Mobile application development |
| Dart | Programming language |
| Firebase Authentication | User authentication |
| Cloud Firestore | Application database |
| Firebase Storage | Fault image/media storage |
| Firebase | Backend services |
| Git | Version control |
| GitHub | Collaboration and Pull Requests |
| Figma | UI/UX planning and mockups |

---

## 🏗️ Application Architecture

```text
                ┌─────────────────────┐
                │   Flutter Mobile    │
                │        App          │
                └──────────┬──────────┘
                           │
            ┌──────────────┼──────────────┐
            │              │              │
            ▼              ▼              ▼
     Firebase Auth     Firestore      Firebase Storage
            │              │              │
            ▼              ▼              ▼
        User Login     App Data        Images/Media
```

---

## 🗄️ Firestore Structure

```text
users/
    userId/
        uid
        name
        email
        role

machines/
    machineId/
        name
        productionLine
        status
        temperature
        vibration
        healthScore

faults/
    faultId/
        machineId
        type
        severity
        description
        reportedBy
        imageUrl
        createdAt

maintenance/
    maintenanceId/
        machineId
        faultId
        technicianId
        priority
        status
        notes
        createdAt
```

This is an abbreviated schema. Models in `lib/models/` and `firestore.rules`
define the full current fields, including maintenance `updateHistory`. Machine
statuses are `Operational`, `Warning`, `Critical`, and `Under Maintenance`;
fault statuses are `Open`, `In Progress`, and `Resolved`. Maintenance uses
`Pending`, `In Progress`, and `Resolved` in Firestore; the UI also uses the label
`Completed` for `Resolved`.

Attachments use `fault_images/{uid}/{fileName}` and
`maintenance_proofs/{uid}/{fileName}`. Updating a maintenance task does not
automatically update the separate machine or fault document.

---

## 📁 Flutter Folder Structure

Abbreviated view of the current implementation:

```text
lib/
│
├── main.dart
├── firebase_options.dart
├── theme/
│   └── app_theme.dart
│
├── models/
│   ├── user_model.dart
│   ├── machine_model.dart
│   ├── machine_statistics.dart
│   ├── fault_model.dart
│   └── maintenance_model.dart
│
├── screens/
│   ├── auth/
│   ├── splash/
│   ├── onboarding/
│   ├── dashboard/
│   ├── machines/
│   ├── faults/
│   ├── maintenance/
│   ├── reports/
│   └── profile/
│
├── services/
│   ├── auth_service.dart
│   ├── user_service.dart
│   ├── machine_service.dart
│   ├── fault_service.dart
│   ├── maintenance_service.dart
│   └── storage_service.dart
│
├── widgets/
│   ├── app_button.dart
│   ├── app_text_field.dart
│   ├── mach_alert_logo.dart
│   └── main_bottom_navigation.dart
│
├── utils/
│   ├── app_constants.dart
│   ├── validators.dart
│   ├── emulator_config.dart
│   └── app_routes.dart
│
└── providers/
    ├── app_state_provider.dart
    └── machine_provider.dart
```

---

## 🗓️ Original Sprint 2 Plan

The assignment plan called for **3 members over 20 days**. The following timeline
and contribution targets describe that plan; they are not a current delivery or
cloud-verification claim.

Each member is expected to raise **at least one Pull Request every day**.

That means:

```text
3 Members
×
20 Days
=
Minimum 60 Pull Requests
```

### Team Responsibilities

| Role | Primary Responsibility |
|---|---|
| Member 1 | Flutter UI/UX |
| Member 2 | Firebase & Database |
| Member 3 | Application Logic & Integration |

### Sprint Milestones

| Milestone | Target |
|---|---|
| Project Planning & Setup | Day 1–5 |
| Authentication | Day 6–10 |
| Firestore & Core Application | Day 11–15 |
| Storage, Security & Integration | Day 16–18 |
| Testing & Polish | Day 19 |
| Final Submission | Day 20 |

---

## 🔀 Git & GitHub Workflow

We follow a Pull Request based development workflow.

```text
main
 │
 ├── feature/member1-feature-name
 ├── feature/member2-feature-name
 └── feature/member3-feature-name
```

### Development Process

```text
Create Branch
     ↓
Make Changes
     ↓
Test Changes
     ↓
Commit
     ↓
Push Branch
     ↓
Raise Pull Request
     ↓
Peer Review
     ↓
Merge
```

### Branch Naming Examples

```text
feature/splash-screen
feature/firebase-auth
feature/machine-list
feature/fault-reporting
feature/firestore-integration
fix/login-validation
docs/update-readme
```

### Commit Naming Examples

```text
feat: add splash screen

feat: implement firebase authentication

feat: create machine model

feat: add fault reporting form

fix: resolve login validation issue

refactor: improve firestore service

docs: update README
```

---

## 💻 Getting Started

### Prerequisites

Before running the project, make sure you have the following installed and configured:

- **Flutter SDK:** Verified with `3.47.6`; run `flutter doctor -v` to check your environment.
- **Dart SDK:** `pubspec.yaml` requires `^3.13.5`; the verified Flutter installation bundles Dart `3.13.5`. The Dart version is not the Flutter version.
- **Java Development Kit (JDK):**
  - Use a JDK supported by the checked-in Gradle/Android plugin versions. The verified build used Android Studio's JDK `25.0.3`; Java/Kotlin compilation targets Java 17.
  - Use Java 21 or later for the current Firebase emulator tooling and verify the requirement for the installed CLI version.
- **Android Studio / Android SDK:** Command-line tools, platform-tools, SDK/build tools, and either a physical Android device or an AVD. The verified APK uses min SDK 24 and target SDK 36.
- **Firebase CLI:** Node.js package `firebase-tools` (`npm install -g firebase-tools`).
- **FlutterFire CLI:** Activated via Dart pub (`dart pub global activate flutterfire_cli`).
- **Firebase Project Access:** Access to the `machalert` Firebase project.

Verify your Flutter and toolchain installation:

```bash
flutter doctor
```

---

## 📥 Clone the Repository

```bash
git clone https://github.com/kalviumcommunity/SW2627-FlutterFire-MachAlert.git
cd SW2627-FlutterFire-MachAlert
```

---

## 🔥 Firebase Setup & Installation Guide

MachAlert implements **Firebase Authentication**, **Cloud Firestore**, and
**Firebase Storage** integrations. Local Firestore and Storage emulators are
configured; Authentication still uses the cloud project in an interactive app run.

### 1. Flutter Dependency Installation

Fetch all required Dart and Flutter dependencies:

```bash
flutter pub get
```

On Windows, if this reports that plugins require symlink support, enable
**Developer Mode** in Windows Settings and rerun `flutter pub get`. Ensure it
finishes successfully before building: a partial setup can leave Android's
generated plugin registration outdated and cause a startup crash.

### 2. Firebase CLI Installation

Install or update the Firebase CLI globally:

```bash
npm install -g firebase-tools
```

Verify the installed version:

```bash
firebase --version
```

### 3. Firebase Login

Authenticate your CLI session:

```bash
firebase login
```

If working in a headless or cloud environment without a browser, use:

```bash
firebase login --no-localhost
```

### 4. FlutterFire Configuration

The repository already contains the verified `lib/firebase_options.dart` generated for the target project `machalert`. To re-synchronize or inspect options:

```bash
flutterfire configure --project=machalert
```

> **Platform Support Note:** Android is the configured target in
> `lib/firebase_options.dart`. Other platforms need matching configuration and
> testing before use; the existence of a platform folder or Firebase registration
> does not make that target runnable. Cloud Storage provisioning is a separate
> requirement even for Android.

### 5. Android Firebase Configuration

Ensure `android/app/google-services.json` is present and matches the `machalert` project:
- Package Name: `com.example.mach_alert`
- Project ID: `machalert`
- Configured Storage Bucket: `machalert.firebasestorage.app` — this name is in the app configuration, but the bucket was confirmed absent on 3 November 2026.

For cloud photo uploads, complete Storage setup and review/deploy `storage.rules`
after the project owner approves the required billing setup. Follow the
[verified storage setup guide](docs/firebase-verification.md#completing-cloud-photo-setup).
The error **“The requested storage file was not found.”** during report submission
currently comes from this missing bucket. Remove the optional photo to submit
through Firestore while Storage is unavailable.

New sign-ups create **operator** profiles. Provision technician and manager roles
through trusted administrative access; the app has no sign-up role selector.
The three showcase identities and their original credentials are retained in
[the demo guide](docs/DEMO_GUIDE.md), with their verified setup status.

The Google Services Gradle plugin is registered in `android/settings.gradle.kts`:
```kotlin
id("com.google.gms.google-services") version("4.4.4") apply false
```
and applied in `android/app/build.gradle.kts`:
```kotlin
id("com.google.gms.google-services")
```

### 6. Starting Firestore and Storage Emulators

MachAlert includes local emulator configuration in `firebase.json`:
- **Firestore Emulator:** Port `8080` (HTTP / REST)
- **Firebase Storage Emulator:** Port `9199`
- **Emulator UI:** Port `4000`

Ensure JDK 21+ is in your environment and start the emulators:

```bash
firebase emulators:start --only firestore,storage
```

The Emulator UI dashboard will be accessible at `http://127.0.0.1:4000`.

### 7. Running MachAlert in Local Emulator Mode

By default, debug builds run in **safe local emulator mode** via `EmulatorConfig`:
- **Firestore Traffic:** Redirected to port `8080`.
- **Storage Uploads:** Redirected to port `9199`.

#### Emulator Network Host Resolution
- **Android Virtual Device (AVD):** Automatically routes to `10.0.2.2` (the special loopback alias pointing to the host machine's `127.0.0.1`).
- **macOS / Desktop / Local Environment:** Connects directly to `127.0.0.1`.

Run the app in debug mode:

```bash
flutter run
```

### 8. Running MachAlert in Explicit Cloud Mode

To bypass local emulators and connect the debug build directly to live Firebase Cloud Firestore and Firebase Storage:

```bash
flutter run --dart-define=USE_FIREBASE_EMULATOR=false
```

Or target cloud mode explicitly:

```bash
flutter run --dart-define=USE_CLOUD_FIRESTORE=true --dart-define=USE_CLOUD_STORAGE=true
```

> **Release Mode Safety:** Release builds compiled with `flutter build` or `flutter run --release` **never** connect to local emulators by default, preventing accidental emulator connections in production.

### 9. Running Automated Security & Integration Tests

Execute the Firestore and Storage security rules suites inside a transient
Firebase emulator session, and confirm both emulators are reachable:

```bash
firebase emulators:exec --project machalert --only firestore,storage "flutter test test/services/firestore_security_rules_test.dart test/services/fault_security_rules_test.dart test/services/storage_security_rules_test.dart"
```

Or execute the complete repository test suite:

```bash
flutter test
```

The latest plain Flutter run reported **817 passed, 3 skipped**, with no emulators
running. Some security tests return early when an emulator is unavailable, so a
passing count alone does not prove security rules or cloud uploads were tested.
See [the test plan](docs/END_TO_END_TEST_PLAN.md) for the verification boundaries.

### 10. Building the Android APK

For installation on a physical Android phone, build an APK that connects to
Firebase over the internet:

```bash
flutter build apk --release --dart-define=USE_FIREBASE_EMULATOR=false
```

The APK is generated at `build/app/outputs/flutter-apk/app-release.apk`.
Release builds require an ignored `android/key.properties` file with `storeFile`,
`storePassword`, `keyAlias`, and `keyPassword` for the signing key. To update an
installed app without uninstalling it, use the same signing key as that app.
For local assignment installs, this can be the computer's existing debug key.
Use a private upload key before publishing to Google Play.

To install over USB:

1. Enable **Developer options** and **USB debugging** on the phone.
2. Connect it to your computer, unlock it, and accept **Allow USB debugging**.
3. Run `flutter devices` and find the phone's device ID.
4. Run `flutter install -d <device-id> --release`.
5. Open **MachAlert** with Wi-Fi or mobile data enabled and sign in or create an account.

For development with hot reload on a physical phone, use:

```bash
flutter run -d <device-id> --dart-define=USE_FIREBASE_EMULATOR=false
```

Plain `flutter run` and `flutter build apk --debug` still use the local database
and storage emulators. Their default Android host (`10.0.2.2`) is for an Android
Virtual Device and is not reachable from a physical phone.

Google sign-in also requires the SHA-1 fingerprint of the key used to build the
APK to be registered for `com.example.mach_alert` in Firebase project settings.
Each development computer may have a different debug signing key. After adding
its fingerprint, refresh `android/app/google-services.json` and rebuild.

---

## ▶️ Device Selection & Execution

Check connected physical devices and running virtual devices:

```bash
flutter devices
```

Launch on a specific device:

```bash
flutter run -d <device-id>
```

---

## 🤝 Contribution Guidelines

Before starting work:

```bash
git checkout main
git pull origin main
```

Create your branch:

```bash
git checkout -b feature/your-feature-name
```

After completing your work:

```bash
git add .
git commit -m "feat: describe your change"
git push -u origin feature/your-feature-name
```

Then create a Pull Request on GitHub.

### Important Team Rule

Every team member must:

- Raise at least one PR every working day
- Keep PRs small and focused
- Test changes before raising a PR
- Write meaningful commit messages
- Review teammates' PRs
- Avoid pushing unfinished experimental code directly to `main`

---

## 📚 Documentation & Verification Guides

Comprehensive project documentation, testing plans, and presentation guides are available in the `docs/` directory:

- 📋 **[End-to-End Test Plan](docs/END_TO_END_TEST_PLAN.md):** Complete test matrix, scenario breakdown (Scenarios A through E), mock architecture, execution commands, and verification criteria.
- 🎬 **[Demo Guide & Script](docs/DEMO_GUIDE.md):** Showcase identities and credentials, account preparation, cloud/emulator setup, and a 4-to-5 minute demonstration.
- 🏭 **[Implementation & Delivery Report](docs/PROJECT_COMPLETION_REPORT.md):** Current features, architecture, data paths, security model, verification results, and remaining work.
- 🔥 **[Firebase & Android Verification](docs/firebase-verification.md):** Physical-phone installation, signing, cloud service checks, and the confirmed Storage upload blocker.

---

## ✅ Current Project Status

```text
Status: Android build 3 installed; core workflows implemented; cloud photo storage setup pending.
```

As of **3 November 2026**, the latest source baseline is `main` at `3f0f0fe`.
The release APK (`1.0.0`, build `3`) is installed on an Android 16 phone, with
startup, an authenticated session, and machine data display observed. Static
analysis passed; the Flutter runner reported **817 passed and 3 skipped**.
Cloud image uploads remain blocked, demo identities need provisioning, and a full
live multi-role walkthrough and current emulator-rule run are still required.

---

## 📖 Sprint 2 Learning Areas

This project covers:

- Dart Language
- Flutter Core
- Stateless Widgets
- Stateful Widgets
- Reusable Widgets
- Screen Navigation
- Splash Screen
- Forms
- Input Validation
- State Management
- Lists
- Loading Indicators
- Error Handling
- Async/Await
- Firebase Configuration
- Firebase Authentication
- Cloud Firestore
- CRUD Operations
- Firestore Queries
- Real-Time Updates
- Security Rules
- Firebase Storage
- Image Upload
- Persistent Login
- Bottom Navigation
- User Feedback
- Search and Filtering

---

## 📜 License

This project is being developed as part of an academic Sprint project.

---

## 🙌 Acknowledgements

Developed by the MachAlert team as part of the **Flutter & Firebase Mobile Application Development Sprint**.

---

<p align="center">
  <b>MachAlert</b><br>
  Detect Faster • Report Earlier • Maintain Smarter
</p>
