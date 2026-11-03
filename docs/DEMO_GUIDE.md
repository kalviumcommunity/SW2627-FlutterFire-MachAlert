# MachAlert demo guide

Last updated: **3 November 2026**. Current baseline: main at **3f0f0fe**; physical-phone installation: **1.0.0, build 3**.

## What is ready to show

The Android app includes first-launch onboarding, email/password and Google sign-in, role-specific dashboards, machine management, fault reporting/history, manager task assignment, technician status updates, and reports using shared machine statistics.

Cloud photo uploads are currently blocked: the configured Storage bucket does not exist and billing is disabled. Present a **report without an image** until Storage is provisioned, or use the local Storage emulator on an Android Virtual Device. Do not present successful mocked upload tests as a successful cloud upload. See [Firebase verification](firebase-verification.md).

## Demo accounts — retained for the showcase

These are the project's intended demo identities. Their credentials are retained exactly as previously documented.

| Persona | Email | Demo password | Required Firestore role | Verified cloud setup |
| --- | --- | --- | --- | --- |
| Operator | operator@machalert.test | Operator123! | operator | Not provisioned |
| Technician | technician@machalert.test | Technic123! | technician | Not provisioned |
| Manager | manager@machalert.test | Manager123! | manager | Not provisioned |

Read-only checks on **3 November 2026** found none of these three emails in Firebase Authentication for project **machalert**. The repository does not automatically seed these accounts. No account or password was deleted or changed during the documentation update.

### Prepare the identities before presenting

1. In the intended demo Firebase environment, create the three email/password identities with the credentials above, or sign up through the app if the identity is absent.
2. Sign in once to create the matching users/{uid} profile. The app creates new profiles as **operator**; sign-up does not offer a role selector.
3. An authorized project administrator must set the technician profile's role to **technician** and the manager profile's role to **manager** using trusted administrative access. Keep UID and email consistent with Firebase Authentication.
4. Sign out and back in, then verify each dashboard and the technician's available assignments.
5. Do not reset an existing account simply because this guide contains an example password. Check with its owner if credentials differ.

These passwords are published in the repository and are suitable only for a controlled, disposable showcase environment. Do not give an account using a published password privileged access to real production data.

## Choose the demo environment

### Physical Android phone with the cloud backend

Build 3 is already installed on the connected phone. For later development runs:

~~~bash
flutter run -d <device-id> --dart-define=USE_FIREBASE_EMULATOR=false
~~~

Use Wi-Fi or mobile data. Verify real users and machines exist in the cloud project. For the current project, leave optional photos unattached.

### Android Virtual Device with local Firestore and Storage

~~~bash
firebase emulators:start --project machalert --only firestore,storage
~~~

In another terminal:

~~~bash
dart run tool/seed_mock_machines.dart
flutter run -d <emulator-id>
~~~

This seeder targets the **local Firestore emulator**, not the cloud database. It supplies five machines, including **mock-cnc-01 — CNC Milling Machine 01**, **mock-press-02 — Hydraulic Press 02**, and **mock-compressor-05 — Industrial Compressor 05**.

Firestore and Storage use the AVD host alias **10.0.2.2**. Authentication still connects to Firebase because an Auth emulator is not configured. Create matching role profiles in the database actually used by the demo. Plain flutter run is not the correct cloud command for a physical phone.

## Presentation sequence — approximately 4–5 minutes

### 1. Startup and operator report

- On first launch, show the splash and onboarding, then continue to sign-in. Onboarding completion is saved using Shared Preferences.
- Sign in as the prepared operator.
- Open **Machines** and inspect a machine. Use an existing cloud machine, or the seeded **CNC Milling Machine 01** in emulator mode.
- Open **Log Event** in the bottom bar or **Report Fault** on Home.
- Select **Mechanical**, severity **High**, and enter a description of at least 10 characters, for example: “Spindle bearing is running hot with unusually heavy vibration.”
- For the current cloud project, submit without a photo. Once Storage is provisioned, or when using the Storage emulator, demonstrate selecting and uploading an image separately.
- Confirm the success message and verify the new entry in **Fault History**.

A photo-upload error stops this submission before the report is saved. Remove the attachment and retry; do not announce a successful report until the app confirms it.

### 2. Manager overview and assignment

- Sign out through the app and sign in as the prepared manager.
- Show Home's machine counts and **Reports**. Running, In Maintenance, Breakdown, and Other / Unknown derive from the same machine inventory.
- Explain that **Operational** counts as Running, **Warning** and **Under Maintenance** count as In Maintenance, and **Critical** counts as Breakdown.
- Open **Faults** to inspect the new fault and available search/filter controls.
- Open **Maintenance**, tap **Create Task**, select the machine and a provisioned technician, and submit a Pending task.
- If showing machine add/edit, use disposable demo data and confirm any intended changes.

### 3. Technician maintenance

- Sign in as the prepared technician and open **Assigned Maintenance**.
- Select the task the manager just created; the guide does not assume a fixed MNT-001 task already exists.
- Tap **Update Maintenance Status**, select **In Progress**, enter notes, and save.
- Open the update sheet again and select **Completed**, with repair notes.
- Leave proof photos unattached in the current cloud setup. With working Storage, a proof is uploaded under maintenance_proofs/{uid}/{fileName} with taskId metadata.
- Show the update history. The UI label **Completed** maps to the stored status **Resolved**.

### 4. Manager review and close

- Return as manager and inspect the task's status and history.
- Show the machine and fault records separately. Updating a maintenance task does not automatically prove that the machine became Operational or that the linked fault was resolved; inspect and update those records through their supported workflows.
- Explain the current limits: cloud photo storage needs provisioning; push notifications, automated fault-triggered dispatch, predictive maintenance, and live IoT ingestion are not demonstrated features.

## Pre-demo checklist

- Confirm each demo identity exists, signs in, and has the correct users/{uid} role.
- Confirm the chosen cloud or emulator database has machines and technician profiles.
- Confirm the app can submit a report without an image.
- Test report and proof uploads only after the selected Storage backend is working.
- Confirm a manager can create a task and the assigned technician can see it.
- Keep the phone online in cloud mode.
- Treat **817 passed, 3 skipped** as the latest Flutter runner result, not proof that every live Firebase operation works. See [the test plan](END_TO_END_TEST_PLAN.md).
