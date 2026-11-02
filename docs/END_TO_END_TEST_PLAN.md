# MachAlert — End-to-End Test Plan & Verification Strategy

## 1. Application Test Scope

MachAlert is a Flutter + Firebase industrial maintenance management system designed for production manufacturing facilities. This document outlines the comprehensive testing strategy, covering end-to-end user journeys across the three core personas:

- **Operator:** Factory floor personnel inspecting machinery, reporting active breakdowns and anomalies, attaching photo documentation, and tracking reported fault history.
- **Technician:** Specialized maintenance engineers receiving assigned repair orders, transitioning work through lifecycle stages (`Pending` → `In Progress` → `Completed`/`Resolved`), entering timestamped technical notes, uploading photo proof of completion to Firebase Storage, and maintaining an immutable audit log.
- **Manager:** Production and plant leadership overseeing facility machine health, monitoring incoming real-time fault streams, evaluating severity telemetry, and reviewing plant-wide maintenance velocity.

---

## 2. Test Architecture & Methodology

The test suite enforces a rigorous, multi-tiered testing pyramid that strictly differentiates between isolated fast feedback, emulator-backed security verification, and full-application user journeys:

| Test Layer | Framework / Tools | Scope & Purpose |
| :--- | :--- | :--- |
| **Unit Tests** | `flutter_test`, `fake_cloud_firestore` | Domain logic, data models, serialization (`fromMap`/`toMap`), state providers (`AppStateProvider`, `MachineProvider`), and utilities (`EmulatorConfig`). |
| **Widget & Screen Tests** | `WidgetTester` | Rendering invariants, form validation triggers, state switching (loading, error, empty), and isolated widget interactions. |
| **Service Integration Tests** | `fake_cloud_firestore`, mocked `FirebaseAuth`, custom `StorageUploader` | Multi-method transaction sequences, stream transformation, actor scoping, and service-level error handling (`FaultService`, `MaintenanceService`, `StorageService`, `UserService`). |
| **Live Emulator Security Tests** | `firebase emulators:exec`, Java 21 | Rule evaluation on live Firestore (`firestore.rules`) and Firebase Storage (`storage.rules`) emulator instances, verifying read/write permissions, role boundaries, and append-only history enforcement. |
| **Widget-Level E2E Integration Tests** | `WidgetTester`, `fake_cloud_firestore`, mock `StorageUploader`, mock `FirebaseAuth` (`app_e2e_test.dart`) | Multi-screen application integration tests simulating complete user journeys, role navigation, form validation, state propagation, and full factory workflows in an isolated, deterministic test environment without network calls. |

> **Important Test Classification Note:**
> - **Widget-Level Multi-Screen Integration Tests:** Implemented in `test/integration/app_e2e_test.dart`. Uses `WidgetTester` and in-memory test doubles (`FakeFirebaseFirestore`, mock `StorageUploader`, fake `FirebaseAuth`) to execute fast, deterministic, multi-screen user journeys without external network dependencies.
> - **Firebase Emulator Security Tests:** Implemented in `test/services/*_security_rules_test.dart`. Executed against real local Firestore (port 8080) and Storage (port 9199) emulator processes via `firebase emulators:exec`.
> - **Live Backend E2E Tests:** Involves connecting automated test harnesses to live cloud Firebase or running emulator instances over real HTTP/TCP sockets (planned for CI release pipelines).
> - **Manual Device Testing:** Interactive physical or virtual device testing on Android Virtual Devices (AVD) using `flutter run` with `EmulatorConfig` routing.

---

## 3. End-to-End Scenarios Tested

### Scenario A — Complete Authentication & Role Provisioning Journey
- **Launch & Splash:** The app initializes in `AppStatus.initializing`, displaying the branded splash screen.
- **Unauthenticated Gate:** Once initialized, `AuthGate` routes the user to `LoginScreen`.
- **Registration Flow:** Tapping "Don't have an account? Sign Up" transitions to `SignupScreen`. The user enters full name, email, and matching passwords.
- **Profile Provisioning:** `AuthService.signUp()` registers the authentication identity, followed by `UserService.createProfileIfAbsent()` creating the Firestore record under `users/{uid}` with default role `operator`.
- **Authenticated Routing:** `AppStateProvider` resolves the user profile and notifies `AuthGate`, mounting `HomeScreen` with role-specific banners.
- **Session Termination:** Tapping "Logout" invokes `AuthService.signOut()`, clearing state and cleanly returning to `LoginScreen`.
- **Error Boundaries:** Validates email format, password minimum length (6+ chars), password confirmation mismatch, and duplicate email collision handling.

### Scenario B — Operator Fault Reporting & History Journey
- **Dashboard Action:** Authenticated operator accesses "Report Fault" from the Operator Dashboard.
- **Form Completion:** Operator selects machine (`MCH-001`), fault type (`Mechanical`), severity chip (`High`), and enters descriptive narrative (minimum 10 characters).
- **Attachment Upload:** Attaches fault photo via `StorageService.uploadFaultImage()`, user-scoped under `fault_images/{uid}/...`.
- **Persistence & Feedback:** Form submission invokes `FaultService.addFault()`, persisting the record with status `Open` and actor UID. A confirmation snackbar is surfaced, and navigation returns to `HomeScreen`.
- **History Inspection:** Operator opens "Fault History", asserting the new fault is rendered with its severity badge and status.
- **Error Boundaries:** Rejects descriptions shorter than 10 characters and prevents corrupt writes on storage upload failure.

### Scenario C — Manager Monitoring & Factory Inspection Journey
- **Manager Overview:** Authenticated manager accesses "Manager Dashboard" and inspects the "Factory Overview" stat cards.
- **Machine Fleet Inspection:** Manager navigates to "Machines", opening `MachineListScreen` with administrative privileges (`canManage: true`). Tapping an individual unit opens `MachineDetailsScreen` displaying telemetry, health scores, and operational line details.
- **Live Fault Stream:** Manager accesses "Faults", opening `RealtimeFaultsScreen` to monitor real-time fault events with severity and status filters.
- **Maintenance Overview:** Manager accesses "Maintenance", inspecting all active tasks across the entire facility.
- **Empty & Error Handling:** Validates empty state messaging and error recovery buttons on stream disconnects.

### Scenario D — Technician Maintenance & Resolution Journey
- **Assigned Task Access:** Authenticated technician opens "Assigned Maintenance" on the Technician Dashboard, displaying only tasks assigned to their UID.
- **Task Detail Inspection:** Technician opens task details (`MaintenanceDetailsScreen`), reviewing machine context, priority, and original assignment instructions.
- **In-Progress Transition:** Technician opens the status update bottom sheet, selects `In Progress`, enters diagnostic notes, and saves the update.
- **Completion with Proof:** Technician re-opens status update, selects `Completed` (`Resolved`), enters repair notes, attaches photo proof via `StorageService.uploadImage()`, and saves the update.
- **Audit Verification:** Verifies the Firestore document transitions to `Resolved`, `updateHistory` appends both milestones with the technician's UID, and original assignment notes remain strictly immutable.

### Scenario E — Integrated Multi-Role Factory Workflow
- **Cross-Domain Verification:** Unifies Operator, Manager, and Technician interactions on a shared factory dataset:
  1. Operator reports a `Critical` breakdown on an extrusion press.
  2. Manager monitors incoming critical alerts via the live fault stream.
  3. A maintenance repair task is scheduled and assigned to the technician.
  4. Technician starts repair, uploads photo proof, and marks the task `Resolved`.
  5. Final database assertions verify full consistency across collections (`faults`, `maintenance`, `storage`).

---

## 4. Test Environment & Prerequisites

To execute the test suites locally:

1. **Flutter SDK:** Version `3.13.5` or higher with Dart SDK `3.13+`.
2. **Java Runtime:** Java 21+ required by `firebase-tools >= 15.32.0` (set via `JAVA_HOME`).
3. **Firebase CLI:** Version `15.32.0` or higher (`npm install -g firebase-tools@latest`).
4. **Platform Setup:** Validated on macOS (arm64/x86_64) and Linux.

---

## 5. Execution Instructions

### A. Run Focused End-to-End Tests
Executes the complete multi-screen user journey test suite:
```bash
flutter test test/integration/app_e2e_test.dart
```

### B. Run Service & Emulator Configuration Tests
```bash
flutter test test/utils/emulator_config_test.dart
flutter test test/services/storage_service_test.dart
flutter test test/services/fault_service_test.dart
flutter test test/services/maintenance_service_test.dart
flutter test test/services/user_service_test.dart
```

### C. Run Live Security Rules Tests Against Local Emulators
```bash
# Ensure JAVA_HOME points to JDK 21+
export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

firebase emulators:exec --only firestore,storage \
  "flutter test test/services/firestore_security_rules_test.dart test/services/fault_security_rules_test.dart test/services/storage_security_rules_test.dart"
```

### D. Run Full Repository Test Suite
```bash
flutter test
```

### E. Run Static Analysis & Build Verification
```bash
flutter analyze
flutter build apk --debug
```

---

## 6. Verification Results Summary

| Suite / Check | Test Count | Passed | Failed | Skipped | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **End-to-End Integration (`app_e2e_test.dart`)** | 7 | 7 | 0 | 0 | **PASSED** |
| **Emulator Configuration (`emulator_config_test.dart`)** | 17 | 17 | 0 | 0 | **PASSED** |
| **Storage Service (`storage_service_test.dart`)** | 17 | 17 | 0 | 0 | **PASSED** |
| **Firestore Security Rules (Live Emulator)** | 50 | 50 | 0 | 0 | **PASSED** |
| **Fault Security Rules (Live Emulator)** | 16 | 16 | 0 | 0 | **PASSED** |
| **Storage Security Rules (Live Emulator)** | 24 | 24 | 0 | 0 | **PASSED** |
| **Full Flutter Test Suite (`flutter test`)** | 709 | 709 | 0 | 0 | **PASSED** |
| **Static Analysis (`flutter analyze`)** | — | — | 0 issues | — | **PASSED** |
| **Android Debug Build (`flutter build apk --debug`)** | — | — | — | — | **SUCCESS** |

---

## 7. Known Test Limitations & Future Enhancements

1. **Authentication Emulator Dependency:** The current `firebase.json` registers Firestore (port 8080) and Storage (port 9199) emulators. Live Firebase Authentication emulator is not yet registered; end-to-end authentication journeys utilize isolated `FirebaseAuth` and `UserService` fakes to prevent polluting production credentials.
2. **Manager Task Creation UI:** The manager maintenance task creation/assignment UI from PR #57 remains an unmerged dependency. The test suite validates existing monitoring, inspection, and maintenance overview capabilities while documenting creation workflows as pending.
3. **Platform Scope:** E2E and unit suites validate Android and desktop/headless runtime environments. iOS, Web, macOS, Windows, and Linux are unconfigured in `firebase_options.dart`.
