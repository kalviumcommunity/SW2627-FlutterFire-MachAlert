# 🏗️ MachAlert System Architecture & Design

This document details the architectural patterns, data pipelines, hybrid cloud storage integration, real-time synchronization mechanisms, and component interactions that power the MachAlert platform.

---

## 1. High-Level Architecture Overview

MachAlert employs a modern **Layered Reactive Architecture** built on Flutter and a hybrid cloud backend leveraging **Google Firebase** for identity and document state, alongside **Supabase Storage** for secure binary asset handling.

```mermaid
flowchart TD
    subgraph UI_Layer ["Presentation Layer (Flutter)"]
        Screens["Screens\n(Dashboard, Faults, Maintenance, Machines, Reports)"]
        Widgets["Reusable UI Components\n(StatusBadge, MachineCard, ActivityTimeline)"]
    end

    subgraph State_Layer ["State Management Layer (Provider)"]
        AppState["AppStateProvider\n(Session, User Profile, Global Theme)"]
    end

    subgraph Service_Layer ["Service Layer"]
        AuthService["AuthService\n(Firebase Auth & Custom Claims)"]
        MachineService["MachineService\n(CRUD & Health Streams)"]
        FaultService["FaultService\n(Fault Lifecycle & Image URLs)"]
        MaintenanceService["MaintenanceService\n(Task Assignment & Status Logs)"]
        ActivityService["MachineActivityService\n(Dynamic Timeline Synthesis)"]
        StorageService["SupabaseStorageUploader\n(S3-Compatible Uploads & Signed URLs)"]
    end

    subgraph Cloud_Layer ["Hybrid Cloud Infrastructure"]
        FirebaseAuth["Firebase Authentication\n(JWT Tokens & machalert_role)"]
        Firestore["Cloud Firestore\n(machines, faults, maintenance, users)"]
        SupabaseStorage["Supabase Storage\n(fault-images Private Bucket + RLS)"]
    end

    Screens --> AppState
    Screens --> Service_Layer
    AppState --> AuthService
    Service_Layer --> Cloud_Layer
```

---

## 2. Layered Component Responsibilities

### A. Presentation Layer (`lib/screens/`, `lib/widgets/`)
- Pure Flutter UI declarative widgets implementing Material 3 styling.
- Responsive layout adaptations supporting screen viewports from 320px compact mobile screens to large tablets.
- Consumes service streams via `StreamBuilder` and `Consumer<AppStateProvider>` to maintain zero-drift state synchronization.

### B. State Management Layer (`lib/providers/`)
- Manages application-wide session state, user authentication status, authenticated role metadata, and active theme modes.
- `AppStateProvider` holds the current `UserModel` and notifies descendant listeners upon authentication state transitions.

### C. Service Layer (`lib/services/`)
- Encapsulates business logic, validation rules, query execution, and network error handling.
- Exposes typed reactive streams (`Stream<List<T>>`) and async operations (`Future<T>`).
- Completely decouples the UI from direct third-party SDK dependencies (Firebase, Supabase).

### D. Data & Model Layer (`lib/models/`)
- Immutable Dart models with strict serialization/deserialization methods (`fromFirestore`, `toFirestore`, `fromJson`, `toJson`).
- Strongly typed domain entities:
  - `MachineModel` & `MachineStatistics`
  - `FaultModel`
  - `MaintenanceModel` & `MaintenanceUpdateModel`
  - `MachineActivityLogModel`
  - `UserModel`

---

## 3. Hybrid Cloud Infrastructure Design

MachAlert implements a hybrid cloud architecture combining the best-in-class features of Firebase and Supabase:

```
┌─────────────────────────────────────────────────────────────────┐
│                      Hybrid Cloud Division                      │
├───────────────────────────────┬─────────────────────────────────┤
│ Google Firebase               │ Supabase                        │
├───────────────────────────────┼─────────────────────────────────┤
│ • User Authentication         │ • Binary Media Asset Storage    │
│ • Custom Claims JWT Tokens    │ • User-Prefix Folder Isolation  │
│ • Cloud Firestore Documents   │ • Row-Level Security (RLS)      │
│ • Real-time Stream Listeners  │ • Time-Limited Signed URLs      │
│ • Composite Indexing          │ • S3-Compatible REST Endpoints  │
└───────────────────────────────┴─────────────────────────────────┘
```

### Why Hybrid?
1. **Low-Latency Metadata:** Firestore provides unmatched reactive document streaming for real-time mobile UI synchronization.
2. **Predictable Media Storage:** Supabase provides high-throughput S3-compatible binary storage with standard PostgreSQL Row-Level Security (RLS) policies, eliminating proprietary storage lock-in.

---

## 4. End-to-End Data Pipelines

### A. Fault Reporting & Media Upload Pipeline

```mermaid
sequenceDiagram
    autonumber
    actor Operator as Operator / User
    participant Screen as FaultReportingScreen
    participant Storage as SupabaseStorageUploader
    participant FaultSvc as FaultService
    participant Supabase as Supabase Storage
    participant Firestore as Cloud Firestore

    Operator->>Screen: Fill fault form & select image
    Operator->>Screen: Tap "Submit Fault Report"
    Screen->>Screen: Validate form inputs
    alt Image Attached
        Screen->>Storage: uploadFaultImage(bytes, fileName, uid)
        Storage->>Supabase: POST /storage/v1/object/fault-images/{uid}/{timestamp}_{fileName}
        Supabase-->>Storage: 200 OK (storagePath)
        Storage-->>Screen: Return storagePath
    end
    Screen->>FaultSvc: reportFault(FaultModel with storagePath)
    FaultSvc->>Firestore: faults.add(faultData)
    Firestore-->>FaultSvc: DocumentReference (faultId)
    FaultSvc-->>Screen: Success
    Screen-->>Operator: Display confirmation & navigate back
```

### B. Machine Activity Timeline Synthesis

The Machine Activity timeline does not rely on a static logs table. Instead, `MachineActivityService` dynamically synthesizes and sorts events across multiple Firestore streams in real time:

```mermaid
sequenceDiagram
    autonumber
    participant Screen as MachineDetailsScreen (Logs Tab)
    participant ActivitySvc as MachineActivityService
    participant Firestore as Cloud Firestore

    Screen->>ActivitySvc: getMachineActivityStream(machineId)
    par Stream Faults
        ActivitySvc->>Firestore: streamFaults(machineId)
        Firestore-->>ActivitySvc: List<FaultModel>
    and Stream Maintenance
        ActivitySvc->>Firestore: streamTasks(machineId)
        Firestore-->>ActivitySvc: List<MaintenanceModel>
    end
    ActivitySvc->>ActivitySvc: Transform Faults → Activity Logs
    ActivitySvc->>ActivitySvc: Transform Maintenance Updates → Activity Logs
    ActivitySvc->>ActivitySvc: Combine & sort descending by timestamp
    ActivitySvc-->>Screen: Stream<List<MachineActivityLogModel>>
    Screen->>Screen: Render chronological interactive timeline
```

---

## 5. Maintenance Task Assignment with Linked Faults

When assigning a maintenance work order, managers can optionally link an existing active fault belonging to the machine:

```mermaid
flowchart TD
    A["Manager Selects Machine\n(e.g., MCH-CNC-01)"] --> B["Query Open & In-Progress Faults\nfor MCH-CNC-01"]
    B --> C["Populate Searchable Dropdown\n(Displays Fault Type, Severity, Description)"]
    C --> D["Manager Selects Linked Fault (Optional)"]
    D --> E["Form Pre-populates or Stores\ncanonical faultId"]
    E --> F["Submit Maintenance Task\n(Linked to both Machine and Fault)"]
```

---

## 6. Manager Dashboard Statistics Reconciliation

To prevent mathematical discrepancies across the manager dashboard, `MachineStatistics` enforces exact partitioning:

$$\text{Total Machines} = \text{Running} + \text{In Maintenance} + \text{Breakdown} + \text{Other}$$

Status mappings are strictly normalized:
- **Running:** `Operational`, `Running`
- **In Maintenance:** `Under Maintenance`, `In Maintenance`
- **Breakdown:** `Critical`, `Breakdown`, `Broken`
- **Other:** `Warning`, `Offline`, `Unknown`

---

## 7. Storage Security & Image URL Resolution

Fault images are stored in a private bucket (`fault-images`). Image access requires an authenticated signed URL:

```mermaid
sequenceDiagram
    autonumber
    participant UI as Fault History / My Reports UI
    participant FaultSvc as FaultService
    participant Supabase as Supabase Storage

    UI->>FaultSvc: getFaultImageUrl(fault, callerRole, callerUid)
    FaultSvc->>FaultSvc: Validate caller permissions (Owner or Technician/Manager)
    FaultSvc->>Supabase: POST /storage/v1/object/sign/fault-images/{storagePath} (expiresIn: 3600s)
    Supabase-->>FaultSvc: Signed URL with temporary token
    FaultSvc-->>UI: Return signed URL
    UI->>UI: Render network image with auth token
```
