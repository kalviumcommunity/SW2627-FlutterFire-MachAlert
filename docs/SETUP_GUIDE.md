# 🛠️ MachAlert Setup & Installation Guide

This guide walks through configuring and running the MachAlert mobile application, including Firebase backend setup, Supabase Storage integration, custom claims provisioning, and Android release compilation.

---

## 1. System Prerequisites

Ensure the following tools and SDKs are installed on your workstation:

| Tool | Recommended Version | Verification Command |
|---|---|---|
| **Flutter SDK** | `>= 3.29.0` (channel stable) | `flutter --version` |
| **Dart SDK** | `>= 3.7.0` | `dart --version` |
| **Java JDK** | `OpenJDK 17` (Temurin recommended) | `java -version` |
| **Android SDK** | API Level 34+ / Build-Tools 34.0.0 | `sdkmanager --list` |
| **Node.js** | `>= 20.x` | `node -v` |
| **npm** | `>= 10.x` | `npm -v` |
| **Firebase CLI** | `>= 13.x` | `firebase --version` |

---

## 2. Repository Setup

Clone the repository and initialize Flutter dependencies:

```bash
git clone https://github.com/kalviumcommunity/SW2627-FlutterFire-MachAlert.git
cd SW2627-FlutterFire-MachAlert
flutter pub get
```

---

## 3. Firebase Configuration

MachAlert uses Firebase for user authentication, real-time Firestore database storage, and role profiles.

### A. Firebase Authentication
1. Navigate to the [Firebase Console](https://console.firebase.google.com).
2. Select or create your Firebase project.
3. Enable **Email/Password** authentication in **Build > Authentication > Sign-in method**.

### B. Cloud Firestore
1. Create a Cloud Firestore database in production mode.
2. Deploy the security rules defined in `firestore.rules`:
   ```bash
   firebase deploy --only firestore:rules
   ```
3. Deploy Firestore composite indexes defined in `firestore.indexes.json`:
   ```bash
   firebase deploy --only firestore:indexes
   ```

### C. Android Platform Registration
1. Register your Android app package name: `com.example.mach_alert`.
2. Add your SHA-1 and SHA-256 fingerprint hashes to the Firebase Android app configuration.
3. Download `google-services.json` and place it at:
   ```text
   android/app/google-services.json
   ```

---

## 4. Supabase Storage Configuration

MachAlert utilizes Supabase Storage for secure, scalable object storage with Row-Level Security (RLS) and signed URL generation.

### A. Create Supabase Project
1. Open the [Supabase Dashboard](https://supabase.com/dashboard) and create a new project.
2. Note your **Project URL** and **Anon Key** from **Project Settings > API**.

### B. Create Storage Bucket
1. Go to **Storage > New Bucket**.
2. Name the bucket: `fault-images`.
3. Set the bucket to **Private** (public access disabled).

### C. Apply Row-Level Security (RLS) Policies
In the Supabase SQL Editor, run the script provided in `scripts/supabase/storage_rls_policies.sql`:

```sql
-- Enable RLS on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 1. Read Policy: Signed URLs or Authenticated Users
CREATE POLICY "Allow authenticated reads and signed URLs"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'fault-images');

-- 2. Insert Policy: Users can only upload to their own user prefix
CREATE POLICY "Allow users to upload to their own folder"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'fault-images' AND
  (storage.foldername(name))[1] = auth.uid()
);

-- 3. Delete Policy: Managers can delete any image; users can delete their own
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

## 5. Firebase Custom Claims Provisioning

To enable Supabase to verify user roles in JWT claims, users must have custom claims assigned in Firebase Authentication.

### A. Install Dependencies
```bash
cd scripts/admin
npm install
```

### B. Configure Service Account
Download your Firebase Admin SDK service account key JSON file from **Firebase Console > Project Settings > Service accounts > Generate new private key**.

Set the path to your service account key:
```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccountKey.json"
```

### C. Execute Provisioning Script
1. **Dry-Run Mode (Preview changes without applying):**
   ```bash
   npm run provision:dry-run
   ```
2. **Apply Mode (Write claims to Firebase Auth):**
   ```bash
   npm run provision:apply
   ```

---

## 6. Android Release Signing Configuration

For local release builds or production packaging, configure your keystore.

### A. Generate Upload Keystore (If not already created)
```bash
keytool -genkeypair -v \
  -keystore ~/.machalert/machalert-upload.jks \
  -alias machalert-upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

### B. Configure `android/key.properties`
Create `android/key.properties` with the following contents:
```properties
storeFile=/path/to/machalert-upload.jks
storePassword=your_keystore_password
keyAlias=machalert-upload
keyPassword=your_key_password
```

> [!WARNING]
> Never commit `key.properties` or `.jks` keystores to git. They are ignored in `.gitignore`.

---

## 7. Running the Application

### Debug Mode (with Supabase Storage configured)
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<your-project-id>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key> \
  --dart-define=SUPABASE_BUCKET=fault-images
```

### Debug Mode (Photo-free offline mode)
```bash
flutter run
```

---

## 8. Automated Testing & Verification

Run the complete test suite:
```bash
# Run Flutter unit and widget tests
flutter test

# Run Node.js administrative provisioning tests
cd scripts/admin && npm test && cd ../..
```

Build the release APK:
```bash
flutter build apk --release
```
Verify the APK artifact:
```bash
ls -lh build/app/outputs/flutter-apk/app-release.apk
```
