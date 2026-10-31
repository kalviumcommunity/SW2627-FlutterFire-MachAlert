import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/maintenance_update_model.dart';

void main() {
  group('MaintenanceUpdateModel Tests', () {
    final now = DateTime(2026, 10, 31, 10, 0);

    test('can be created with all fields', () {
      final update = MaintenanceUpdateModel(
        id: 'upd-001',
        taskId: 'task-100',
        previousStatus: 'Pending',
        newStatus: 'In Progress',
        notes: 'Commenced inspection of main spindle motor',
        proofImageUrl: 'https://storage.googleapis.com/test-bucket/proof1.jpg',
        updatedBy: 'tech_01',
        updatedAt: now,
      );

      expect(update.id, 'upd-001');
      expect(update.taskId, 'task-100');
      expect(update.previousStatus, 'Pending');
      expect(update.newStatus, 'In Progress');
      expect(update.notes, 'Commenced inspection of main spindle motor');
      expect(
        update.proofImageUrl,
        'https://storage.googleapis.com/test-bucket/proof1.jpg',
      );
      expect(update.updatedBy, 'tech_01');
      expect(update.updatedAt, now);
      expect(update.isStatusChange, isTrue);
      expect(update.hasNotes, isTrue);
      expect(update.hasProofImage, isTrue);
    });

    test('toMap serializes fields accurately', () {
      final update = MaintenanceUpdateModel(
        id: 'upd-002',
        taskId: 'task-200',
        previousStatus: 'In Progress',
        newStatus: 'Resolved',
        notes: 'Bearing replaced successfully',
        proofImageUrl: null,
        updatedBy: 'tech_02',
        updatedAt: now,
      );

      final map = update.toMap();
      expect(map['id'], 'upd-002');
      expect(map['taskId'], 'task-200');
      expect(map['previousStatus'], 'In Progress');
      expect(map['newStatus'], 'Resolved');
      expect(map['notes'], 'Bearing replaced successfully');
      expect(map['proofImageUrl'], isNull);
      expect(map['updatedBy'], 'tech_02');
      expect(map['updatedAt'], now.toIso8601String());
    });

    test('fromMap parses ISO string timestamp and docId fallback', () {
      final map = {
        'taskId': 'task-300',
        'previousStatus': 'In Progress',
        'newStatus': 'In Progress',
        'notes': 'Added lubricant to drive chain',
        'proofImageUrl': 'https://storage.googleapis.com/test/chain.jpg',
        'updatedBy': 'tech_03',
        'updatedAt': now.toIso8601String(),
      };

      final update = MaintenanceUpdateModel.fromMap(map, 'doc_upd_300');
      expect(update.id, 'doc_upd_300');
      expect(update.taskId, 'task-300');
      expect(update.previousStatus, 'In Progress');
      expect(update.newStatus, 'In Progress');
      expect(update.isStatusChange, isFalse);
      expect(update.updatedAt, now);
    });

    test('fromMap parses Firestore Timestamp and alternative field names', () {
      final timestamp = Timestamp.fromDate(now);
      final map = {
        'updateId': 'upd_alt_name',
        'taskId': 'task-400',
        'previousStatus': 'Pending',
        'newStatus': 'In Progress',
        'updatedBy': 'tech_04',
        'timestamp': timestamp,
      };

      final update = MaintenanceUpdateModel.fromMap(map);
      expect(update.id, 'upd_alt_name');
      expect(update.updatedAt, now);
      expect(update.hasNotes, isFalse);
      expect(update.hasProofImage, isFalse);
    });

    test('fromMap parses epoch millis timestamp', () {
      final map = {
        'id': 'upd_epoch',
        'taskId': 'task-500',
        'previousStatus': 'Pending',
        'newStatus': 'In Progress',
        'updatedBy': 'tech_05',
        'createdAt': now.millisecondsSinceEpoch,
      };

      final update = MaintenanceUpdateModel.fromMap(map);
      expect(
        update.updatedAt?.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      );
    });

    test('copyWith updates specified fields only', () {
      final original = MaintenanceUpdateModel(
        id: 'upd-orig',
        taskId: 't-1',
        previousStatus: 'Pending',
        newStatus: 'In Progress',
        updatedBy: 'tech_01',
        updatedAt: now,
      );

      final modified = original.copyWith(
        notes: 'Follow up completed',
        newStatus: 'Resolved',
      );

      expect(modified.id, 'upd-orig');
      expect(modified.taskId, 't-1');
      expect(modified.previousStatus, 'Pending');
      expect(modified.newStatus, 'Resolved');
      expect(modified.notes, 'Follow up completed');
      expect(modified.updatedBy, 'tech_01');
      expect(modified.updatedAt, now);
    });

    test('equality and hashCode contract', () {
      final u1 = MaintenanceUpdateModel(
        id: 'same_id',
        taskId: 't-1',
        previousStatus: 'Pending',
        newStatus: 'In Progress',
        notes: 'Notes',
        proofImageUrl: 'url',
        updatedBy: 'tech_1',
        updatedAt: now,
      );

      final u2 = MaintenanceUpdateModel(
        id: 'same_id',
        taskId: 't-1',
        previousStatus: 'Pending',
        newStatus: 'In Progress',
        notes: 'Notes',
        proofImageUrl: 'url',
        updatedBy: 'tech_1',
        updatedAt: now,
      );

      final u3 = u1.copyWith(newStatus: 'Resolved');

      expect(u1, equals(u2));
      expect(u1.hashCode, equals(u2.hashCode));
      expect(u1, isNot(equals(u3)));
      expect(u1.toString(), contains('upd'));
    });
  });
}
