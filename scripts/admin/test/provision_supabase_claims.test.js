/**
 * Unit Tests for MachAlert Supabase Claims Provisioning Script
 */

const assert = require('assert');
const {
  evaluateUserClaims,
  runProvisioning,
  ALLOWED_ROLES,
  MAX_CLAIMS_PAYLOAD_BYTES,
} = require('../provision_supabase_claims');

async function runTests() {
  console.log('Running Claims Provisioning Unit Tests...\n');
  let passed = 0;
  let total = 0;

  function test(description, fn) {
    total++;
    try {
      fn();
      console.log(`✓ ${description}`);
      passed++;
    } catch (err) {
      console.error(`✗ ${description}`);
      console.error(err);
    }
  }

  async function testAsync(description, fn) {
    total++;
    try {
      await fn();
      console.log(`✓ ${description}`);
      passed++;
    } catch (err) {
      console.error(`✗ ${description}`);
      console.error(err);
    }
  }

  // 1. Manager claims provisioning
  test('1. Manager claims provisioning generates correct claims', () => {
    const user = { uid: 'mgr-001', email: 'mgr@machalert.com', customClaims: {} };
    const profile = { role: 'manager', name: 'Factory Manager' };
    const res = evaluateUserClaims(user, profile);

    assert.strictEqual(res.action, 'PROVISION');
    assert.strictEqual(res.role, 'manager');
    assert.deepStrictEqual(res.proposedClaims, {
      role: 'authenticated',
      machalert_role: 'manager',
    });
  });

  // 2. Technician claims provisioning
  test('2. Technician claims provisioning generates correct claims', () => {
    const user = { uid: 'tech-001', email: 'tech@machalert.com', customClaims: {} };
    const profile = { role: 'technician', name: 'Lead Tech' };
    const res = evaluateUserClaims(user, profile);

    assert.strictEqual(res.action, 'PROVISION');
    assert.strictEqual(res.role, 'technician');
    assert.deepStrictEqual(res.proposedClaims, {
      role: 'authenticated',
      machalert_role: 'technician',
    });
  });

  // 3. Operator claims provisioning
  test('3. Operator claims provisioning generates correct claims', () => {
    const user = { uid: 'op-001', email: 'op@machalert.com', customClaims: {} };
    const profile = { role: 'operator', name: 'Plant Operator' };
    const res = evaluateUserClaims(user, profile);

    assert.strictEqual(res.action, 'PROVISION');
    assert.strictEqual(res.role, 'operator');
    assert.deepStrictEqual(res.proposedClaims, {
      role: 'authenticated',
      machalert_role: 'operator',
    });
  });

  // 4. Existing custom-claim preservation
  test('4. Existing custom-claim preservation preserves unrelated claims', () => {
    const user = {
      uid: 'user-002',
      email: 'user@machalert.com',
      customClaims: { departmentId: 'line-3', shift: 'morning', betaTester: true },
    };
    const profile = { role: 'technician' };
    const res = evaluateUserClaims(user, profile);

    assert.strictEqual(res.action, 'PROVISION');
    assert.deepStrictEqual(res.proposedClaims, {
      departmentId: 'line-3',
      shift: 'morning',
      betaTester: true,
      role: 'authenticated',
      machalert_role: 'technician',
    });
  });

  // 5. Missing Firestore profile skipped safely
  test('5. Missing Firestore profile skipped safely', () => {
    const user = { uid: 'ghost-001', email: 'ghost@machalert.com', customClaims: {} };
    const res = evaluateUserClaims(user, null);

    assert.strictEqual(res.action, 'SKIP');
    assert.strictEqual(res.proposedClaims, null);
    assert(res.reason.includes('Missing Firestore profile'));
  });

  // 6. Invalid role rejected safely
  test('6. Invalid role rejected safely without defaulting', () => {
    const user = { uid: 'hacker-001', email: 'hacker@evil.com', customClaims: {} };
    const profile = { role: 'superadmin' };
    const res = evaluateUserClaims(user, profile);

    assert.strictEqual(res.action, 'SKIP');
    assert.strictEqual(res.proposedClaims, null);
    assert(res.reason.includes('Invalid application role'));
  });

  // 7. Role with leading/trailing whitespace or uppercase handled safely
  test('7. Roles are trimmed and case-insensitive', () => {
    const user = { uid: 'clean-001', email: 'clean@machalert.com', customClaims: {} };
    const profile = { role: '  Technician  ' };
    const res = evaluateUserClaims(user, profile);

    assert.strictEqual(res.action, 'PROVISION');
    assert.strictEqual(res.role, 'technician');
    assert.strictEqual(res.proposedClaims.machalert_role, 'technician');
  });

  // 8. Incompatible existing 'role' claim triggers a warning
  test('8. Incompatible existing role claim produces explicit warning', () => {
    const user = {
      uid: 'legacy-001',
      email: 'legacy@machalert.com',
      customClaims: { role: 'old_legacy_role' },
    };
    const profile = { role: 'manager' };
    const res = evaluateUserClaims(user, profile);

    assert.strictEqual(res.action, 'PROVISION');
    assert(res.warnings.length > 0);
    assert(res.warnings[0].includes('old_legacy_role'));
  });

  // 9. Payload size exceeding 1000 bytes is rejected
  test('9. Claims exceeding 1000 bytes fail with safety error', () => {
    const hugeCustomData = 'x'.repeat(1200);
    const user = {
      uid: 'bloated-001',
      email: 'bloated@machalert.com',
      customClaims: { extra: hugeCustomData },
    };
    const profile = { role: 'operator' };
    const res = evaluateUserClaims(user, profile);

    assert.strictEqual(res.action, 'FAIL');
    assert(res.reason.includes('exceeds Firebase limit'));
  });

  // 10. Already provisioned user marked UNCHANGED
  test('10. User already having correct claims is marked UNCHANGED', () => {
    const user = {
      uid: 'synced-001',
      email: 'synced@machalert.com',
      customClaims: { role: 'authenticated', machalert_role: 'manager' },
    };
    const profile = { role: 'manager' };
    const res = evaluateUserClaims(user, profile);

    assert.strictEqual(res.action, 'UNCHANGED');
  });

  // 11. Dry-run makes NO changes to Auth
  await testAsync('11. Dry-run makes NO changes to Firebase Authentication', async () => {
    let setCustomUserClaimsCalled = false;
    const mockAuth = {
      listUsers: async () => ({
        users: [
          { uid: 'u-1', email: 'u1@m.com', customClaims: {} },
        ],
        pageToken: null,
      }),
      setCustomUserClaims: async () => {
        setCustomUserClaimsCalled = true;
      },
    };

    const mockDb = {
      collection: () => ({
        doc: () => ({
          get: async () => ({
            exists: true,
            data: () => ({ role: 'operator' }),
          }),
        }),
      }),
    };

    const results = await runProvisioning({
      dryRun: true,
      apply: false,
      auth: mockAuth,
      db: mockDb,
    });

    assert.strictEqual(setCustomUserClaimsCalled, false);
    assert.strictEqual(results.provisioned.length, 1);
  });

  // 12. Apply mode invokes setCustomUserClaims
  await testAsync('12. Apply mode writes claims to Firebase Authentication', async () => {
    let updatedUid = null;
    let updatedClaims = null;
    const mockAuth = {
      listUsers: async () => ({
        users: [
          { uid: 'u-live', email: 'live@m.com', customClaims: {} },
        ],
        pageToken: null,
      }),
      setCustomUserClaims: async (uid, claims) => {
        updatedUid = uid;
        updatedClaims = claims;
      },
    };

    const mockDb = {
      collection: () => ({
        doc: () => ({
          get: async () => ({
            exists: true,
            data: () => ({ role: 'technician' }),
          }),
        }),
      }),
    };

    const results = await runProvisioning({
      dryRun: false,
      apply: true,
      auth: mockAuth,
      db: mockDb,
    });

    assert.strictEqual(updatedUid, 'u-live');
    assert.deepStrictEqual(updatedClaims, {
      role: 'authenticated',
      machalert_role: 'technician',
    });
    assert.strictEqual(results.provisioned.length, 1);
  });

  console.log(`\nTests completed: ${passed}/${total} passed.`);
  if (passed !== total) {
    process.exit(1);
  }
}

runTests();
