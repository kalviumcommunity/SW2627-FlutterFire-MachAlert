# ⚠️ MachAlert Known Limitations & Technical Boundaries

To maintain engineering transparency and integrity, this document details the architectural boundaries, system limitations, and intentional design trade-offs of the current MachAlert release.

---

## 1. No Standalone `inspections` Firestore Collection

### Context
Industrial maintenance frequently references regular machine inspections (e.g., daily visual checklists, vibration audits).

### Current Reality & Implementation
- The current Firestore schema does not include a standalone `inspections` collection.
- In both `MachineDetailsScreen` and `ReportsScreen` (Inspections Tab), the application **strictly avoids fabricating simulated inspection records**.
- Instead, the UI displays an explicit, honest empty state informing the user:
  > *"No inspection records are currently logged for this machine. Regular shift inspections can be recorded once the inspections schema is provisioned."*
- Future Roadmap: Provision an `inspections` subcollection under `machines/{machineId}/inspections` with scheduled checklist templates.

---

## 2. No Continuous IoT Time-Series Telemetry Engine

### Context
Industrial dashboards often display continuous temperature, vibration, or spindle RPM curves.

### Current Reality & Implementation
- MachAlert is designed as a human-reported fault management system, not a hardware-connected SCADA or high-frequency IoT streaming platform.
- Previous placeholder UI rendered simulated sinusoidal curves which could mislead operators into assuming real-time sensor integration.
- The updated `ReportsScreen` removes simulated trend curves and replaces them with actual historical breakdown data derived from authentic `faults` records.
- When historical records for a selected date filter are insufficient, an honest empty/insufficient data state is displayed.

---

## 3. No Automated Orphan Asset Cleaner on Supabase Storage

### Context
When a user submits a fault report with an attached image, the binary object is stored in Supabase Storage (`fault-images/{uid}/{filename}`) and referenced by `storagePath` on the Firestore `faults` document.

### Current Reality & Implementation
- If a fault document is subsequently deleted from Firestore, the associated binary file remains in the Supabase Storage bucket.
- No automated Cloud Function or database trigger currently garbage-collects orphaned storage objects upon document deletion.
- Managers can manually delete storage objects using administrative tools or Supabase Dashboard.
- Future Roadmap: Deploy a Cloud Function trigger (`onDocumentDeleted('faults/{faultId}')`) or scheduled cron job to reconcile and purge unreferenced storage paths.

---

## 4. Manual Custom Claims Provisioning via Admin Script

### Context
To enforce Row-Level Security (RLS) in Supabase Storage based on user roles (`operator`, `technician`, `manager`), the user's JWT token must include the `machalert_role` claim.

### Current Reality & Implementation
- Firebase Authentication does not natively mirror Firestore document fields into JWT claims upon user registration.
- Currently, role synchronization is handled via an administrative Node.js script:
  ```bash
  node scripts/admin/provision_supabase_claims.js --apply
  ```
- New users who register do not automatically receive custom claims until the provisioning script is executed or triggered by an administrator.
- Future Roadmap: Deploy a Firebase Auth `beforeUserCreated` or `onUserCreated` Cloud Function to automatically inject `machalert_role` into custom claims upon signup.

---

## 5. Headless Test Environment Uses Mock Hardware & Network Drivers

### Context
MachAlert's automated test suite includes 977 comprehensive unit, widget, and integration tests covering the entire application lifecycle.

### Current Reality & Implementation
- Tests running in headless CI (`ubuntu-latest`) or local test runners execute against mocked platform channels (`camera`, `image_picker`, `supabase_client`, `cloud_firestore`).
- Physical optical camera sensors, hardware image compression, and live carrier network latency variations cannot be fully simulated in headless widget tests.
- Physical device testing on real Android hardware remains a required pre-release validation step for camera ergonomics and touch responsiveness.
