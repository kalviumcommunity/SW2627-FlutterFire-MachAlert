# MachAlert — implementation and delivery report

Last updated: **3 November 2026**. Code baseline: **main at 3f0f0fe**.

## Delivery status

MachAlert is an Android assignment app for reporting machine faults, viewing machine condition, and coordinating maintenance. The latest code was built as **version 1.0.0, build 3** and installed on a physical Android 16 phone. Startup, an authenticated session, and machine data display were observed on the phone.

Core application workflows are implemented, but **cloud image uploads are currently blocked by missing Firebase Storage setup**. This report does not certify complete production readiness or successful live verification of every role and backend operation.

The original Sprint 2 plan and contribution goals remain in [the PRD](../PRD.md). The current operational record is [Firebase verification](firebase-verification.md).

## Implemented application features

| Area | Current behavior |
| --- | --- |
| Startup | Branded splash, minimum 1.5-second display, authentication timeout handling, first-launch onboarding stored in Shared Preferences. |
| Authentication | Email/password sign-up and login, Google sign-in, persistent sessions, logout, and Firestore user profiles. New profiles default to operator. |
| Navigation | Home, Machines, Log Event, Reports, and Profile; role-specific actions on Home. |
| Machines | Live inventory, details, search/filtering, manager create/edit flows, status and health fields. |
| Faults | Machine/type/severity/description form, optional image, Firestore report creation, history, live monitoring, search/filtering. An upload failure prevents that report submission. |
| Maintenance | Manager task creation and technician assignment, assigned task view, status updates, notes, optional photo proof, transactional update history. |
| Reports | Machine totals and status summaries shared with Home through MachineProvider and MachineStatistics. |
| Branding | Approved MachAlert assets and Google G asset, shared Material theme, revised auth and onboarding screens. |

MachineStatistics assigns every machine to one bucket: Operational → Running; Warning or Under Maintenance → In Maintenance; Critical → Breakdown; unrecognized status → Other / Unknown. The categories sum to Total.

Maintenance states stored in Firestore are **Pending → In Progress → Resolved**. **Completed** is a presentation alias for Resolved. MaintenanceService updates the maintenance document and its history; it does not automatically synchronize the separate machine and fault documents.

## Architecture and versions

~~~text
Screens and widgets
  → AppStateProvider / MachineProvider
  → AuthService / UserService / MachineService / FaultService
    / MaintenanceService / StorageService
  → Firebase Authentication / Cloud Firestore / Cloud Storage
~~~

| Component | Current source or verified environment |
| --- | --- |
| Flutter / Dart | Verified locally with Flutter 3.47.6 and Dart 3.13.5; pubspec.yaml requires Dart ^3.13.5. |
| State management | Provider; shared machine inventory and role/session state. |
| Preferences | shared_preferences for first-launch onboarding. |
| Android build | Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0, Google Services plugin 4.4.4. |
| APK compatibility | Minimum API 24; target API 36. |
| Build Java | Verified with Android Studio's JDK 25.0.3; Java/Kotlin compile target 17. |
| Firebase project | machalert; Android package com.example.mach_alert. |
| Firebase platforms | Android configured in firebase_options.dart. Other targets require configuration and testing. |
| Dependencies | pubspec.yaml declares constraints; pubspec.lock records exact resolved versions. |

## Data and attachment paths

| Collection / path | Purpose |
| --- | --- |
| users/{uid} | Auth-linked profile, email, display name, role, timestamps. |
| machines/{machineId} | Name, production line, model, operational status, health/telemetry fields. |
| faults/{faultId} | Machine reference, type, severity, description, reporter UID, status, optional image URL, timestamp. |
| maintenance/{taskId} | Machine/fault context, assigned technician, priority, status, assignment notes, timestamps, updateHistory map. |
| alerts/{alertId} | Schema and security rules exist; this does not establish automated alert generation or push delivery. |
| fault_images/{uid}/{fileName} | Fault photo attachments. |
| maintenance_proofs/{uid}/{fileName} | Repair proof attachments; metadata includes taskId. |

Machine status values are Operational, Warning, Critical, and Under Maintenance. Fault status values are Open, In Progress, and Resolved.

## Security model in the repository

The authoritative policies are [firestore.rules](../firestore.rules) and [storage.rules](../storage.rules). Their presence in Git does not establish which version is deployed to the cloud.

- Roles are read from the canonical Firestore user profile, not inferred from the email address or a UI selection.
- Authenticated users can read machines and faults. Managers manage machine records.
- Fault creation requires an authenticated matching reportedBy UID and valid data; the rule is not restricted to the operator role.
- Managers create maintenance tasks. Managers and assigned technicians have the permitted task access; operators cannot read maintenance documents.
- The app creates operator profiles. Rules allow limited initial profile roles and prevent self-promotion to manager; privileged role setup requires trusted administration.
- Storage creation requires authentication, an own-UID path, image MIME type, and size at most 5 MiB.
- Fault-image reads allow the owner, technicians, and managers. Maintenance-proof reads allow the owner, managers, or the assigned technician identified through task metadata and Firestore.
- Storage update and delete are denied. Storage creation itself is not a role-specific “operator only” or “assigned technician only” check.
- Storage rules rely on Firestore role/task lookups, which must be configured when deploying them.

## Current cloud blocker

Read-only checks found **no buckets** in project machalert, a **404** for machalert.firebasestorage.app, a disabled/unused Firebase Storage API, and **billingEnabled: false**. The phone's report-image upload fails with HTTP 404 and object-not-found.

The photo is uploaded before the report is written, so the failed image attempt does not create the report. A report without the optional photo bypasses Storage. Maintenance proof uploads are affected too.

Provisioning Storage requires project-owner billing approval and the Blaze plan, then bucket setup and reviewed rule deployment. See [the verified diagnosis and setup steps](firebase-verification.md). No billing change, bucket creation, or rule deployment was performed during this documentation audit.

## Verification record

| Check | Result on 3 November 2026 |
| --- | --- |
| Latest code synchronized | main at 3f0f0fe; local phone-specific changes preserved. |
| Flutter analysis | No issues found. |
| Flutter test runner | 817 passed, 3 skipped, zero reported failures. |
| Live emulator security evaluation | Not established by this run; emulators were not running and some tests return early when unavailable. |
| Android release compilation | Successful, approximately 55.4 MB. |
| Installation | Build 3 installed as an update using the existing development signing key. |
| Device smoke check | App remained running; signed-in session and machine data were visible. |
| Cloud report-photo upload | Failed; missing Storage provisioning confirmed. |

An initial build 2 crashed because Windows plugin setup had stopped before regenerating Android's JNI and Shared Preferences registrations. A successful dependency setup regenerated them; build 3 passed the on-device startup check. This was a local build setup correction, not a change to the latest application feature code.

For reproducible commands and the distinction between mocked tests, emulator tests, and physical-device checks, use [the test plan](END_TO_END_TEST_PLAN.md).

## Remaining work before a complete cloud demonstration

1. Provision Storage with the project owner's approved billing setup, deploy the intended rules, and test both image workflows.
2. Provision and verify the three retained [demo identities](DEMO_GUIDE.md). They were absent from Firebase Authentication at the last check.
3. Exercise the operator, manager, and technician workflow against the chosen backend, including task assignment and authorization failures.
4. Run security tests with both emulators actually available and record the result separately from mocked tests.
5. Use a private upload signing key and appropriate release checks before any Play Store distribution.

Push notifications, automatic backend task dispatch, predictive maintenance, and live IoT data ingestion remain future work. The PRD's goals, example rules, and acceptance scenarios should not be treated as completed features.
