# 🎬 MachAlert — 3-to-5 Minute Demonstration Guide

> **Live Walkthrough Script, Multi-Role Factory Workflows, and Presentation Guide**
> **Application:** MachAlert Industrial Maintenance Platform
> **Target Audience:** Engineering Leads, Plant Supervisors, Academic Evaluators
> **Duration:** 3 to 5 Minutes

---

## 📋 Executive Overview & Architecture (30 Seconds)

MachAlert is a real-time industrial mobile platform built with **Flutter** and **Firebase** to eliminate delayed breakdown reporting on manufacturing production lines.

### Key Technical Foundations
- **Cross-Platform UI:** Flutter 3.13+ with unified Material 3 design and role-adaptive dashboards.
- **Backend Services:** Firebase Authentication, Cloud Firestore (real-time stream listeners), and Firebase Storage.
- **Role-Based Access Control (RBAC):** Three distinct personas (**Operator**, **Technician**, **Manager**) enforced at both the client routing layer and production database security rules.
- **Local Emulator Integration:** Out-of-the-box local development via `firebase-tools` supporting Firestore (port 8080) and Storage (port 9199) with automated host mapping for Android Virtual Devices (`10.0.2.2`).

```text
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│    Operator     │       │     Manager     │       │   Technician    │
│  Reports Fault  │       │ Real-Time Audit │       │ Resolves Repair │
└────────┬────────┘       └────────▲────────┘       └────────▲────────┘
         │                         │                         │
         ▼                         │                         │
  [Cloud Firestore] ◄──────────────┴─────────────────────────┘
  [Firebase Storage] (Fault Evidence & Maintenance Completion Proofs)
```

---

## ⚙️ Demo Environment Setup & Prerequisites

No cloud billing or live Firebase project credentials are required to run this demonstration. The entire demo operates reliably on the local Firebase Emulator Suite or on an Android Virtual Device / physical test device.

### 1. Start the Local Firebase Emulators
In your terminal, launch the Firestore and Storage emulators:
```bash
firebase emulators:start --only firestore,storage
```
*The Firebase Emulator UI dashboard will be accessible at `http://127.0.0.1:4000`.*

### 2. Launch MachAlert
In a second terminal, run the application:
```bash
# Debug run with automated local emulator routing
flutter run
```

### 3. Demo Persona Credentials (Pre-Seeded / Self-Registered)
| Persona | Email | Password | Role | Primary Responsibility |
| :--- | :--- | :--- | :--- | :--- |
| **Operator** | `operator@machalert.test` | `Operator123!` | `operator` | Inspect machines, report breakdown faults with photos |
| **Technician** | `technician@machalert.test` | `Technic123!` | `technician` | Execute maintenance, transition statuses, upload repair proof |
| **Manager** | `manager@machalert.test` | `Manager123!` | `manager` | Monitor factory health, audit active faults, inspect maintenance |

*(Note: New users can also be registered directly through the in-app Sign Up screen; the sign-up workflow allows instant role selection. The local `firebase.json` currently registers Firestore and Storage emulators; Firebase Authentication connects to the configured project or can be exercised via in-app registration).*

---

## ⏱️ Step-by-Step Presentation Script

```text
Total Time: 4 Minutes 30 Seconds
├── 00:00 - 00:30  Intro & Architecture
├── 00:30 - 01:30  Scene 1: Operator Fault Reporting & History
├── 01:30 - 02:30  Scene 2: Manager Factory Monitoring & Live Stream
├── 02:30 - 03:30  Scene 3: Technician Repair Execution & Proof Upload
├── 03:30 - 04:00  Scene 4: Manager Audit & Machine Health Verification
└── 04:00 - 04:30  Conclusion & Security Deep-Dive
```

---

### Scene 1: Operator Reports Machine Fault (1 Minute)

**Presenter Goal:** Demonstrate fast, guided breakdown reporting with photo evidence directly from the shop floor.

1. **Login as Operator:**
   - On the `LoginScreen`, enter `operator@machalert.test` and `Operator123!`.
   - Tap **Login**.
   - The app routes to `HomeScreen`, displaying the **Operator Dashboard** (`Machine Operations`).
2. **Review Operator Dashboard:**
   - Highlight the operator-specific action cards: *Machines*, *Report Fault*, *Fault History*, and *My Reports*.
3. **Report a Machine Fault:**
   - Tap **Report Fault** to open `FaultReportingScreen`.
   - Select Machine: Choose **CNC Milling Unit 01 (MCH-001)**.
   - Select Fault Type: Choose **Mechanical Fault**.
   - Select Severity: Choose **High** (color-coded amber/red badge).
   - Enter Description:
     > *"Spindle motor bearing running hot with heavy vibration exceeding 4.2 mm/s at 3000 RPM."*
   - Attach Photo Evidence:
     - Tap the camera/gallery photo picker card (`pick-fault-image`).
     - Select a sample equipment inspection photo.
     - The thumbnail preview appears instantly with the attached file name.
   - Tap **Submit Report**.
4. **Verify Immediate Local Feedback:**
   - A success confirmation SnackBar appears.
   - Tap **Fault History** to verify that the newly submitted fault immediately appears in the real-time stream with status **Open** and severity **High**.

---

### Scene 2: Manager Factory Monitoring & Live Stream (1 Minute)

**Presenter Goal:** Show how managers gain instantaneous visibility into shop-floor breakdowns without waiting for end-of-shift meetings.

1. **Switch to Manager:**
   - On the Operator dashboard, tap **Logout**.
   - Log in as `manager@machalert.test` with `Manager123!`.
   - The app routes to `HomeScreen`, adapting dynamically to the **Manager Dashboard** (`Factory Overview`).
2. **Inspect Factory Overview Metrics:**
   - Notice the high-level KPI cards: **Machines** count and **Active Faults** counter.
   - Notice the Manager action cards: *Machines*, *Fault History*, *Faults* (Real-Time Monitor), and *Maintenance*.
3. **Real-Time Fault Stream Inspection:**
   - Tap **Faults** to open `RealtimeFaultsScreen`.
   - The newly reported CNC Milling Unit 01 fault is visible at the top of the stream.
   - Point out that this screen subscribes to Cloud Firestore snapshots (`streamFaults()`), eliminating manual pull-to-refresh.
4. **Machine Fleet Inspection:**
   - Return to the dashboard and tap **Machines** to open `MachineListScreen`.
   - Explain that Managers possess management privileges (FAB / add-machine capabilities enabled via `canManage: true`).
   - Tap **CNC Milling Unit 01** to view `MachineDetailsScreen`, showing health scores, production line mapping (`Line 1`), and operating status.

---

### Scene 3: Technician Repair Execution & Proof Upload (1 Minute)

**Presenter Goal:** Demonstrate technician workflow, enforced lifecycle status transitions, and audit-proof image upload to Firebase Storage.

1. **Switch to Technician:**
   - Tap **Logout** and log in as `technician@machalert.test` with `Technic123!`.
   - The dashboard dynamically presents the **Technician Dashboard** (`Maintenance Overview`).
2. **Access Assigned Maintenance:**
   - Tap **Assigned Maintenance** to open `MaintenanceListScreen`.
   - Select the maintenance task corresponding to the CNC Milling Unit 01 breakdown: **MNT-001: Inspect spindle vibration**.
3. **Open Maintenance Task Details:**
   - The `MaintenanceDetailsScreen` displays the current status as **Pending**, priority **High**, and machine context.
4. **Transition to "In Progress":**
   - Tap the status selector or button to transition the task from **Pending** to **In Progress**.
   - The update is committed to Firestore in real time.
5. **Complete Repair with Storage Photo Proof:**
   - In the repair notes input, enter:
     > *"Disassembled spindle housing. Replaced worn drive belt and defective front bearing assembly. Re-greased with synthetic high-temp lubricant. Vibration measured at nominal 0.2 mm/s."*
   - Attach Completion Proof:
     - Tap the proof image picker (`ValueKey('pick-proof-gallery')`).
     - Select the repair completion photo.
   - Tap **Completed**.
   - The application uploads the binary image directly to Firebase Storage (`maintenance/{taskId}/...`), obtains the storage download URL, and writes a tamper-evident entry to the Firestore document's `updateHistory` map.
6. **Verify Audit Trail:**
   - Scroll down to the **Update History** section.
   - Show the sequential lifecycle log:
     - `Pending` (Initial)
     - `In Progress` (Technician assigned)
     - `Completed` (Repair notes, timestamp, technician ID, and verified photo proof thumbnail).

---

### Scene 4: Manager Audit & Machine Health Verification (30 Seconds)

**Presenter Goal:** Close the factory loop by validating that managers and operators see the completed resolution.

1. **Switch back to Manager:**
   - Log in as `manager@machalert.test`.
2. **Review Maintenance Activity:**
   - Tap **Maintenance** on the dashboard.
   - Filter by **Completed**.
   - Tap **MNT-001** to inspect the technician's repair notes and click the verified proof image URL stored in Firebase Storage.
3. **Verify Machine Status:**
   - Return to **Machines** -> **CNC Milling Unit 01**.
   - Confirm that the machine is marked as **Operational** and ready for continuous production.

---

### Conclusion & Security Deep-Dive (30 Seconds)

**Presenter Goal:** Highlight code quality, test rigor, and defense-in-depth security.

1. **Production Security Rules:**
   - **Firestore Rules (`firestore.rules`):**
     - Strict RBAC: Operators can only create faults and read machine/history data.
     - Technicians can only update tasks assigned to their UID and must follow the valid status machine (`Pending` -> `In Progress` -> `Completed`).
     - Managers hold administrative privileges for machine definitions and maintenance assignment.
   - **Storage Rules (`storage.rules`):**
     - Enforces path isolation (`faults/{faultId}/...`, `maintenance/{taskId}/...`).
     - Validates image content types (`image/jpeg`, `image/png`) and restricts payloads to `< 5MB`.
2. **Automated Verification Metrics:**
   - **709 Automated Tests** passing across unit, widget, mock-based E2E, and emulator-backed security suites.
   - Zero static analysis warnings (`flutter analyze`).
   - Verified Android Debug APK build (`flutter build apk --debug`).

---

## 🏭 Standard Mock Factory Dataset

For realistic and repeatable demonstrations, use the following factory assets:

| Asset ID | Machine Name | Production Line | Model Number | Initial Status | Initial Health |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `MCH-001` | CNC Milling Unit 01 | Line 1 - Machining | DMG-MORI-NLX2500 | `Operational` | 95.0% |
| `MCH-002` | Hydraulic Press 02 | Line 2 - Stamping | SCHULER-HP-500 | `Maintenance` | 64.0% |
| `MCH-003` | Robotic Welding Cell 03 | Line 1 - Fabrication | KUKA-KR-CYBERTECH | `Operational` | 91.0% |
| `MCH-100` | Injection Molder 100 | Line 3 - Plastics | ENGEL-VICTORY-330 | `Operational` | 88.5% |

---

## 💡 Practical Presentation Tips

1. **Fast Persona Switching:** Keep three browser tabs or three device windows open if presenting in emulator web/desktop mode, or keep test account passwords on your clipboard for swift mobile login transitions.
2. **Highlight Real-Time Sync:** If presenting on a projector or dual monitor, display the **Manager Realtime Faults screen** side-by-side with the **Operator Fault Reporting screen** to show instant live Firestore snapshot updates without manual refresh.
3. **Photo Evidence Importance:** Emphasize that in industrial manufacturing, photographic evidence of breakdown components and completed repairs prevents dispute between machine operators, plant engineers, and shift managers.

---

## ⚠️ Scope & Implementation Disclosures

- **Manager Maintenance Creation UI:** In PR #57 (under peer review), manager maintenance task creation UI is introduced. In the baseline branch (`chore/day-20-firebase-config-cleanup`), maintenance tasks are created through `MaintenanceService.createMaintenanceTask()` or pre-seeded in the database.
- **Offline Capabilities:** Cloud Firestore provides local document persistence on physical devices; when operating in emulator mode, ensure the local emulator suite remains active during the demonstration.
