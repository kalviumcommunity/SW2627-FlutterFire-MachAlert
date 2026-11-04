# 🛡️ Role-Based Access Control (RBAC) Specification

MachAlert implements a defense-in-depth security model enforcing Role-Based Access Control across three distinct layers:
1. **Client-Side UI Routing & Navigation Guards**
2. **Cloud Firestore Security Rules**
3. **Supabase Storage PostgreSQL Row-Level Security (RLS)**

---

## 1. System Roles

| Role | Target Persona | Primary Responsibilities |
|---|---|---|
| **`operator`** | Floor Machine Operator | Operates equipment, reports anomalies immediately, views personal reports (`My Reports`). |
| **`technician`** | Maintenance Technician | Inspects faults, manages assigned repair work orders, logs status transitions, attaches repair proof. |
| **`manager`** | Plant Maintenance Manager | Oversees machine inventory, creates/assigns tasks, analyzes fleet statistics, reviews plant reports. |

---

## 2. Comprehensive Permissions Matrix

| Feature / Resource | Action | Operator | Technician | Manager |
|---|---|:---:|:---:|:---:|
| **Machines** | View machine list & details | ✅ | ✅ | ✅ |
| | Create, edit, or delete machines | ❌ | ❌ | ✅ |
| **Fault Reports** | Submit new fault report | ✅ | ✅ | ✅ |
| | Upload fault image to storage | ✅ (Own folder) | ✅ (Own folder) | ✅ (Any folder) |
| | View personal submitted reports (`My Reports`) | ✅ | ✅ | ✅ |
| | View global fault history (`FaultHistoryScreen`) | ❌ (Redirected to My Reports) | ✅ | ✅ |
| | Delete or modify historical fault records | ❌ | ❌ | ✅ |
| **Maintenance Tasks** | View assigned maintenance tasks | ❌ | ✅ (Assigned only) | ✅ (All tasks) |
| | Create new maintenance work order | ❌ | ❌ | ✅ |
| | Transition task status (`Pending` → `In Progress` → `Resolved`) | ❌ | ✅ (Assigned only) | ✅ |
| | Add repair notes & completion proof | ❌ | ✅ (Assigned only) | ✅ |
| **Reports & Analytics** | View overview & breakdown metrics | ❌ | ❌ | ✅ |
| **Administrative Claims**| Provision / manage JWT custom claims | ❌ | ❌ | Service Account / Admin |

---

## 3. UI Navigation & Routing Access Control

Navigation guards are implemented in `lib/screens/dashboard/home_screen.dart` and `lib/screens/faults/fault_history_screen.dart`:

- **Operator Redirection:** If a user with the `operator` role attempts to open the global Fault History screen, the UI automatically redirects them to `MyReportsScreen` (`/faults/my-reports`), preventing exposure of company-wide incidents while providing a focused view of faults they personally submitted.
- **Role-Aware Dashboard:** Bottom navigation bar items adapt dynamically according to the authenticated user's role:
  - Operators see: `Dashboard`, `Machines`, `My Reports`.
  - Technicians see: `Dashboard`, `Machines`, `Faults`, `Maintenance`.
  - Managers see: `Dashboard`, `Machines`, `Faults`, `Maintenance`, `Reports`.

---

## 4. Cloud Firestore Security Rules Architecture

Cloud Firestore security rules (`firestore.rules`) validate identity and roles using both the `users/{uid}` profile document and Firebase Authentication token claims:

### Collection: `users/{userId}`
- **Read:** Any authenticated user can read public profile names to resolve human-readable reporter names.
- **Write:** Users can only update their own profile; managers can create/update all profiles.

### Collection: `machines/{machineId}`
- **Read:** All authenticated users (`operator`, `technician`, `manager`) have read access.
- **Write:** Strictly restricted to users with `role == 'manager'`.

### Collection: `faults/{faultId}`
- **Create:** Any authenticated user can create a fault document. The rule validates that `request.resource.data.reportedBy == request.auth.uid`.
- **Read:** Technicians and managers can read all faults. Operators can read faults where `resource.data.reportedBy == request.auth.uid`.
- **Update/Delete:** Restricted to managers or assigned technicians updating fault resolution status.

### Collection: `maintenance/{taskId}`
- **Create:** Restricted to `manager`.
- **Read:** Managers can read all tasks; technicians can read tasks assigned to them (`resource.data.technicianId == request.auth.uid`).
- **Update:** Assigned technicians can update status and append to `updateHistory`; managers can update all fields.
- **Delete:** Strictly restricted to `manager`.

---

## 5. Supabase Storage Row-Level Security (RLS) Policies

Supabase Storage enforces isolation directly at the PostgreSQL layer using JWT token claims:

### Token Claims Structure
When users authenticate with Supabase using their Firebase custom claims or service token:
```json
{
  "sub": "user_uid_12345",
  "role": "authenticated",
  "machalert_role": "operator"
}
```

### Storage RLS Policies (`storage.objects`)

```sql
-- 1. SELECT (Read / Download / Signed URL generation)
CREATE POLICY "Allow authenticated reads and signed URLs"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'fault-images');

-- 2. INSERT (Upload)
-- Restricts uploads to the user's isolated subfolder: fault-images/{uid}/{filename}
CREATE POLICY "Allow users to upload to their own folder"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'fault-images' AND
  (storage.foldername(name))[1] = auth.uid()
);

-- 3. DELETE (Removal)
-- Users can delete their own uploaded files; managers can delete any file
CREATE POLICY "Allow owners and managers to delete images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'fault-images' AND (
    (storage.foldername(name))[1] = auth.uid() OR
    (auth.jwt() ->> 'machalert_role') = 'manager'
  )
);
```

---

## 6. Custom Claims Synchronization

To keep Firebase Auth JWT claims synchronized with Firestore user roles, an administrative CLI utility is provided at `scripts/admin/provision_supabase_claims.js`.

### How It Works:
1. Queries the Firestore `users` collection for all registered profiles.
2. Reads the `role` field (`operator`, `technician`, or `manager`).
3. Updates Firebase Authentication custom claims via `admin.auth().setCustomUserClaims()`:
   ```javascript
   await admin.auth().setCustomUserClaims(uid, {
     ...existingClaims,
     role: 'authenticated',
     machalert_role: resolvedRole
   });
   ```
4. Provides a dry-run mode (`npm run provision:dry-run`) to preview claims without mutating production state.
