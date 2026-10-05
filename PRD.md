# MachAlert — Product Requirements Document (PRD) & Technical Specification

**Project Name:** MachAlert  
**Document Type:** Product Requirements Document (PRD) & Architecture Specification  
**Project Version:** 1.0.0 (Sprint 2 MVP)  
**Target Platform:** Mobile (Android & iOS via Flutter)  
**Backend:** Serverless (Google Firebase — Auth, Cloud Firestore, Firebase Storage)  
**Team Composition:** 3 Beginner Developers (Member 1: UI/UX, Member 2: Firebase, Member 3: Logic & Integration)  
**Development Timeline:** 20 Days (Sprint 2 Academic Project)  
**PR Target:** Minimum 60 Pull Requests (3 members × 20 days)  

---

## Table of Contents
1. [Executive Summary](#1-executive-summary)
2. [Problem Statement & Background](#2-problem-statement--background)
3. [Product Vision](#3-product-vision)
4. [Project Goals & Non-Goals](#4-project-goals--non-goals)
5. [Target Users & Stakeholders](#5-target-users--stakeholders)
6. [User Roles & Permissions Matrix](#6-user-roles--permissions-matrix)
7. [User Personas](#7-user-personas)
8. [Comprehensive User Stories](#8-comprehensive-user-stories)
9. [Functional Requirements](#9-functional-requirements)
10. [Non-Functional Requirements](#10-non-functional-requirements)
11. [MVP Scope vs. Future Scope](#11-mvp-scope-vs-future-scope)
12. [Smart Features & Rule-Based Logic](#12-smart-features--rule-based-logic)
13. [Screen Specifications (All 12 Screens)](#13-screen-specifications-all-12-screens)
14. [Complete User Flows & Navigation Hierarchy](#14-complete-user-flows--navigation-hierarchy)
15. [Cloud Firestore Data Model](#15-cloud-firestore-data-model)
16. [Firebase Architecture & Infrastructure](#16-firebase-architecture--infrastructure)
17. [Flutter Application Architecture & Folder Structure](#17-flutter-application-architecture--folder-structure)
18. [Security & Access Control](#18-security--access-control)
19. [Team Responsibilities & Work Division](#19-team-responsibilities--work-division)
20. [20-Day Development Roadmap](#20-20-day-development-roadmap)
21. [Daily PR Plan (60 Pull Requests Matrix)](#21-daily-pr-plan-60-pull-requests-matrix)
22. [Git & GitHub Collaboration Workflow](#22-git--github-collaboration-workflow)
23. [Testing Strategy](#23-testing-strategy)
24. [Formal Acceptance Criteria (Given-When-Then)](#24-formal-acceptance-criteria-given-when-then)
25. [Definition of Done (DoD)](#25-definition-of-done-dod)
26. [Project Risks & Practical Mitigations](#26-project-risks--practical-mitigations)
27. [Success Metrics & KPI Tracking](#27-success-metrics--kpi-tracking)
28. [Final Demonstration Script & Flow (3–5 Minutes)](#28-final-demonstration-script--flow-35-minutes)
29. [Future Roadmap (v1.1 to v2.0)](#29-future-roadmap-v11-to-v20)
30. [Executive Appendices & Master Checklists](#30-executive-appendices--master-checklists)

---

## 1. Executive Summary

**MachAlert** is a purpose-built, real-time industrial machine fault reporting and maintenance management mobile application developed using **Flutter** and **Google Firebase**. Designed specifically for discrete manufacturing production plants, MachAlert solves the costly operational latency between shop-floor machine breakdown observation and technical intervention.

In conventional factory environments, machine malfunctions, abnormal acoustic signatures, and micro-stoppages are compiled manually or vocalized during end-of-shift review meetings (typically occurring after 8–12 hours of operational lag). By the time maintenance engineers are dispatched, recurring mechanical friction or thermal stress has caused catastrophic failure, halting entire assembly lines.

MachAlert eliminates this blind spot by equipping shop-floor operators with an instant, three-tap digital fault logging tool, delivering real-time reactive dispatch to maintenance technicians and empowering plant managers with holistic visibility over machine health scores and recurring fault alerts. Developed over a 20-day sprint by a 3-developer student team, MachAlert prioritizes software engineering discipline, clean Flutter architecture, robust Cloud Firestore security rules, and an accessible rule-based analytical engine without the premature overhead of complex microservices or unmaintainable machine learning pipelines.

---

## 2. Problem Statement & Background

### 2.1 The Shop-Floor Reality
A mid-sized manufacturing facility operates 4 to 8 production lines, with equipment ranging from CNC milling machines, industrial hydraulic presses, robotic welding arms, to conveyor motors. Currently, the factory tracks machine health via paper logbooks attached to machine bays and verbal handovers at shift-end meetings.

### 2.2 Core Friction Points
1. **Reporting Latency:** Operators who observe overheating, excessive vibration, or pneumatic leakages continue operating machines or wait until their 8-hour shift terminates before logging an entry.
2. **Missing Longitudinal History:** Paper slips get misplaced, soiled by industrial grease, or left unfiled. There is no historical digital timeline for a machine's fault recurrence.
3. **Reactive Firefighting:** Technicians only learn of defects when a line experiences a hard shutdown. Preventive intervention cannot occur.
4. **Unnoticed Recurring Patterns:** A machine that experiences minor thermal throttling three days in a row is treated as three isolated incidents rather than a symptom of bearing degradation.

### 2.3 Operational Transformation

```
CURRENT REACTIVE WORKFLOW (Without MachAlert):
┌────────────────┐     ┌──────────────────┐     ┌─────────────────────┐     ┌─────────────────┐
│ Machine Fault  │ ──> │ Operator Notices │ ──> │ No Immediate Action │ ──> │ Shift-End Review│
│ (e.g. 10:15 AM)│     │ Verbal Mention   │     │ Continues Running   │     │ (06:00 PM)      │
└────────────────┘     └──────────────────┘     └─────────────────────┘     └────────┬────────┘
                                                                                     │
┌────────────────┐     ┌──────────────────┐     ┌─────────────────────┐              │
│ Extended Plant │ <── │ Expensive Repair │ <── │ Catastrophic Failure│ <────────────┘
│ Downtime ($$$) │     │ Parts Replaced   │     │ Line Completely Halted│
└────────────────┘     └──────────────────┘     └─────────────────────┘

PROPOSED PROACTIVE WORKFLOW (With MachAlert):
┌────────────────┐     ┌──────────────────┐     ┌─────────────────────┐     ┌─────────────────┐
│ Machine Fault  │ ──> │ Operator Logs in │ ──> │ Cloud Firestore Sync│ ──> │ Alert Dispatched│
│ (e.g. 10:15 AM)│     │ MachAlert (<30s) │     │ Real-time Stream    │     │ to Technician   │
└────────────────┘     └──────────────────┘     └─────────────────────┘     └────────┬────────┘
                                                                                     │
┌────────────────┐     ┌──────────────────┐     ┌─────────────────────┐              │
│ Minimal Downtime│<── │ Machine Restored │ <── │ Fast Maintenance    │ <────────────┘
│ Target Met     │     │ Digital Log Saved│     │ Note Added in App   │
└────────────────┘     └──────────────────┘     └─────────────────────┘
```

---

## 3. Product Vision

### 3.1 Short-Term Vision (Sprint 2 MVP — Day 1 to 20)
Deliver a rock-solid, beginner-friendly mobile app powered by Flutter and Firebase that digitizes the entire lifecycle of a machine fault:
- **Instantaneous Reporting:** Operators capture photos, severities, and fault categories in under 30 seconds.
- **Role-Based Workspaces:** Dedicated experiences tailored for Operators, Technicians, and Managers.
- **Rule-Based Smart Alarms:** Automatic detection of thermal/vibration danger zones and recurring 7-day fault spikes.
- **Closed-Loop Resolution:** Technicians pick up tasks, log resolution notes, and mark faults resolved.

### 3.2 Long-Term Vision (v2.0 & Beyond)
Evolve MachAlert into an end-to-end industrial **Predictive Maintenance & Telemetry Intelligence Suite**:
- Wireless Bluetooth Low Energy (BLE) and MQTT edge sensor integrations for real-time automated telemetry.
- On-device edge ML models predicting Remaining Useful Life (RUL) of machine bearings.
- Automated parts procurement integration with enterprise ERP/SAP backends.

---

## 4. Project Goals & Non-Goals

### 4.1 Business & Academic Goals
- **G-1 (Speed of Capture):** Reduce fault reporting time from hours to under 45 seconds.
- **G-2 (Real-Time Propagation):** Propagate a logged fault to technician and manager dashboards within 1.5 seconds via Firestore real-time snapshots.
- **G-3 (Digital Traceability):** Maintain a 100% digital audit trail of machine faults, technician notes, and timestamps.
- **G-4 (Delivery Cadence):** Successfully execute a 20-day agile sprint with exactly 3 beginner developers producing at least 1 verified Pull Request per person per day (Total ≥ 60 PRs).
- **G-5 (Clean Software Engineering):** Build a modular Flutter project adhering to MVVM/Service-Repository patterns, avoiding bloated god-widgets.

### 4.2 Non-Goals (Strictly Out of Scope for 20-Day MVP)
- **NG-1: No Custom Backend Servers.** No Node.js, Express, NestJS, Django, or custom REST servers. The project relies purely on client-side FlutterFire integration.
- **NG-2: No Alternative Databases.** No MongoDB, PostgreSQL, SQLite, or Redis. Cloud Firestore is the sole database.
- **NG-3: No Complex Machine Learning / AI Models.** No TensorFlow Lite, Python scikit-learn models, or neural networks. Smart features are strictly deterministic, rule-based heuristics.
- **NG-4: No Real Physical IoT Hardware.** No soldering, Arduino, ESP32, or physical sensor wiring. Telemetry (temperature/vibration) is simulated or entered via realistic shop-floor inspection inputs.
- **NG-5: No Push Notification Daemons (FCM Background Services).** Due to OS-level background service complexity and beginner developer timelines, notifications are handled as real-time in-app alert streams via Cloud Firestore listeners.
- **NG-6: No Payment Gateways or ERP Integrations.** No SAP, Oracle, or payment SDKs.

---

## 5. Target Users & Stakeholders

| User Group | Workplace Context | Technological Familiarity | Primary Pain Point |
|---|---|---|---|
| **Shop-Floor Operators** | Physically stationed along the assembly line. Often wearing light industrial gloves; noisy environment. | Moderate (uses everyday smartphone apps like WhatsApp). | Forms are too slow; cannot remember fault terminology; no feedback if reports were seen. |
| **Maintenance Technicians** | Mobile across the plant floor, carrying toolkits, inspecting electrical and hydraulic bays. | Moderate to High (comfortable with digital instruments). | Dispatched without diagnostic context; cannot easily see machine maintenance history on-site. |
| **Plant / Production Managers** | Desk-based in plant office or walking factory floors during supervisory audits. | High (uses ERPs, spreadsheets, dashboards). | Lacks high-level visibility; notices downtime patterns only after production targets are missed. |

---

## 6. User Roles & Permissions Matrix

MachAlert enforces strict Role-Based Access Control (RBAC) across three distinct roles: `operator`, `technician`, and `manager`.

| Feature / Action | Operator | Technician | Manager |
|---|---|---|---|
| **User Sign Up & Login** | ✅ Full Access | ✅ Full Access | ✅ Full Access |
| **View Machine List & Specs** | ✅ Full Access | ✅ Full Access | ✅ Full Access |
| **Add / Edit / Archive Machines** | ❌ Denied | ❌ Denied | ✅ Full Access |
| **Report New Machine Fault** | ✅ Primary Action | ✅ Permitted | ✅ Permitted |
| **Upload Fault Photos** | ✅ Permitted | ✅ Permitted | ✅ Permitted |
| **View Machine Fault History** | ✅ Read Only | ✅ Read Only | ✅ Read Only |
| **View Assigned Maintenance Tasks** | ❌ Denied | ✅ Primary Action | ✅ Full View |
| **Update Task Status (In Progress/Done)** | ❌ Denied | ✅ Permitted | ✅ Permitted |
| **Add Maintenance Resolution Notes** | ❌ Denied | ✅ Permitted | ✅ Permitted |
| **Assign Technician to Fault** | ❌ Denied | ❌ Denied | ✅ Primary Action |
| **View Smart Recurring Fault Alerts** | ⚠️ View Indicator | ⚠️ View Indicator | ✅ Full Analytics |
| **Delete Fault / Maintenance Records** | ❌ Denied | ❌ Denied | ✅ Admin Only |

---

## 7. User Personas

### Persona 1: Rajesh Sharma — Line Operator
- **Age:** 32 | **Experience:** 6 years on Assembly Line 2 (Hydraulic Press Operator)
- **Environment:** Noisy shop floor, high-pressure shift targets.
- **Needs:** Needs a mobile screen with big buttons, simple dropdowns, and instant camera attachment. Wants confirmation that his report reached the maintenance team so he is not blamed for machine downtime.
- **Quote:** *"If the press starts vibrating violently at 11 AM, I shouldn't have to wait until 5 PM to write it on a clipboard."*

### Persona 2: Anand Patel — Senior Maintenance Technician
- **Age:** 41 | **Experience:** 14 years Industrial Electrical & Mechanical Maintenance
- **Environment:** Moving constantly across 3 factory bays with diagnostic tools.
- **Needs:** Clear list of open tasks sorted by priority (Critical first). Needs machine location, fault photo, and past repair history before cracking open a control panel.
- **Quote:** *"Show me what failed, when it failed, and what the guy before me did. That saves me an hour of guesswork."*

### Persona 3: Neha Roy — Factory Operations Manager
- **Age:** 37 | **Experience:** 10 years Operations & Industrial Engineering
- **Environment:** Plant office, reviewing shift KPIs, line OEE (Overall Equipment Effectiveness).
- **Needs:** Overview of all machines color-coded by health status. Automated alerts whenever a machine fails repeatedly in 7 days so she can schedule overhaul during planned maintenance windows.
- **Quote:** *"I don't just want to fix broken machines; I want to know which machine is eating our production margins."*

---

## 8. Comprehensive User Stories

### Epic 1: Authentication & Onboarding
- **US-1.1:** As a new factory employee, I want to register using my email, full name, and assigned role so that I can access features specific to my job.
- **US-1.2:** As an employee, I want to securely log into MachAlert using my credentials so that my activity is authenticated and attributed to me.
- **US-1.3:** As an active user, I want the app to remember my login session across app restarts so that I do not have to type my password on the factory floor every morning.
- **US-1.4:** As a user, I want to log out easily from my profile so that other workers cannot misuse my account on shared plant tablets.

### Epic 2: Machine Exploration & Monitoring
- **US-2.1:** As an operator or technician, I want to browse a complete directory of factory machines with search and line filtering so that I can quickly find the machine I am standing next to.
- **US-2.2:** As any user, I want to view a machine’s real-time operational status (Operational, Warning, Critical, Under Maintenance) indicated by intuitive color badges.
- **US-2.3:** As any user, I want to inspect a machine's detailed profile, including its production line, current temperature, vibration index, calculated health score, and past fault log.

### Epic 3: Fault Reporting & Media Upload
- **US-3.1:** As an operator, I want to report a machine fault by selecting the machine, fault type, and severity level so that the defect is clearly classified.
- **US-3.2:** As an operator, I want to provide a concise text description of the abnormal symptom (e.g. "Clanking noise during stroke").
- **US-3.3:** As an operator, I want to take a live photo or upload an image of the physical defect so that the technician sees the issue before arriving.
- **US-3.4:** As an operator, I want to view a list of all faults I have submitted, complete with current resolution status.

### Epic 4: Maintenance Workflow & Resolution
- **US-4.1:** As a plant manager, I want to review incoming open faults and assign them to a qualified technician with an assigned priority.
- **US-4.2:** As a technician, I want to see my dedicated list of assigned maintenance tasks sorted by priority (Critical > High > Medium > Low).
- **US-4.3:** As a technician, I want to transition a task from `Pending` to `In Progress` when I begin work, and to `Resolved` once repairs conclude.
- **US-4.4:** As a technician, I want to enter mandatory repair notes describing what was fixed (e.g. "Replaced worn synthetic seal") before closing the task.

### Epic 5: Smart Risk Detection & Factory Health
- **US-5.1:** As a manager, I want the system to automatically compute a Health Score (0–100%) for each machine based on telemetry and recent faults.
- **US-5.2:** As a manager, I want the system to flag a "Recurring Fault Alert" if the same machine suffers the same category of fault 3 or more times within 7 days.
- **US-5.3:** As any user, I want to view an in-app Alert Feed highlighting warning thresholds and urgent machine conditions.

---

## 9. Functional Requirements

### 9.1 Authentication & Profile (FR-01 to FR-05)
- **FR-01 [P0]:** System shall authenticate users via Firebase Authentication using email and password.
- **FR-02 [P0]:** System shall enforce email format validation and minimum 6-character password constraint.
- **FR-03 [P0]:** During registration, system shall write a user document to `users/{userId}` containing `name`, `email`, `role`, and `createdAt`.
- **FR-04 [P0]:** System shall persist authentication state using Firebase Auth persistent token cache.
- **FR-05 [P1]:** System shall provide a Profile screen displaying user details, role badge, and a secure Logout action.

### 9.2 Machine Inventory Management (FR-06 to FR-10)
- **FR-06 [P0]:** System shall fetch and render a real-time list of machines from the `machines` Firestore collection.
- **FR-07 [P0]:** System shall display machine cards containing: Machine Name, Line Number, Operational Status Badge, Temperature, Vibration, and Health Score.
- **FR-08 [P1]:** System shall support client-side text search (filtering by machine name/code) and tab filtering (by Production Line: Line 1, Line 2, Line 3).
- **FR-09 [P0]:** System shall display a comprehensive Machine Details screen showing all technical specifications, telemetry chips, and a sub-list of recent faults.
- **FR-10 [P1]:** System shall allow Manager accounts to add new machines or update operational parameters.

### 9.3 Fault Reporting & Media Integration (FR-11 to FR-16)
- **FR-11 [P0]:** System shall provide a Report Fault form with fields: Machine Picker, Fault Category (Mechanical, Electrical, Hydraulic, Thermal, Pneumatic, Other), Severity (Low, Medium, High, Critical), Description (text), and Image (optional).
- **FR-12 [P0]:** System shall validate all required fields before enabling report submission.
- **FR-13 [P1]:** System shall allow capturing photos via camera or selecting from gallery using the `image_picker` package.
- **FR-14 [P1]:** System shall upload captured fault images to Firebase Storage under `fault_images/{timestamp}_{filename}.jpg` and store the resulting download URL in the fault document.
- **FR-15 [P0]:** System shall write the fault record to `faults/{faultId}` with a server timestamp (`FieldValue.serverTimestamp()`).
- **FR-16 [P0]:** System shall automatically transition the associated machine's status to `Warning` or `Critical` upon submission of High/Critical faults.

### 9.4 Maintenance Dispatch & Resolution (FR-17 to FR-21)
- **FR-17 [P0]:** System shall create a corresponding `maintenance` document whenever a fault is logged or dispatched.
- **FR-18 [P0]:** System shall provide a filtered Maintenance screen where technicians view tasks assigned to them, and managers view all tasks across the plant.
- **FR-19 [P0]:** System shall allow technicians to transition task status: `Pending` ➔ `In Progress` ➔ `Resolved`.
- **FR-20 [P0]:** System shall require technicians to input descriptive completion notes prior to marking any maintenance task as `Resolved`.
- **FR-21 [P1]:** When a maintenance task is marked `Resolved`, the system shall update the linked fault status and automatically recalculate the machine's operational status.

### 9.5 Smart Rule Engine & Alerts (FR-22 to FR-25)
- **FR-22 [P0]:** System shall compute dynamic Machine Health Scores using a deterministic penalty algorithm based on temperature, vibration, and active faults.
- **FR-23 [P1]:** System shall evaluate recurring fault heuristics: If a machine logs ≥ 3 faults of identical category within the preceding 7 days, generate a `Recurring Fault Detected` alert.
- **FR-24 [P1]:** System shall maintain an `alerts` collection in Firestore populated by telemetry threshold breaches and recurring fault detections.
- **FR-25 [P1]:** System shall provide an Alert Feed screen showing unacknowledged factory warnings with high-contrast priority styling.

---

## 10. Non-Functional Requirements

### 10.1 Performance & Responsiveness
- **NFR-01 (Launch Time):** Cold boot to interactive Splash/Login screen under 2.5 seconds on mid-range Android hardware.
- **NFR-02 (Data Synchronization):** Changes to Firestore collections shall reflect on subscribed screens in under 1.5 seconds over standard 4G/Wi-Fi.
- **NFR-03 (Frame Rate):** Maintain 60 fps for all scrolling lists (Machine List, Fault History) using optimized `ListView.builder` widgets.

### 10.2 Security & Data Integrity
- **NFR-04 (Token Integrity):** All database read/write requests must be accompanied by a valid Firebase Authentication JSON Web Token.
- **NFR-05 (Rule-Based Validation):** Cloud Firestore and Firebase Storage security rules must enforce role permissions at the database level, preventing malicious client writes.
- **NFR-06 (Credential Secrecy):** No raw credentials or sensitive Firebase service account private keys committed to version control.

### 10.3 Usability & Industrial Ergonomics
- **NFR-07 (Touch Target Sizing):** All interactive buttons, radio options, and list tiles must possess minimum touch targets of 48×48 dp for easy gloved-finger tapping.
- **NFR-08 (High-Contrast Status Indicators):** Statuses must be distinguished by both color and textual badges (e.g. Green + "Operational", Amber + "Warning", Red + "Critical") to support color-blind operators.
- **NFR-09 (Feedback Loops):** Every asynchronous operation (login, submit, update) must exhibit explicit loading spinners (`CircularProgressIndicator`) and user-facing completion SnackBars.

### 10.4 Maintainability & Code Hygiene
- **NFR-10 (Clean Architecture):** Codebase must separate Presentation (`screens`, `widgets`), Business Logic (`providers`/`controllers`), Data Layer (`models`), and External Services (`services`).
- **NFR-11 (Zero Warnings):** Codebase must adhere to standard `flutter_lints` rules without lingering linter warnings or dead code.

---

## 11. MVP Scope vs. Future Scope

```
┌────────────────────────────────────────────────────────────────────────┐
│                        MACHALERT SCOPE TAXONOMY                         │
├──────────────────────────────────┬─────────────────────────────────────┤
│      IN-SCOPE FOR 20-DAY MVP     │      FUTURE ROADMAP (POST-MVP)      │
├──────────────────────────────────┼─────────────────────────────────────┤
│ • Email/Password Auth (RBAC)     │ • Multi-factor & Biometric Login    │
│ • Machine Inventory & Specs      │ • Edge IoT Sensor Telemetry (MQTT)  │
│ • Manual / Simulated Telemetry   │ • BLE Gateway Auto-Sync             │
│ • 30-Second Fault Reporting Form │ • Machine Learning Predictive RUL   │
│ • Camera / Gallery Photo Upload  │ • Background Push Notifications(FCM)│
│ • Cloud Firestore Real-Time Sync │ • Exportable PDF Compliance Reports │
│ • Firebase Storage Media Hosting │ • Spare Parts ERP Inventory Sync    │
│ • Technician Dispatch & Notes    │ • Audio FFT Acoustic Defect Model   │
│ • Deterministic Health Scores    │ • Multi-Plant Enterprise Hierarchy  │
│ • Rule-Based 7-Day Recurrence    │ • Offline-First P2P Sync (Mesh)     │
└──────────────────────────────────┴─────────────────────────────────────┘
```

---

## 12. Smart Features & Rule-Based Logic

To deliver actionable intelligence without the complexity and instability of training machine learning models within a 20-day beginner sprint, MachAlert incorporates **two deterministic, production-grade rule algorithms**.

### 12.1 Machine Health Score Algorithm
Every machine document calculates a real-time `healthScore` (integer from 0 to 100) whenever telemetry values or fault states update.

$$\text{HealthScore} = \max\Big(0, \, 100 - (\text{TempPenalty} + \text{VibPenalty} + \text{FaultPenalty})\Big)$$

#### Penalty Rules:
1. **Temperature Penalty ($T$ in °C):**
   - If $T \le 70^\circ\text{C}$: Penalty = $0$ (Normal)
   - If $70^\circ\text{C} < T \le 85^\circ\text{C}$: Penalty = $15$ (Elevated)
   - If $T > 85^\circ\text{C}$: Penalty = $35$ (Overheating Risk)
2. **Vibration Index Penalty ($V$ in mm/s RMS):**
   - If $V \le 3.5\text{ mm/s}$: Penalty = $0$ (Smooth)
   - If $3.5 < V \le 6.5\text{ mm/s}$: Penalty = $15$ (Moderate Wear)
   - If $V > 6.5\text{ mm/s}$: Penalty = $35$ (Severe Mechanical Imbalance)
3. **Active Open Fault Penalty:**
   - Active Critical Fault: Penalty = $40$
   - Active High Severity Fault: Penalty = $25$
   - Active Medium Severity Fault: Penalty = $10$
   - Active Low Severity Fault: Penalty = $5$

#### Resulting Operational Status Classification:
- **Health Score 80 – 100:** `Operational` (Green)
- **Health Score 50 – 79:** `Warning` (Amber)
- **Health Score 0 – 49:** `Critical` (Red)
- If an active maintenance task is currently marked `In Progress`: Status overrides to `Under Maintenance` (Blue).

### 12.2 Recurring Fault Detection Algorithm
A major plant pain point is recurring micro-breakdowns that get addressed patch-by-patch without identifying systemic fatigue.

```text
ALGORITHM: Recurring Fault Detector
INPUT: machineId, candidateFaultType, referenceTimestamp (Now)
WINDOW: 7 Days (referenceTimestamp - 7 days)
THRESHOLD: >= 3 occurrences

STEP 1: Query Firestore collection 'faults'
        WHERE machineId == currentMachineId
        AND type == candidateFaultType
        AND createdAt >= (Now - 7 Days)

STEP 2: Count returned documents.
STEP 3: IF count >= 3:
            CREATE document in collection 'alerts':
            - alertId: auto-generated
            - machineId: currentMachineId
            - type: "RECURRING_FAULT"
            - severity: "CRITICAL"
            - message: "Machine [Name] has logged 3+ [Type] faults in the past 7 days. Immediate engineering inspection advised."
            - createdAt: ServerTimestamp
            - acknowledged: false
        ELSE:
            No alert generated.
```

---

## 13. Screen Specifications (All 12 Screens)

Each of the 12 screens is specified with complete UI requirements, behavioral state handling, and backend contracts.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        MACHALERT SCREEN INVENTORY                      │
├────────────────────────────────┬───────────────────────────────────────┤
│ 1. Splash Screen               │ 7. Report Fault Screen                │
│ 2. Login Screen                │ 8. Fault History Screen               │
│ 3. Sign Up Screen              │ 9. Maintenance Tasks Screen           │
│ 4. Dashboard Screen (Role-Based│ 10. Maintenance Detail & Action Screen│
│ 5. Machine List Screen         │ 11. Notifications / Smart Alert Screen│
│ 6. Machine Details Screen      │ 12. Profile & Settings Screen         │
└────────────────────────────────┴───────────────────────────────────────┘
```

---

### Screen 1: Splash Screen
- **Purpose:** Brand landing screen, initializes Firebase core SDKs, checks cached user authentication state, routes user accordingly.
- **Target User:** All users.
- **UI Components:** App Logo (MachAlert industrial gear/shield icon), Animated Fade-in, App Title, Loading Spinner, Version badge (`v1.0.0`).
- **Data Displayed:** None.
- **User Actions:** None (automatic progression after 1.5 seconds).
- **Navigation:**
  - If user is authenticated: Route to `DashboardScreen` (loading user role from Firestore).
  - If user is not authenticated: Route to `LoginScreen`.
- **Firebase Interaction:** `FirebaseAuth.instance.authStateChanges()`.
- **Validation:** Verify local auth token validity.
- **Loading State:** Centered smooth indeterminate progress indicator.
- **Error State:** Network connection alert banner with a "Retry" button if Firebase fails to initialize.
- **Empty State:** N/A.

---

### Screen 2: Login Screen
- **Purpose:** Authenticate registered factory personnel.
- **Target User:** All existing users.
- **UI Components:** Header illustration, Email text input (`keyboardType: TextInputType.emailAddress`), Password text input with visibility toggle icon button, "Sign In" primary button, "Don't have an account? Sign Up" navigation link.
- **Data Displayed:** Form input fields and validation feedback text.
- **User Actions:** Enter credentials, toggle password visibility, press Sign In, navigate to Sign Up.
- **Navigation:** Upon successful auth: fetch user doc from `users/{uid}` and route to `DashboardScreen`.
- **Firebase Interaction:** `FirebaseAuth.instance.signInWithEmailAndPassword()`.
- **Validation:**
  - Email: Non-empty, valid regex email format.
  - Password: Minimum 6 characters, non-empty.
- **Loading State:** "Sign In" button displays embedded `CircularProgressIndicator`; inputs disabled.
- **Error State:** Floating red SnackBar with human-readable error (e.g. "User not found", "Incorrect password", "Network timeout").
- **Empty State:** Clean, pristine input fields with clear placeholder text.

---

### Screen 3: Sign Up Screen
- **Purpose:** Onboard new factory team members with role designation.
- **Target User:** Unregistered operators, technicians, or managers.
- **UI Components:** Full Name input field, Email input field, Password input field, Confirm Password input field, Role Dropdown Selector (`Operator`, `Technician`, `Manager`), "Register Account" button, "Already registered? Login" link.
- **Data Displayed:** Role selection options with brief descriptions.
- **User Actions:** Fill personal information, select role, submit registration.
- **Navigation:** On success, redirect to `DashboardScreen` with active user session.
- **Firebase Interaction:**
  1. `FirebaseAuth.instance.createUserWithEmailAndPassword()`
  2. `FirebaseFirestore.instance.collection('users').doc(user.uid).set({...})`
- **Validation:**
  - Name: Minimum 2 characters.
  - Email: Valid email format.
  - Password: Minimum 6 characters.
  - Confirm Password: Must match Password field exactly.
  - Role: Must select one valid role.
- **Loading State:** Submit button disabled with spinning progress indicator.
- **Error State:** SnackBar message ("Email already in use", "Weak password").
- **Empty State:** Clean fields, role defaults to `Operator`.

---

### Screen 4: Role-Based Dashboard Screen
- **Purpose:** Central operational command screen, dynamically customized according to the authenticated user's role.
- **Target User:** Operators, Technicians, Managers.
- **UI Components:**
  - Top AppBar: Greeting banner ("Welcome back, [Name]"), role badge chip, notification bell with unread badge counter.
  - High-Level Metric Cards:
    - *For Operator:* "Total Machines Online", "My Active Reports", "Quick Report Fault Action Button".
    - *For Technician:* "My Assigned Tasks", "Pending Interventions", "Critical Breakdowns".
    - *For Manager:* "Total Plant Machines", "Machines with Warnings/Critical", "Open Faults", "Recurring Fault Alerts".
  - Quick Action Shortcuts (e.g., "Report Fault", "Machine Directory", "Task List").
  - Recent Activity Feed: List of the last 3 plant events.
- **Data Displayed:** Real-time metrics queried from `machines`, `faults`, and `maintenance`.
- **User Actions:** Tap metric cards to drill down into filtered lists; tap quick actions; tap notification icon.
- **Navigation:** Routes to `MachineListScreen`, `ReportFaultScreen`, `MaintenanceTasksScreen`, or `AlertsScreen`.
- **Firebase Interaction:** Real-time stream snapshots from `machines`, `faults`, and `alerts` collections.
- **Validation:** Role security check on widget build.
- **Loading State:** Shimmer placeholder skeleton cards.
- **Error State:** Error card with "Could not load factory metrics. Tap to reload."
- **Empty State:** "No active plant events currently recorded."

---

### Screen 5: Machine List Screen
- **Purpose:** Catalog of all factory production machines across lines.
- **Target User:** All roles.
- **UI Components:**
  - Search bar (`TextField` with clear icon).
  - Production Line Filter Tabs (All, Line 1, Line 2, Line 3).
  - Machine Card List: Machine Name, Line Number, Model, Health Score Gauge/Bar, Status Badge (Green/Amber/Red/Blue), Current Temperature and Vibration indicators.
- **Data Displayed:** Stream of documents from `machines`.
- **User Actions:** Type query in search bar, tap line filter tabs, tap machine card to open details.
- **Navigation:** Tap machine card ➔ navigates to `MachineDetailScreen(machineId: id)`.
- **Firebase Interaction:** `FirebaseFirestore.instance.collection('machines').snapshots()`.
- **Validation:** Live filtering ignores case sensitivity.
- **Loading State:** Vertical list of 4 shimmer skeleton cards.
- **Error State:** "Failed to load machines. Check network connection." with retry button.
- **Empty State:** "No machines found matching '[query]'." with a reset filter button.

---

### Screen 6: Machine Details Screen
- **Purpose:** In-depth technical profile and history of an individual machine.
- **Target User:** All roles (especially Technicians and Managers).
- **UI Components:**
  - Header: Machine Name, Serial Number, Line Number, Installation Date.
  - Health Score Gauge: Circular indicator (0–100%) color-coded.
  - Telemetry Dashboard Cards:
    - Temperature card (e.g. `78°C` with status icon).
    - Vibration card (e.g. `4.2 mm/s` with status icon).
  - "Report Fault for this Machine" floating or fixed CTA button.
  - Recent Fault History Tab / Section: Expandable list of faults associated with this machine.
- **Data Displayed:** Real-time machine doc and nested/queried fault history docs.
- **User Actions:** Inspect telemetry, click "Report Fault" (pre-populates machine selector), tap previous fault to view resolution details.
- **Navigation:**
  - Back arrow to `MachineListScreen`.
  - Tap "Report Fault" ➔ navigates to `ReportFaultScreen(preselectedMachineId: id)`.
- **Firebase Interaction:**
  - `machines/{machineId}` stream.
  - `faults.where('machineId', isEqualTo: machineId).orderBy('createdAt', descending: true)` stream.
- **Validation:** Handle missing telemetry fields gracefully with fallback values ("N/A").
- **Loading State:** Centered progress indicator for screen body.
- **Error State:** "Machine not found or has been decommissioned."
- **Empty State (for faults):** "No faults ever recorded for this machine. Operating in optimal condition."

---

### Screen 7: Report Fault Screen
- **Purpose:** High-speed capture of machine issues and physical symptoms.
- **Target User:** Primary tool for Operators; accessible to all roles.
- **UI Components:**
  - Machine Dropdown (pre-selected if opened from Machine Details).
  - Fault Category Selector (Chips: Mechanical, Electrical, Hydraulic, Thermal, Pneumatic, Other).
  - Severity Radio Selector / Segmented Control (Low, Medium, High, Critical).
  - Symptom Description (`TextField`, multi-line, 4 lines max, with placeholder).
  - Image Attachment Box: Camera icon button, Gallery icon button, image preview thumbnail with a red "Remove" tap target.
  - "Submit Fault Report" large primary button.
- **Data Displayed:** List of machines for dropdown; selected image preview.
- **User Actions:** Select machine, pick fault type, choose severity, type description, snap photo, submit report.
- **Navigation:** Upon successful submission: display success dialog/SnackBar and pop back to `DashboardScreen` or `FaultHistoryScreen`.
- **Firebase Interaction:**
  1. If photo attached: Upload file bytes to `FirebaseStorage.instance.ref('fault_images/...')`.
  2. Write new document to `faults` collection.
  3. If severity is High or Critical: update linked machine's status to `Warning` or `Critical`.
  4. Trigger rule-based recurring fault query.
- **Validation:**
  - Machine selection is mandatory.
  - Fault Category is mandatory.
  - Description must be at least 5 characters.
  - Severity is mandatory.
- **Loading State:** Modal barrier overlay with progress spinner and message "Uploading fault report and media...".
- **Error State:** SnackBar alert detailing upload failure with "Retry" option without clearing form inputs.
- **Empty State:** Clean, pristine input form with default severity `Medium`.

---

### Screen 8: Fault History Screen
- **Purpose:** Comprehensive searchable log of all reported faults across the factory.
- **Target User:** All roles.
- **UI Components:**
  - Filter chips: All, Open/Pending, In Progress, Resolved.
  - Fault Card List: Machine Name, Fault Type Chip, Severity Indicator Badge, Reporting Operator Name, Relative Timestamp (e.g. "25 mins ago"), Status Badge (`Open`, `In Progress`, `Resolved`), Image thumbnail icon if media attached.
- **Data Displayed:** Queried list from `faults` collection.
- **User Actions:** Tap filter chips; tap fault card to view details or full-size photo in dialog.
- **Navigation:** Tap card ➔ opens fault inspection modal or navigates to `MaintenanceDetailScreen` if technician/manager.
- **Firebase Interaction:** `FirebaseFirestore.instance.collection('faults').orderBy('createdAt', descending: true).snapshots()`.
- **Validation:** Automatic timestamp formatting using `intl` package (e.g. `DateFormat.yMMMd().add_jm()`).
- **Loading State:** Shimmer list placeholder.
- **Error State:** "Unable to retrieve fault history."
- **Empty State:** "No faults match the selected filter."

---

### Screen 9: Maintenance Tasks Screen
- **Purpose:** Operational task management for scheduled and reactive maintenance.
- **Target User:** Technicians (primary) and Managers.
- **UI Components:**
  - Status Switcher Tabs: "Assigned to Me" vs "All Plant Tasks" (Managers only).
  - Filter Tabs: `Pending`, `In Progress`, `Resolved`.
  - Maintenance Task Card: Machine Name & Location, Fault Summary, Priority Chip (Critical, High, Medium, Low), Assigned Technician Name, Task Status Badge, "Update Status" button.
- **Data Displayed:** Maintenance task documents joined with machine and fault data.
- **User Actions:** Filter tasks, tap card to begin maintenance intervention.
- **Navigation:** Tap card ➔ navigates to `MaintenanceDetailScreen(taskId: id)`.
- **Firebase Interaction:**
  - For Technician: `maintenance.where('technicianId', isEqualTo: currentUserId)`.
  - For Manager: `maintenance.snapshots()`.
- **Validation:** Restrict task status modification to assigned technician or manager.
- **Loading State:** Standard list loading indicator.
- **Error State:** "Failed to load maintenance schedule."
- **Empty State:** "Great job! You have zero open maintenance tasks assigned."

---

### Screen 10: Maintenance Details & Action Screen
- **Purpose:** Execution workspace for technicians to document repairs and resolve issues.
- **Target User:** Technicians and Managers.
- **UI Components:**
  - Header: Machine Name, Bay Location, Initial Fault Description, Severity.
  - Attached Photo preview with tap-to-enlarge full-screen view.
  - Current Status Timeline: Visual stepper showing `Pending` ➔ `In Progress` ➔ `Resolved`.
  - Status Action Buttons: "Start Repair" (sets to `In Progress`), "Mark Resolved" (triggers completion modal).
  - Technician Notes Field: Mandatory multi-line input detailing corrective actions taken (e.g., "Cleaned hydraulic filter, replaced O-ring, verified pressure stability").
  - Parts Replaced (optional text input).
- **Data Displayed:** Detailed task info from `maintenance/{id}` and referenced `faults/{faultId}`.
- **User Actions:** Update task state, enter maintenance notes, confirm resolution.
- **Navigation:** Upon marking resolved: show celebratory completion toast and return to `MaintenanceTasksScreen`.
- **Firebase Interaction:**
  - `maintenance/{id}.update({'status': 'Resolved', 'notes': notes, 'resolvedAt': ServerTimestamp})`.
  - `faults/{faultId}.update({'status': 'Resolved'})`.
  - `machines/{machineId}.update({'status': 'Operational'})`.
- **Validation:**
  - Cannot mark `Resolved` without entering at least 10 characters in the resolution notes.
- **Loading State:** Button progress indicators during status writes.
- **Error State:** "Failed to update maintenance task. Verify permissions."
- **Empty State:** N/A.

---

### Screen 11: Notifications & Smart Alerts Screen
- **Purpose:** Dedicated feed for rule-based machine warnings, recurring fault detections, and critical breakdown broadcasts.
- **Target User:** All users (especially Managers).
- **UI Components:**
  - Alert Card List with high-contrast priority banners.
  - Alert Type Icon: Flame/Warning icon for Overheating, Vibration icon for Mechanical Imbalance, Repeat icon for Recurring Faults.
  - Timestamp, Machine Name, and Alert Description.
  - "Acknowledge" button (clears warning badge).
- **Data Displayed:** Real-time stream from `alerts` collection.
- **User Actions:** Tap alert to jump directly to the implicated machine's details screen; tap "Acknowledge" to dismiss.
- **Navigation:** Tap alert ➔ navigates to `MachineDetailScreen(machineId)`.
- **Firebase Interaction:** `alerts.orderBy('createdAt', descending: true).snapshots()`.
- **Validation:** Visual indication for acknowledged vs unacknowledged alerts.
- **Loading State:** Skeleton alert banners.
- **Error State:** "Failed to fetch plant alerts."
- **Empty State:** "Factory floor is running smoothly. Zero active alerts."

---

### Screen 12: Profile & Settings Screen
- **Purpose:** User account verification, role inspection, and application session control.
- **Target User:** All users.
- **UI Components:**
  - Profile Avatar (initials placeholder with industrial slate-blue accent).
  - User Full Name text.
  - Email Address text.
  - Role Chip Badge (e.g., "OPERATOR" in green, "TECHNICIAN" in blue, "MANAGER" in purple).
  - App Preferences: "About MachAlert", "Terms of Use", "Development Team Credits".
  - "Log Out" destructive button with confirmation dialog.
- **Data Displayed:** User profile data from `users/{userId}`.
- **User Actions:** Review account details, initiate logout.
- **Navigation:** Logout clears Firebase session and replaces route with `LoginScreen`.
- **Firebase Interaction:** `FirebaseAuth.instance.signOut()`.
- **Validation:** Confirmation dialog on logout prevents accidental tap ("Are you sure you want to log out?").
- **Loading State:** Centered spinner if profile is fetching.
- **Error State:** "Unable to retrieve profile."
- **Empty State:** N/A.

---

## 14. Complete User Flows & Navigation Hierarchy

### 14.1 Master Navigation Hierarchy
MachAlert utilizes a Flutter `BottomNavigationBar` structure persistent across the primary authenticated experience, tailored per role:

```text
                               ┌──────────────────────────┐
                               │       SPLASH SCREEN      │
                               └────────────┬─────────────┘
                                            │
                           ┌────────────────┴────────────────┐
                           ▼                                 ▼
                     [Authenticated]                  [Unauthenticated]
                           │                                 │
                           │                          ┌──────┴──────┐
                           │                          ▼             ▼
                           │                    LOGIN SCREEN   SIGNUP SCREEN
                           │                          │             │
                           │                          └──────┬──────┘
                           │                                 │
                           └─────────────────┬───────────────┘
                                             │
                                             ▼
                               ┌───────────────────────────┐
                               │   ROLE-BASED DASHBOARD    │
                               └─────────────┬─────────────┘
                                             │
      ┌──────────────────────┬───────────────┼───────────────┬──────────────────────┐
      ▼                      ▼               ▼               ▼                      ▼
┌───────────┐          ┌───────────┐   ┌───────────┐   ┌───────────┐          ┌───────────┐
│ Machines  │          │  Report   │   │   Fault   │   │Maintenance│          │  Alerts   │
│Directory  │          │   Fault   │   │  History  │   │   Tasks   │          │   Feed    │
└─────┬─────┘          └─────┬─────┘   └───────────┘   └─────┬─────┘          └───────────┘
      │                      │                               │
      ▼                      ▼                               ▼
┌───────────┐          ┌───────────┐                   ┌───────────┐
│  Machine  │          │  Success  │                   │Maintenance│
│  Details  │          │Feedback UI│                   │  Action   │
└───────────┘          └───────────┘                   └───────────┘
```

### 14.2 Role-Specific Bottom Navigation Tabs
- **Operator:** Dashboard ➔ Machines ➔ Report Fault ➔ Fault History ➔ Profile
- **Technician:** Dashboard ➔ Tasks ➔ Machines ➔ Fault History ➔ Profile
- **Manager:** Dashboard ➔ Machines ➔ All Tasks ➔ Alerts ➔ Profile

---

## 15. Cloud Firestore Data Model

A clean, predictable, and normalized schema designed for beginner developers to avoid deep subcollection queries while maintaining relational integrity.

```text
FIRESTORE ROOT COLLECTIONS:
├── users/             [User identity, credentials metadata, and role assignment]
├── machines/          [Physical equipment inventory, line, telemetry, and health score]
├── faults/            [Logged breakdown incidents, severity, descriptions, photos]
├── maintenance/       [Intervention dispatches, technician notes, status lifecycle]
└── alerts/            [Rule-based thermal, vibration, and recurring fault warnings]
```

---

### Collection 1: `users`
- **Path:** `/users/{userId}` (where `userId` == `FirebaseAuth.currentUser.uid`)
- **Description:** Stores identity and role access control profiles.

| Field | Type | Required | Description | Example |
|---|---|---|---|---|
| `userId` | String | Yes | Firebase Auth UID | `"u7Xk91pL0mQz"` |
| `name` | String | Yes | Full employee name | `"Rajesh Sharma"` |
| `email` | String | Yes | Registered email | `"rajesh.sharma@factory.com"` |
| `role` | String | Yes | Access tier: `operator`, `technician`, `manager` | `"operator"` |
| `createdAt` | Timestamp | Yes | Account creation timestamp | `ServerTimestamp` |

```json
// Example Document: users/u7Xk91pL0mQz
{
  "userId": "u7Xk91pL0mQz",
  "name": "Rajesh Sharma",
  "email": "rajesh.sharma@factory.com",
  "role": "operator",
  "createdAt": "2026-10-06T08:30:00Z"
}
```

---

### Collection 2: `machines`
- **Path:** `/machines/{machineId}`
- **Description:** Industrial assets monitored by MachAlert.

| Field | Type | Required | Description | Example |
|---|---|---|---|---|
| `machineId` | String | Yes | Unique equipment code | `"MCH-LINE1-CNC03"` |
| `name` | String | Yes | Human-readable name | `"CNC Milling Machine 03"` |
| `productionLine` | String | Yes | Factory line tag (`Line 1`, `Line 2`, `Line 3`) | `"Line 1"` |
| `modelNumber` | String | Yes | Manufacturer model | `"Haas VF-2SS"` |
| `status` | String | Yes | `Operational`, `Warning`, `Critical`, `Under Maintenance` | `"Operational"` |
| `healthScore` | Integer | Yes | Dynamic score 0–100 | `92` |
| `temperature` | Number | Yes | Current temperature in °C | `68.5` |
| `vibration` | Number | Yes | Current vibration in mm/s RMS | `2.8` |
| `lastInspection` | Timestamp | No | Date of last maintenance check | `ServerTimestamp` |
| `createdAt` | Timestamp | Yes | Record creation timestamp | `ServerTimestamp` |
| `updatedAt` | Timestamp | Yes | Last telemetry/status update | `ServerTimestamp` |

```json
// Example Document: machines/MCH-LINE1-CNC03
{
  "machineId": "MCH-LINE1-CNC03",
  "name": "CNC Milling Machine 03",
  "productionLine": "Line 1",
  "modelNumber": "Haas VF-2SS",
  "status": "Operational",
  "healthScore": 92,
  "temperature": 68.5,
  "vibration": 2.8,
  "lastInspection": "2026-10-01T10:00:00Z",
  "createdAt": "2026-09-15T00:00:00Z",
  "updatedAt": "2026-10-06T09:15:00Z"
}
```

---

### Collection 3: `faults`
- **Path:** `/faults/{faultId}`
- **Description:** Individual breakdown reports logged by operators.

| Field | Type | Required | Description | Example |
|---|---|---|---|---|
| `faultId` | String | Yes | Auto-generated document ID | `"flt_88391024"` |
| `machineId` | String | Yes | Target machine reference ID | `"MCH-LINE1-CNC03"` |
| `machineName` | String | Yes | Denormalized machine name for fast listing | `"CNC Milling Machine 03"` |
| `type` | String | Yes | Category: `Mechanical`, `Electrical`, `Hydraulic`, `Thermal`, `Pneumatic`, `Other` | `"Thermal"` |
| `severity` | String | Yes | `Low`, `Medium`, `High`, `Critical` | `"High"` |
| `description` | String | Yes | Detailed symptom narrative | `"Spindle motor emitting burning smell and casing hot."` |
| `imageUrl` | String | No | Public download URL from Firebase Storage | `"https://firebasestorage.googleapis.com/.../img.jpg"` |
| `reportedBy` | String | Yes | User UID of reporting operator | `"u7Xk91pL0mQz"` |
| `reportedByName`| String | Yes | Denormalized operator name | `"Rajesh Sharma"` |
| `status` | String | Yes | `Open`, `In Progress`, `Resolved` | `"Open"` |
| `createdAt` | Timestamp | Yes | Incident report timestamp | `ServerTimestamp` |

```json
// Example Document: faults/flt_88391024
{
  "faultId": "flt_88391024",
  "machineId": "MCH-LINE1-CNC03",
  "machineName": "CNC Milling Machine 03",
  "type": "Thermal",
  "severity": "High",
  "description": "Spindle motor emitting burning smell and casing is extremely hot to touch.",
  "imageUrl": "https://firebasestorage.googleapis.com/v0/b/machalert.appspot.com/o/faults%2Fflt_88391024.jpg?alt=media",
  "reportedBy": "u7Xk91pL0mQz",
  "reportedByName": "Rajesh Sharma",
  "status": "Open",
  "createdAt": "2026-10-06T10:15:00Z"
}
```

---

### Collection 4: `maintenance`
- **Path:** `/maintenance/{maintenanceId}`
- **Description:** Work orders assigned to technicians to repair logged faults.

| Field | Type | Required | Description | Example |
|---|---|---|---|---|
| `maintenanceId` | String | Yes | Auto-generated document ID | `"maint_551029"` |
| `machineId` | String | Yes | Target machine ID | `"MCH-LINE1-CNC03"` |
| `machineName` | String | Yes | Denormalized machine name | `"CNC Milling Machine 03"` |
| `faultId` | String | Yes | Linked fault document ID | `"flt_88391024"` |
| `technicianId` | String | Yes | Assigned technician's UID | `"tech_49210aBc"` |
| `technicianName`| String | Yes | Assigned technician's name | `"Anand Patel"` |
| `priority` | String | Yes | `Low`, `Medium`, `High`, `Critical` | `"High"` |
| `status` | String | Yes | `Pending`, `In Progress`, `Resolved` | `"Pending"` |
| `notes` | String | No | Technician's diagnostic & resolution remarks | `"Replaced thermal fuse and cleaned debris from fan shroud."` |
| `assignedAt` | Timestamp | Yes | Date/time work was assigned | `ServerTimestamp` |
| `resolvedAt` | Timestamp | No | Date/time completed | `ServerTimestamp` |

```json
// Example Document: maintenance/maint_551029
{
  "maintenanceId": "maint_551029",
  "machineId": "MCH-LINE1-CNC03",
  "machineName": "CNC Milling Machine 03",
  "faultId": "flt_88391024",
  "technicianId": "tech_49210aBc",
  "technicianName": "Anand Patel",
  "priority": "High",
  "status": "In Progress",
  "notes": "Opened spindle enclosure. Coolant line clogged causing thermal spike. Clearing passage.",
  "assignedAt": "2026-10-06T10:20:00Z",
  "resolvedAt": null
}
```

---

### Collection 5: `alerts`
- **Path:** `/alerts/{alertId}`
- **Description:** System-generated notifications triggered by the smart rule engine.

| Field | Type | Required | Description | Example |
|---|---|---|---|---|
| `alertId` | String | Yes | Auto-generated ID | `"alt_992104"` |
| `machineId` | String | Yes | Target machine ID | `"MCH-LINE1-CNC03"` |
| `machineName` | String | Yes | Machine name | `"CNC Milling Machine 03"` |
| `type` | String | Yes | `RECURRING_FAULT`, `OVERHEATING`, `VIBRATION_CRITICAL` | `"RECURRING_FAULT"` |
| `severity` | String | Yes | `Warning`, `Critical` | `"Critical"` |
| `message` | String | Yes | Human-readable alert summary | `"CNC Milling Machine 03 logged 3 Thermal faults in 7 days."` |
| `acknowledged`| Boolean| Yes | Has manager dismissed the alert | `false` |
| `createdAt` | Timestamp | Yes | Generated timestamp | `ServerTimestamp` |

---

### 15.6 Required Firestore Composite Indexes
To ensure fast queries without runtime query execution exceptions, the following composite indexes must be configured in `firestore.indexes.json`:

1. **Collection:** `faults`
   - Fields: `machineId` (Ascending) + `createdAt` (Descending)
2. **Collection:** `faults`
   - Fields: `type` (Ascending) + `createdAt` (Descending)
3. **Collection:** `maintenance`
   - Fields: `technicianId` (Ascending) + `status` (Ascending) + `priority` (Descending)
4. **Collection:** `alerts`
   - Fields: `acknowledged` (Ascending) + `createdAt` (Descending)

---

## 16. Firebase Architecture & Infrastructure

MachAlert avoids complex middleware by connecting Flutter directly to Firebase using official FlutterFire plugins.

```text
                     ┌────────────────────────────────────────┐
                     │         Flutter Mobile Client          │
                     │          (Android / iOS App)           │
                     └───────────────────┬────────────────────┘
                                         │
                 ┌───────────────────────┼───────────────────────┐
                 │                       │                       │
                 ▼                       ▼                       ▼
      ┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐
      │    Firebase Auth    │ │   Cloud Firestore   │ │  Firebase Storage   │
      │   (JWT Auth State)  │ │ (Real-Time Streams) │ │ (Compressed Images) │
      └─────────────────────┘ └─────────────────────┘ └─────────────────────┘
                 │                       │                       │
                 ▼                       ▼                       ▼
      • Email/Password Login  • users/ Collection     • /fault_images/
      • Role Token Binding    • machines/ Collection  • Max 5MB per upload
      • Persistent Session    • faults/ Collection    • JPEG/PNG only
                              • maintenance/ Col.
                              • alerts/ Collection
```

---

## 17. Flutter Application Architecture & Folder Structure

MachAlert adopts a **Layered Service-Repository Pattern** using Flutter’s native `ChangeNotifierProvider` (`provider` package). This architecture provides strict separation of concerns, simplifies daily unit PR division, and avoids bloated widget files.

```text
lib/
│
├── main.dart                      # App entry point, Firebase.initializeApp(), MultiProvider setup
│
├── models/                        # Plain Dart data classes with fromFirestore() & toFirestore()
│   ├── user_model.dart            # AppUser: uid, name, email, role
│   ├── machine_model.dart         # Machine: id, name, line, status, healthScore, temp, vib
│   ├── fault_model.dart           # Fault: id, machineId, type, severity, description, imageUrl
│   ├── maintenance_model.dart     # MaintenanceTask: id, machineId, faultId, techId, status, notes
│   └── alert_model.dart           # AlertItem: id, machineId, type, severity, message, acknowledged
│
├── screens/                       # User interfaces organized by domain feature
│   ├── splash_screen.dart         # Initial routing and session verification
│   ├── auth/
│   │   ├── login_screen.dart      # Email/Password form
│   │   └── signup_screen.dart     # Registration and role dropdown
│   ├── dashboard/
│   │   ├── dashboard_screen.dart  # Role-aware metrics and action hub
│   │   └── widgets/               # Dashboard-specific summary cards
│   ├── machines/
│   │   ├── machine_list_screen.dart
│   │   └── machine_detail_screen.dart
│   ├── faults/
│   │   ├── report_fault_screen.dart
│   │   └── fault_history_screen.dart
│   ├── maintenance/
│   │   ├── maintenance_tasks_screen.dart
│   │   └── maintenance_detail_screen.dart
│   ├── alerts/
│   │   └── alerts_screen.dart     # Smart alert feed
│   └── profile/
│       └── profile_screen.dart    # Account details and logout
│
├── widgets/                       # Reusable visual components
│   ├── custom_button.dart         # High-contrast 48dp industrial button
│   ├── custom_text_field.dart     # Validated text field with custom theme
│   ├── status_badge.dart          # Colored pill badge (Operational/Warning/Critical)
│   ├── machine_card.dart          # Machine inventory list card with health indicator
│   ├── fault_card.dart            # Fault incident card
│   └── loading_indicator.dart     # Standardized spinner
│
├── services/                      # Low-level Firebase SDK wrapper methods
│   ├── auth_service.dart          # signIn, signUp, signOut, currentUser
│   ├── firestore_service.dart     # getMachinesStream, addFault, updateMaintenanceTask
│   ├── storage_service.dart       # uploadFaultImage, deleteFile
│   └── rule_engine_service.dart   # calculateHealthScore, checkRecurringFaults
│
├── providers/                     # State management using Provider & ChangeNotifier
│   ├── auth_provider.dart         # Tracks active user session, role, auth state
│   ├── machine_provider.dart      # Streams machines, handles line filtering and search
│   ├── fault_provider.dart        # Manages fault form state and submission loading
│   └── maintenance_provider.dart  # Filters tasks for technicians and managers
│
└── utils/                         # Global helpers, theme, constants, and validators
    ├── constants.dart             # Color palettes, string constants, collection names
    ├── validators.dart            # Form field regex & string validation functions
    ├── routes.dart                # Named route definitions
    └── theme.dart                 # Industrial Material 3 theme configuration
```

---

## 18. Security & Access Control

### 18.1 Firestore Security Rules (`firestore.rules`)
MachAlert protects production data using declarative Firestore Security Rules that validate request authentication tokens and inspect user roles.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper function: Check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }

    // Helper function: Fetch user document from users collection
    function getUserData() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
    }

    // Helper functions for specific roles
    function isManager() {
      return isAuthenticated() && getUserData().role == 'manager';
    }

    function isTechnician() {
      return isAuthenticated() && getUserData().role == 'technician';
    }

    function isOperator() {
      return isAuthenticated() && getUserData().role == 'operator';
    }

    // --- USERS COLLECTION ---
    // Users can read any user profile; can only write their own user doc during registration
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() && request.auth.uid == userId;
      allow update: if isAuthenticated() && (request.auth.uid == userId || isManager());
      allow delete: if isManager();
    }

    // --- MACHINES COLLECTION ---
    // All authenticated users can inspect machines; only managers can create or delete
    match /machines/{machineId} {
      allow read: if isAuthenticated();
      allow create, delete: if isManager();
      // Operators & Technicians can update telemetry and status via fault/repair actions
      allow update: if isAuthenticated();
    }

    // --- FAULTS COLLECTION ---
    // All users can view and log faults; only managers can delete
    match /faults/{faultId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated();
      allow update: if isAuthenticated() && (isTechnician() || isManager() || resource.data.reportedBy == request.auth.uid);
      allow delete: if isManager();
    }

    // --- MAINTENANCE COLLECTION ---
    // Technicians can update their assigned tasks; Managers have full control
    match /maintenance/{maintenanceId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() && (isManager() || isOperator());
      allow update: if isAuthenticated() && (isTechnician() || isManager());
      allow delete: if isManager();
    }

    // --- ALERTS COLLECTION ---
    // All authenticated users can read alerts; system/managers can acknowledge
    match /alerts/{alertId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated();
      allow update: if isManager() || isTechnician();
      allow delete: if isManager();
    }
  }
}
```

### 18.2 Firebase Storage Security Rules (`storage.rules`)
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /fault_images/{imageName} {
      // Any authenticated user can read images
      allow read: if request.auth != null;
      // Only authenticated users can upload; must be an image under 5MB
      allow write: if request.auth != null
                   && request.resource.size < 5 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }
  }
}
```

---

## 19. Team Responsibilities & Work Division

To ensure equal accountability and clear separation of concerns across the 3 beginner developers, responsibilities are organized by engineering domain:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        TEAM DIVISION OF RESPONSIBILITIES               │
├────────────────────┬────────────────────┬──────────────────────────────┤
│      MEMBER 1      │      MEMBER 2      │           MEMBER 3           │
│   (UI/UX Lead)     │   (Firebase Lead)  │ (Logic & Integration Lead)   │
├────────────────────┼────────────────────┼──────────────────────────────┤
│ • Design System &  │ • Firebase Project │ • Dart Models (Serialization)│
│   Theme Tokens     │   Configuration    │ • State Management (Provider)│
│ • Screen Layouts   │ • Auth & Token Mgmt│ • Form Input Validators      │
│ • Custom Reusable  │ • Firestore CRUD & │ • Search & Filtering Logic   │
│   Widgets (Cards)  │   Security Rules   │ • Rule Engine Implementation │
│ • Shimmer Loading  │ • Firebase Storage │ • End-to-End Service Binding │
│   & Error Banners  │   Upload Pipeline  │ • Unit & Integration Testing │
└────────────────────┴────────────────────┴──────────────────────────────┘
```

---

## 20. 20-Day Development Roadmap

```text
DAY 01–05: FOUNDATIONS & SETUP
├── Project scaffolding, Git convention setup, Flutter theme, Firebase console provisioning
└── Output: Running Flutter skeleton connected to Firebase project with empty collections.

DAY 06–08: AUTHENTICATION & ROLE-BASED ACCESS
├── Login, Sign Up, Role Selection, Persistent Session, Auth Guards
└── Output: Working authentication cycle with role routing to dummy dashboard.

DAY 09–12: MACHINE INVENTORY & TELEMETRY MODULE
├── Machine data models, Firestore machine streams, Machine Cards, Details Screen
└── Output: Real-time machine directory with live health scores and line filters.

DAY 13–15: FAULT REPORTING & MEDIA PIPELINE
├── Fault reporting form, Image Picker integration, Firebase Storage upload, Fault History
└── Output: Operators can snap photos and submit faults, creating real-time Firestore records.

DAY 16–17: MAINTENANCE WORKFLOW & STATUS DISPATCH
├── Maintenance task list, Task assignment, Status lifecycle (Pending->Done), Notes input
└── Output: Technicians pick up tasks, input repair notes, and resolve faults.

DAY 18–19: SMART RULE ENGINE, POLISH & TEST SUITE
├── Health score recalculations, 7-day recurring fault alert trigger, Bug bashing, UI polish
└── Output: Fully functional, bug-free, styled industrial application.

DAY 20: FINAL EVALUATION, DOCUMENTATION & DEMO SPRINT
├── Comprehensive demo rehearsal, README finalization, Presentation slides
└── Output: Flawless 3–5 minute presentation and project submission.
```

---

## 21. Daily PR Plan (60 Pull Requests Matrix)

Every developer delivers **one focused, testable, and reviewed Pull Request every calendar day**. Below is the exact 60-PR schedule:

| Day | Member 1 (UI/UX) PR | Member 2 (Firebase) PR | Member 3 (Logic & Integration) PR | Daily Feature Milestone Achieved |
|---|---|---|---|---|
| **Day 1** | `feat(ui): add industrial theme colors and typography` | `chore(firebase): configure firebase options and core init` | `chore(project): initialize folder structure and app routes` | Project initialized, Firebase connected, styling tokens established. |
| **Day 2** | `feat(ui): create custom button and text field widgets` | `chore(firebase): add firestore security rules template` | `feat(utils): create regex string validators for forms` | Common UI form primitives and validation utilities ready. |
| **Day 3** | `feat(ui): implement animated splash screen layout` | `feat(auth): configure firebase auth service wrapper` | `feat(models): create user model with to/from map helpers` | Splash screen visual assets and user data serialization ready. |
| **Day 4** | `feat(ui): create custom loading spinner and error snackbar`| `feat(firestore): configure firestore helper service class` | `feat(state): setup root multiprovider configuration` | Global loading states and central state management wired up. |
| **Day 5** | `feat(ui): design reusable status pill badge widget` | `feat(firestore): seed initial machine documents in db` | `feat(models): build machine data model and unit tests` | Database seeded with 6 factory machines; models tested. |
| **Day 6** | `feat(ui): design login screen layout with logo header` | `feat(auth): implement signin with email and password` | `feat(state): build auth provider login action and states` | Functional Login screen with error handling complete. |
| **Day 7** | `feat(ui): design signup screen with role dropdown` | `feat(auth): implement signup and write user doc to firestore`| `feat(state): bind signup form validation to auth provider` | Full registration flow operational with role selection. |
| **Day 8** | `feat(ui): implement persistent bottom navigation bar` | `feat(auth): setup persistent auth state stream listener` | `feat(routes): implement role-based route guard redirect` | Authenticated users stay logged in and route by role. |
| **Day 9** | `feat(ui): build base dashboard layout and greeting bar`| `feat(firestore): add realtime stream for plant machines` | `feat(state): build machine provider with realtime listener`| Live machine count and user welcome banner on dashboard. |
| **Day 10**| `feat(ui): design machine list card with health gauge` | `feat(firestore): add query filtering by production line` | `feat(logic): implement client-side machine name search` | Machine directory browsable with live line-filtering tabs. |
| **Day 11**| `feat(ui): design machine detail screen layout` | `feat(firestore): fetch single machine realtime stream` | `feat(state): bind machine details and telemetry chips` | Machine details view with live temp and vibration readouts. |
| **Day 12**| `feat(ui): design report fault screen layout and chips` | `feat(firestore): create addFault document transaction` | `feat(state): create fault provider with form controllers` | Static fault reporting form ready with dropdown picker. |
| **Day 13**| `feat(ui): add image preview thumbnail and remove button`| `feat(storage): setup firebase storage fault image upload` | `feat(logic): integrate image_picker for camera & gallery` | Fault form can take photos and upload image to Storage. |
| **Day 14**| `feat(ui): design fault history card and list layout` | `feat(firestore): add query for faults sorted by date` | `feat(state): implement fault history filtering by status` | Fault history feed functional with real-time updates. |
| **Day 15**| `feat(ui): add modal dialog to view enlarged fault photo`| `feat(firestore): auto-update machine status on high fault`| `feat(logic): bind fault submission to machine status update`| Submitting high-severity fault turns machine status Red. |
| **Day 16**| `feat(ui): design maintenance task list card and tabs` | `feat(firestore): implement maintenance collection queries`| `feat(state): build maintenance provider with task streams`| Maintenance task screen renders tasks assigned to user. |
| **Day 17**| `feat(ui): build maintenance detail screen and action bar`| `feat(firestore): add updateMaintenanceStatus transaction` | `feat(logic): implement mandatory technician notes check` | Technicians can accept tasks and mark them Resolved. |
| **Day 18**| `feat(ui): design smart alert banner and notifications tab`| `feat(rules): write 7-day recurring fault query in firestore`| `feat(logic): implement deterministic health score algorithm`| Recurring fault warnings generate automated alert badges. |
| **Day 19**| `feat(ui): build profile screen with role badge and logout`| `feat(rules): finalize strict firestore & storage rules` | `test: add unit tests for validators and health score` | Complete profile screen, security rules locked, tests green. |
| **Day 20**| `style(ui): polish animations, margins, and contrast` | `docs: add firestore schema documentation to README` | `chore: clean debug logs and prepare presentation build` | Application polished, audited, packaged, and ready for demo. |

---

## 22. Git & GitHub Collaboration Workflow

To ensure smooth collaboration among 3 beginner developers and avoid merge conflicts, MachAlert strictly enforces a **Feature-Branch Workflow**.

```text
                                  GITHUB MAIN BRANCH
                                (Production-Ready Code)
                                           │
             ┌─────────────────────────────┼─────────────────────────────┐
             │                             │                             │
             ▼                             ▼                             ▼
       feature/m1-login-ui         feature/m2-auth-service       feature/m3-auth-provider
       (Member 1 Branch)           (Member 2 Branch)             (Member 3 Branch)
             │                             │                             │
             ▼                             ▼                             ▼
       1. Code Locally             1. Code Locally               1. Code Locally
       2. Run flutter analyze      2. Run flutter analyze        2. Run flutter analyze
       3. Push to GitHub           3. Push to GitHub             3. Push to GitHub
       4. Open Pull Request        4. Open Pull Request          4. Open Pull Request
             │                             │                             │
             └─────────────────────────────┼─────────────────────────────┘
                                           │
                                5. Peer Code Review
                                (1 Approval Required)
                                           │
                                           ▼
                                6. Squash & Merge to Main
                                (Keeps git history clean)
```

### 22.1 Step-by-Step Developer Commands
```bash
# 1. Start every day with the latest codebase
git checkout main
git pull origin main

# 2. Create your isolated feature branch for the day's PR
git checkout -b feature/m1-machine-detail-ui

# 3. Write code, test locally, and verify zero analyze errors
flutter analyze

# 4. Stage and commit using conventional commit messages
git add .
git commit -m "feat(ui): build machine detail screen layout with telemetry chips"

# 5. Push branch to GitHub
git push -u origin feature/m1-machine-detail-ui

# 6. Open Pull Request on GitHub and request a review from a teammate
```

### 22.2 Mandatory Pull Request Template
Every PR must paste this template into the GitHub PR description:
```markdown
### What Changed?
- Added MachineDetailsScreen with health score gauge and temperature chips.
- Added reusable TelemetryChip widget.

### Why Was This Change Needed?
- Fulfills Functional Requirement FR-09 so operators and technicians can inspect machine condition.

### Verification & Testing Done:
- [x] Ran `flutter analyze` — 0 errors, 0 warnings.
- [x] Tested on Android Emulator (Pixel 7, API 34).
- [x] Verified dark and light contrast for readability.

### Screenshots / Screen Recording:
[Attach PNG or GIF here]
```

---

## 23. Testing Strategy

### 23.1 Automated Unit & Logic Testing
Beginners will write unit tests targeting stateless algorithms and pure Dart classes (stored in `test/`):
- `validators_test.dart`: Validates email patterns, password lengths, and required string inputs.
- `health_score_test.dart`: Tests edge conditions for the health score formula:
  - Normal conditions (Temp 60°C, Vib 2.0 mm/s) ➔ Expect Score = 100 (`Operational`).
  - Elevated conditions (Temp 75°C, Vib 4.0 mm/s) ➔ Expect Score = 70 (`Warning`).
  - Critical conditions (Temp 90°C, Vib 7.5 mm/s) ➔ Expect Score < 50 (`Critical`).
- `model_serialization_test.dart`: Confirms `fromFirestore` handles null fields gracefully without crashing.

### 23.2 Manual Functional Test Scenarios

| Test Case ID | Test Domain | Scenario Description | Expected Outcome |
|---|---|---|---|
| **TC-AUTH-01** | Auth | Enter unregistered email on Login screen. | Displays "No user found with this email" SnackBar. |
| **TC-AUTH-02** | Auth | Register with role `Technician`. | Writes doc to `users` with `role: "technician"` and opens Technician Dashboard. |
| **TC-MACH-01** | Machine | Search for "CNC" in Machine List. | Dynamically hides non-matching machines; shows only CNC equipment. |
| **TC-FLT-01** | Fault | Submit fault without entering description. | Form validation highlights field in red; submit button disabled. |
| **TC-FLT-02** | Fault | Attach camera photo and submit Critical fault. | Photo uploads to Storage; fault doc created; machine status turns Red immediately. |
| **TC-MNT-01** | Maintenance | Technician marks task `Resolved` with empty notes. | Alert dialog prompts: "Please provide resolution notes before completing." |
| **TC-RULE-01** | Smart Rule | Submit 3rd Thermal fault on Machine 02 within 7 days. | Automated `RECURRING_FAULT` document appears in `alerts` collection. |
| **TC-SEC-01** | Security | Operator attempts to delete machine document. | Firestore security rules reject request with `PERMISSION_DENIED`. |

---

## 24. Formal Acceptance Criteria (Given-When-Then)

### AC-01: User Authentication
- **Given** an unregistered operator with email `operator1@factory.com` and password `password123`,
- **When** they fill the Sign Up form, select role `Operator`, and tap "Register Account",
- **Then** a Firebase Auth account is created, a document is saved to `users/{uid}`, and they are redirected to the Operator Dashboard.

### AC-02: Instant Fault Logging
- **Given** an authenticated operator standing next to machine `MCH-LINE1-CNC03`,
- **When** they navigate to Report Fault, choose `Hydraulic`, select severity `Critical`, enter `"Hydraulic oil leaking near cylinder seal"`, attach a photo, and tap "Submit Fault Report",
- **Then** the image is uploaded to Firebase Storage, a new document is written to `faults` with server timestamp, `MCH-LINE1-CNC03` status changes to `Critical`, and a confirmation SnackBar is displayed.

### AC-03: Real-Time Maintenance Task Synchronization
- **Given** a maintenance task assigned to technician `Anand Patel`,
- **When** Anand taps "Start Repair" on the task details screen,
- **Then** the maintenance document status in Firestore updates to `In Progress`, and the linked machine status displays `Under Maintenance` in real-time across all active devices without refreshing.

### AC-04: Task Resolution with Audit Trail
- **Given** an in-progress maintenance task,
- **When** the technician inputs resolution notes `"Tightened high-pressure flange and replaced Teflon gasket"` and taps "Confirm Resolution",
- **Then** the maintenance status transitions to `Resolved`, the completion timestamp is saved, the associated fault status changes to `Resolved`, and the machine operational status returns to `Operational`.

### AC-05: Recurring Fault Detection
- **Given** machine `MCH-LINE2-PRESS01` has 2 previously logged `Mechanical` faults within the past 4 days,
- **When** an operator logs a 3rd `Mechanical` fault for `MCH-LINE2-PRESS01`,
- **Then** the rule engine evaluates the 7-day threshold, generates a new document in `alerts`, and the manager's dashboard displays a high-visibility `Recurring Fault Detected` warning badge.

---

## 25. Definition of Done (DoD)

A user story or daily Pull Request is officially marked **Done** if and only if it satisfies all 10 criteria:

1. **Code Complete:** Feature implemented cleanly in Dart without commented-out code blocks or temporary hacks.
2. **Architecture Compliance:** Follows the established layered folder structure (no raw Firestore calls inside UI widgets).
3. **No Linter Warnings:** `flutter analyze` passes with 0 errors and 0 warnings.
4. **Tested on Device/Emulator:** Tested on at least one physical device or Android Emulator.
5. **State Handling:** Loading spinners, error messages, and empty states are implemented.
6. **Security Rules Checked:** Any new Firestore access pattern is permitted by `firestore.rules`.
7. **Small, Focused Scope:** The PR addresses only the designated task from the 20-Day Plan.
8. **Documented & Titled:** PR uses Conventional Commits (e.g. `feat(ui): ...`, `fix(auth): ...`).
9. **Peer Reviewed & Approved:** Reviewed and approved by at least one teammate on GitHub.
10. **Merged to Main:** Branch is cleanly squash-merged into the `main` branch.

---

## 26. Project Risks & Practical Mitigations

| Risk ID | Risk Description | Severity | Likelihood | Practical Beginner Mitigation |
|---|---|---|---|---|
| **R-01** | Git Merge Conflicts due to simultaneous edits on `main.dart`. | High | High | Keep `main.dart` minimal (only route definitions and theme). Never edit other members' files without coordination. |
| **R-02** | Firestore queries crash app due to missing composite indexes. | Medium | High | Follow console log URL directly to auto-generate index in Firebase Console; export to `firestore.indexes.json`. |
| **R-03** | Camera/Gallery crashes on Android Emulator. | Medium | Medium | Test with static placeholder images or configure emulator camera to "Emulated/Virtual Scene". |
| **R-04** | Security rules block client-side read/write unexpectedly. | High | Medium | Keep security rules in `test_mode` for Days 1–17; lock down to strict production rules on Day 18. |
| **R-05** | Team falls behind on the daily 1 PR per member target. | High | Medium | Keep daily tasks small and modular. A single widget or data model counts as a valid PR. |
| **R-06** | Firebase Storage billing limits exceeded during image upload testing. | Low | Low | Implement client-side image compression using `flutter_image_compress` before uploading. |
| **R-07** | Scope creep: Team attempts unfeasible AI/IoT features. | High | Medium | Strict adherence to Section 4.2 Non-Goals. All smart features remain deterministic heuristics. |

---

## 27. Success Metrics & KPI Tracking

### 27.1 Academic & Development Velocity Metrics
- **Pull Request Completion Rate:** Exactly $\ge 60$ verified PRs merged across 20 days ($3 \text{ PRs/day}$).
- **Build Cleanliness:** 100% passing `flutter analyze` on the `main` branch.
- **Role Distribution Balance:** 33.3% contribution share per developer across commits and PRs.

### 27.2 Simulated Industrial Impact Metrics
- **Mean Time to Report (MTTR_r):** Baseline verbal handover = 6 hours ($21,600\text{ s}$). MachAlert digital submission = $< 35\text{ seconds}$ (**$99.8\%$ reduction in reporting latency**).
- **Audit Completeness:** $100\%$ of logged faults possess machine ID, category, severity, timestamp, and reporting operator attribution.
- **Repeat Incident Detection:** Automated recurring fault alerts generated within 1 second of 3rd fault submission, compared to days or weeks in paper logbooks.

---

## 28. Final Demonstration Script & Flow (3–5 Minutes)

This script is structured for the final academic project evaluation, showcasing the complete transformation from reactive to proactive maintenance in under 5 minutes.

```text
TIMELINE & ACTOR CUES:

[0:00 - 0:45] INTRODUCTION & THE PROBLEM (Presenter 1 - Neha/Manager)
• Visual: Slide showing broken manufacturing assembly line and paper clipboard.
• Script: "Good afternoon. In modern manufacturing, machine breakdowns cost thousands of dollars every hour. 
  Today, factory faults are only reported at shift-end review meetings—up to 10 hours too late. 
  We built MachAlert: an industrial mobile platform powered by Flutter and Firebase that solves this problem in real-time."

[0:45 - 1:45] ACT 1: OPERATOR LOGS CRITICAL FAULT (Presenter 2 - Rajesh/Operator)
• Device: Android Phone running MachAlert logged in as Operator.
• Action: Operator opens app, taps Machine List, selects "CNC Milling Machine 03".
• Action: Taps "Report Fault". Selects Category "Thermal", Severity "Critical".
• Action: Types: "Spindle motor overheating, abnormal vibration." Snaps a live photo.
• Action: Hits "Submit Fault Report".
• Script: "Within 30 seconds, Rajesh has digitally recorded the defect with a photographic audit trail. 
  Notice how CNC Machine 03 immediately turns Red with status Critical."

[1:45 - 2:45] ACT 2: REAL-TIME DISPATCH & TECHNICIAN RESOLUTION (Presenter 3 - Anand/Technician)
• Device: Second Device/Emulator logged in as Technician.
• Action: Instantly shows the new task on Maintenance Tasks Screen without refreshing!
• Action: Anand taps the task, views the attached photo, and taps "Start Repair".
• Action: Status shifts to "In Progress". Anand types repair notes: 
  "Flushed clogged coolant nozzle and replaced thermal relay."
• Action: Taps "Mark Resolved".
• Script: "No paper lost, no waiting for the shift to end. Anand receives the assignment instantly, 
  performs the intervention, logs his technical notes, and marks it resolved."

[2:45 - 3:45] ACT 3: SMART RULE ENGINE & MANAGER VISIBILITY (Presenter 1 - Neha/Manager)
• Device: Tablet/Phone logged in as Manager.
• Action: Manager dashboard shows CNC Machine 03 restored to Green "Operational".
• Action: Manager opens the Alerts Tab.
• Script: "Here is where MachAlert becomes proactive. Our rule engine detected that this was the 3rd 
  Thermal fault on CNC Machine 03 this week. The system automatically triggered a 'Recurring Fault Alert' 
  warning management that the machine needs a complete overhaul before a catastrophic failure occurs."

[3:45 - 4:15] ARCHITECTURAL SUMMARY & CONCLUSION (All Members)
• Script: "MachAlert was built over 20 days by 3 beginner developers following clean Flutter architecture, 
  strict Firebase security rules, and delivering over 60 verified Pull Requests. Thank you!"
```

---

## 29. Future Roadmap (v1.1 to v2.0)

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        MACHALERT POST-MVP ROADMAP                      │
├───────────────────┬────────────────────────────────────────────────────┤
│ VERSION 1.1       │ • Cloud Messaging (FCM) automated push alerts      │
│ (Month 2)         │ • Exportable Shift Maintenance PDF Summary Reports │
│                   │ • Offline-first SQLite local sync cache            │
├───────────────────┼────────────────────────────────────────────────────┤
│ VERSION 1.2       │ • Bluetooth Low Energy (BLE) vibration sensor sync │
│ (Month 3)         │ • Machine QR Code scanning for 1-tap fault opening │
│                   │ • Multilingual UI (English, Hindi, Spanish)        │
├───────────────────┼────────────────────────────────────────────────────┤
│ VERSION 2.0       │ • Edge TensorFlow Lite vibration anomaly detector  │
│ (Month 6)         │ • Predictive Remaining Useful Life (RUL) estimation│
│                   │ • ERP/SAP automated spare parts order integration  │
└───────────────────┴────────────────────────────────────────────────────┘
```

---

## 30. Executive Appendices & Master Checklists

### 30.1 Concise MVP Feature Checklist
- [ ] **Authentication & Security**
  - [ ] User Sign Up with email, password, and full name
  - [ ] Role selector: Operator, Technician, Manager
  - [ ] User Login with validation and error SnackBars
  - [ ] Persistent login state via Firebase Auth
  - [ ] Role-based access control guards on navigation
  - [ ] Declarative Firestore Security Rules
  - [ ] Secure Firebase Storage Rules (image only, < 5MB)
- [ ] **Machine Inventory Management**
  - [ ] Real-time machine list with production line filters
  - [ ] Search machines by name and model code
  - [ ] Machine condition status badges (Operational, Warning, Critical, Under Maintenance)
  - [ ] Comprehensive machine details view with telemetry readouts
  - [ ] Dynamic Health Score gauge (0–100%)
- [ ] **Fault Reporting & Media**
  - [ ] Machine selector dropdown
  - [ ] Categorized fault types (Mechanical, Electrical, Hydraulic, Thermal, etc.)
  - [ ] Severity selector (Low, Medium, High, Critical)
  - [ ] Detailed text description field
  - [ ] Camera and Gallery image attachment via `image_picker`
  - [ ] Media upload to Firebase Storage with download URL binding
  - [ ] Server timestamped fault creation
  - [ ] Real-time fault history view with status filters
- [ ] **Maintenance Work Order Lifecycle**
  - [ ] Technician-assigned task view
  - [ ] Task status progression: Pending ➔ In Progress ➔ Resolved
  - [ ] Mandatory repair notes input before completion
  - [ ] Automatic status restoration of machines upon fault resolution
- [ ] **Smart Rule Engine**
  - [ ] Deterministic health score penalty calculations
  - [ ] 7-day recurring fault detection trigger ($\ge 3$ faults of same category)
  - [ ] Automated generation of documents in `alerts` collection
  - [ ] Dedicated in-app Alert Feed screen
- [ ] **UI/UX Polish**
  - [ ] Industrial theme palette with high-contrast elements
  - [ ] Material 3 responsive design
  - [ ] Minimum 48×48 dp touch targets for shop-floor usability
  - [ ] Shimmer loading states and graceful error banners
  - [ ] Clean empty states for all lists

---

### 30.2 20-Day × 3-Member Pull Request Master Table (Summary Matrix)

| Day Range | Phase | Member 1 (UI/UX) Focus | Member 2 (Firebase) Focus | Member 3 (Logic) Focus | Total PRs |
|---|---|---|---|---|---|
| **Days 1–5** | Foundations & Architecture | Theme, Buttons, Splash, Badges | Firebase Init, Rules, Seeding | Models, Validators, Providers | 15 PRs |
| **Days 6–8** | Authentication & RBAC | Login UI, SignUp UI, Bottom Nav | Auth Service, User Firestore writes | Auth Provider, Route Guards | 9 PRs |
| **Days 9–12** | Machine Catalog & Detail | Machine Card, List Screen, Details UI | Machine Streams, Queries | Machine Provider, Search Logic | 12 PRs |
| **Days 13–15** | Fault Reporting & Storage | Report Fault UI, Image Preview, History | Storage Upload, Fault Writes | Image Picker, Fault Provider | 9 PRs |
| **Days 16–17** | Maintenance Work Orders | Task Cards, Maintenance Action UI | Maintenance Queries, Transactions | Task Lifecycle, Notes Logic | 6 PRs |
| **Days 18–19** | Smart Rules & Security | Alert Feed UI, Profile Screen | Strict Rules, Composite Indexes | Rule Engine, Unit Test Suite | 6 PRs |
| **Day 20** | Final Polish & Packaging | Theme Polish, Contrast Audit | Schema Documentation | Clean Code, Demo Build | 3 PRs |
| **TOTAL** | **Sprint 2 Complete** | **20 PRs** | **20 PRs** | **20 PRs** | **60 PRs** |

---

### 30.3 Recommended Flutter `pubspec.yaml` Dependencies
For full transparency, the beginner team should use the following battle-tested dependencies in `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Firebase Core & Services
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.4
  firebase_storage: ^12.3.2

  # State Management
  provider: ^6.1.2

  # Device Hardware Integration
  image_picker: ^1.1.2

  # Utilities & Helpers
  intl: ^0.19.0
  cached_network_image: ^3.4.1
  shimmer: ^3.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

---
*End of MachAlert Product Requirements Document & Technical Specification.*  
*Authored by Senior Product Manager & Software Architect for Academic Sprint 2 Development.*
