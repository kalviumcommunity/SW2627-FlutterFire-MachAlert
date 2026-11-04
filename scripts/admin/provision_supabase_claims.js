#!/usr/bin/env node

/**
 * MACHALERT — ADMINISTRATIVE PROVISIONING SCRIPT
 *
 * Configures Firebase Authentication Custom Claims for Supabase Storage integration.
 * Supabase third-party auth requires the Firebase ID token to contain:
 * {
 *   "role": "authenticated",
 *   "machalert_role": "manager" | "technician" | "operator"
 * }
 *
 * Rules:
 * - Reads trusted user role strictly from Cloud Firestore: `users/{firebaseUid}`
 * - Allowed roles: manager, technician, operator
 * - Preserves all existing custom claims
 * - Skips users without an existing valid Firestore profile
 * - Never defaults unknown users to any role
 * - Enforces Firebase custom-claims payload limits (max 1000 bytes)
 * - Detects incompatible existing `role` claims and reports them
 * - Requires explicit --apply flag to modify production claims
 * - Default or --dry-run mode makes NO changes
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const ALLOWED_ROLES = Object.freeze(['manager', 'technician', 'operator']);
const MAX_CLAIMS_PAYLOAD_BYTES = 1000;
const DEFAULT_PROJECT_ID = 'machalert';

/**
 * Parses CLI arguments.
 */
function parseArgs(argv) {
  const args = {
    dryRun: true,
    apply: false,
    projectId: DEFAULT_PROJECT_ID,
    credentialsPath: process.env.GOOGLE_APPLICATION_CREDENTIALS || null,
    usersFilePath: null,
    firestoreFilePath: null,
  };

  for (const arg of argv.slice(2)) {
    if (arg === '--dry-run') {
      args.dryRun = true;
      args.apply = false;
    } else if (arg === '--apply') {
      args.apply = true;
      args.dryRun = false;
    } else if (arg.startsWith('--project=')) {
      args.projectId = arg.split('=')[1].trim();
    } else if (arg.startsWith('--credentials=')) {
      args.credentialsPath = arg.split('=')[1].trim();
    } else if (arg.startsWith('--users-file=')) {
      args.usersFilePath = arg.split('=')[1].trim();
    } else if (arg.startsWith('--firestore-file=')) {
      args.firestoreFilePath = arg.split('=')[1].trim();
    } else if (arg === '--help' || arg === '-h') {
      console.log(`
MachAlert — Supabase Claims Provisioning Script

Usage:
  node provision_supabase_claims.js [options]

Options:
  --dry-run                 Inspect users and simulate provisioning without making changes (default)
  --apply                   Execute actual custom claims updates on Firebase Authentication
  --credentials=<path>      Path to Google Service Account JSON (or use GOOGLE_APPLICATION_CREDENTIALS)
  --project=<id>            Firebase project ID (defaults to 'machalert')
  --users-file=<path>       Path to exported auth users JSON file (for offline audit/dry-run)
  --firestore-file=<path>   Path to Firestore users export JSON file (for offline audit/dry-run)
  --help, -h                Show this help message
      `);
      process.exit(0);
    }
  }

  return args;
}

/**
 * Initializes Firebase Admin securely without exposing private keys.
 */
function initializeAdmin(options = {}) {
  if (admin.apps.length > 0) {
    return admin.app();
  }

  const projectId = options.projectId || DEFAULT_PROJECT_ID;
  const credentialsPath = options.credentialsPath;

  let credential;
  if (credentialsPath) {
    const resolvedPath = path.resolve(credentialsPath);
    if (!fs.existsSync(resolvedPath)) {
      throw new Error(`Credentials file not found at: ${resolvedPath}`);
    }
    credential = admin.credential.cert(require(resolvedPath));
  } else {
    try {
      credential = admin.credential.applicationDefault();
    } catch (err) {
      throw new Error(
        'Unable to initialize Application Default Credentials.\n' +
        'Please export GOOGLE_APPLICATION_CREDENTIALS="path/to/serviceAccount.json"\n' +
        'or pass --credentials="path/to/serviceAccount.json".'
      );
    }
  }

  return admin.initializeApp({
    credential,
    projectId,
  });
}

/**
 * Evaluates custom claims for a single user record based on their Firestore profile.
 * Pure function designed for both execution and unit testing.
 *
 * @param {Object} authUser - Firebase Auth user record ({ uid, email, customClaims })
 * @param {Object|null} firestoreProfile - User document data from `users/{uid}`
 * @returns {Object} Evaluation result with action, newClaims, reason, etc.
 */
function evaluateUserClaims(authUser, firestoreProfile) {
  const uid = authUser.uid;
  const email = authUser.email || '(no email)';
  const existingClaims = authUser.customClaims || {};

  // 1. Validate Firestore profile existence
  if (!firestoreProfile) {
    return {
      uid,
      email,
      action: 'SKIP',
      reason: `Missing Firestore profile at users/${uid}`,
      existingClaims,
      proposedClaims: null,
    };
  }

  // 2. Read and validate trusted application role
  const rawRole = firestoreProfile.role;
  if (!rawRole || typeof rawRole !== 'string') {
    return {
      uid,
      email,
      action: 'SKIP',
      reason: `Firestore profile at users/${uid} does not define a string "role" field`,
      existingClaims,
      proposedClaims: null,
    };
  }

  const role = rawRole.trim().toLowerCase();
  if (!ALLOWED_ROLES.includes(role)) {
    return {
      uid,
      email,
      action: 'SKIP',
      reason: `Invalid application role "${rawRole}" in users/${uid}. Must be one of: ${ALLOWED_ROLES.join(', ')}`,
      existingClaims,
      proposedClaims: null,
    };
  }

  // 3. Check for conflicting existing 'role' claim
  const incompatibleRole =
    existingClaims.role !== undefined && existingClaims.role !== 'authenticated';
  const warnings = [];
  if (incompatibleRole) {
    warnings.push(
      `Warning: Overwriting incompatible existing role claim "${existingClaims.role}" with "authenticated"`
    );
  }

  // 4. Construct updated claims preserving all other claims
  const proposedClaims = {
    ...existingClaims,
    role: 'authenticated',
    machalert_role: role,
  };

  // 5. Enforce payload size limit (Firebase restricts custom claims to 1000 bytes)
  const payloadString = JSON.stringify(proposedClaims);
  const payloadBytes = Buffer.byteLength(payloadString, 'utf8');
  if (payloadBytes > MAX_CLAIMS_PAYLOAD_BYTES) {
    return {
      uid,
      email,
      action: 'FAIL',
      reason: `Custom claims payload size (${payloadBytes} bytes) exceeds Firebase limit of ${MAX_CLAIMS_PAYLOAD_BYTES} bytes`,
      existingClaims,
      proposedClaims,
      warnings,
    };
  }

  // 6. Check if claims are already identical
  const isIdentical =
    existingClaims.role === 'authenticated' &&
    existingClaims.machalert_role === role &&
    Object.keys(existingClaims).every(
      (k) => (k === 'role' || k === 'machalert_role') || existingClaims[k] === proposedClaims[k]
    );

  if (isIdentical) {
    return {
      uid,
      email,
      action: 'UNCHANGED',
      role,
      reason: 'Claims already up to date',
      existingClaims,
      proposedClaims,
      warnings,
    };
  }

  return {
    uid,
    email,
    action: 'PROVISION',
    role,
    reason: 'Requires claims provisioning',
    existingClaims,
    proposedClaims,
    warnings,
  };
}

/**
 * Fetches all users from Firebase Auth (or offline export) and provisions their custom claims.
 *
 * @param {Object} options - { dryRun, apply, auth, db, usersFilePath, firestoreFilePath }
 */
async function runProvisioning(options) {
  const { dryRun, apply, auth, db, usersFilePath, firestoreFilePath } = options;

  console.log('='.repeat(72));
  console.log(`MACHALERT SUPABASE CLAIMS PROVISIONING [MODE: ${apply ? 'APPLY (LIVE)' : 'DRY-RUN'}]`);
  console.log('='.repeat(72));

  const results = {
    provisioned: [],
    unchanged: [],
    skipped: [],
    failed: [],
  };

  let authUsers = [];
  if (usersFilePath && fs.existsSync(usersFilePath)) {
    const raw = JSON.parse(fs.readFileSync(usersFilePath, 'utf8'));
    const list = Array.isArray(raw) ? raw : (raw.users || []);
    authUsers = list.map((u) => ({
      uid: u.localId || u.uid,
      email: u.email,
      customClaims: u.customAttributes ? JSON.parse(u.customAttributes) : (u.customClaims || {}),
    }));
    console.log(`Loaded ${authUsers.length} user(s) from offline export: ${usersFilePath}`);
  } else if (auth) {
    let nextPageToken;
    try {
      do {
        const listResult = await auth.listUsers(100, nextPageToken);
        authUsers.push(...listResult.users);
        nextPageToken = listResult.pageToken;
      } while (nextPageToken);
      console.log(`Found ${authUsers.length} Firebase Authentication user(s) via Admin SDK.\n`);
    } catch (authErr) {
      if (
        authErr.message &&
        (authErr.message.includes('metadata.google.internal') ||
          authErr.message.includes('access token') ||
          authErr.message.includes('credentials') ||
          authErr.message.includes('ENOTFOUND'))
      ) {
        console.log('\n[NOTICE] Google Service Account credentials not detected in this environment.');
        console.log('To run claims provisioning against the live "machalert" Firebase project:\n');
        console.log('  1. Generate a Service Account Private Key in Firebase Console:');
        console.log('     Project settings -> Service accounts -> "Generate new private key"');
        console.log('  2. Set the environment variable:');
        console.log('     export GOOGLE_APPLICATION_CREDENTIALS="path/to/serviceAccountKey.json"');
        console.log('  3. Re-run:');
        console.log('     node scripts/admin/provision_supabase_claims.js --dry-run');
        console.log('     node scripts/admin/provision_supabase_claims.js --apply\n');
        return results;
      }
      throw authErr;
    }
  } else {
    throw new Error('No authentication provider available. Pass live Admin SDK auth or --users-file=<path>.');
  }

  let offlineFirestore = null;
  if (firestoreFilePath && fs.existsSync(firestoreFilePath)) {
    offlineFirestore = JSON.parse(fs.readFileSync(firestoreFilePath, 'utf8'));
    console.log(`Loaded offline Firestore profiles from: ${firestoreFilePath}`);
  }

  for (const user of authUsers) {
    let firestoreProfile = null;
    if (offlineFirestore && offlineFirestore[user.uid]) {
      firestoreProfile = offlineFirestore[user.uid];
    } else if (db) {
      try {
        const docSnap = await db.collection('users').doc(user.uid).get();
        if (docSnap.exists) {
          firestoreProfile = docSnap.data();
        }
      } catch (err) {
        results.failed.push({
          uid: user.uid,
          email: user.email,
          reason: `Firestore read error for users/${user.uid}: ${err.message}`,
        });
        continue;
      }
    }

    // 3. Evaluate claims
    const evaluation = evaluateUserClaims(user, firestoreProfile);

    if (evaluation.warnings && evaluation.warnings.length > 0) {
      evaluation.warnings.forEach((w) => console.warn(`[WARN] ${user.uid}: ${w}`));
    }

    if (evaluation.action === 'SKIP') {
      console.log(`[-] SKIP      | ${evaluation.uid} | ${evaluation.email} | ${evaluation.reason}`);
      results.skipped.push(evaluation);
    } else if (evaluation.action === 'UNCHANGED') {
      console.log(`[=] UNCHANGED | ${evaluation.uid} | ${evaluation.email} | Role: ${evaluation.role}`);
      results.unchanged.push(evaluation);
    } else if (evaluation.action === 'FAIL') {
      console.error(`[!] FAIL      | ${evaluation.uid} | ${evaluation.email} | ${evaluation.reason}`);
      results.failed.push(evaluation);
    } else if (evaluation.action === 'PROVISION') {
      if (apply) {
        if (!auth) {
          throw new Error('Cannot apply live updates without Firebase Admin Authentication credentials.');
        }
        try {
          await auth.setCustomUserClaims(evaluation.uid, evaluation.proposedClaims);
          console.log(`[+] APPLIED   | ${evaluation.uid} | ${evaluation.email} | Assigned machalert_role: "${evaluation.role}"`);
          results.provisioned.push(evaluation);
        } catch (err) {
          console.error(`[!] ERROR     | ${evaluation.uid} | Failed to set claims: ${err.message}`);
          results.failed.push({ ...evaluation, reason: err.message });
        }
      } else {
        console.log(`[*] WOULD SET | ${evaluation.uid} | ${evaluation.email} | New claims: ${JSON.stringify(evaluation.proposedClaims)}`);
        results.provisioned.push(evaluation);
      }
    }
  }

  console.log('\n' + '-'.repeat(72));
  console.log('SUMMARY REPORT:');
  console.log(`  Total Users Examined : ${authUsers.length}`);
  console.log(`  ${apply ? 'Successfully Updated' : 'Pending Update (Dry-Run)'} : ${results.provisioned.length}`);
  console.log(`  Already Up to Date   : ${results.unchanged.length}`);
  console.log(`  Skipped (No Profile) : ${results.skipped.length}`);
  console.log(`  Failed               : ${results.failed.length}`);
  console.log('-'.repeat(72));

  if (dryRun) {
    console.log('\n[NOTICE] Dry-run completed. No changes were made to Firebase Authentication.');
    console.log('To apply these changes, run with the explicit --apply flag:');
    console.log('  node scripts/admin/provision_supabase_claims.js --apply\n');
  }

  return results;
}

// Main execution when invoked directly from CLI
if (require.main === module) {
  const options = parseArgs(process.argv);

  let auth = null;
  let db = null;

  try {
    initializeAdmin(options);
    auth = admin.auth();
    db = admin.firestore();
  } catch (err) {
    if (!options.usersFilePath) {
      console.log('='.repeat(72));
      console.log('MACHALERT SUPABASE CLAIMS PROVISIONING [MODE: DRY-RUN]');
      console.log('='.repeat(72));
      console.log('\n[INFO] Firebase Admin Service Account credentials not currently detected.');
      console.log('To run provisioning against the live Firebase project:\n');
      console.log('  1. Generate a Service Account Private Key in Firebase Console:');
      console.log('     Project settings -> Service accounts -> "Generate new private key"');
      console.log('  2. Set the environment variable:');
      console.log('     export GOOGLE_APPLICATION_CREDENTIALS="path/to/serviceAccountKey.json"');
      console.log('  3. Run dry-run or apply:');
      console.log('     node scripts/admin/provision_supabase_claims.js --dry-run');
      console.log('     node scripts/admin/provision_supabase_claims.js --apply\n');
      process.exit(0);
    }
  }

  runProvisioning({
    dryRun: options.dryRun,
    apply: options.apply,
    auth,
    db,
    usersFilePath: options.usersFilePath,
    firestoreFilePath: options.firestoreFilePath,
  })
    .then((results) => {
      if (results.failed.length > 0) {
        process.exit(1);
      }
    })
    .catch((err) => {
      console.error('Fatal execution error:', err.message);
      process.exit(1);
    });
}

module.exports = {
  ALLOWED_ROLES,
  MAX_CLAIMS_PAYLOAD_BYTES,
  parseArgs,
  initializeAdmin,
  evaluateUserClaims,
  runProvisioning,
};
