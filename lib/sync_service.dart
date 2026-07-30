import 'package:supabase_flutter/supabase_flutter.dart';
import 'db_helper.dart';

/// Handles all traffic between the local SQLite cache and Supabase.
class SyncService {
  final _supabase = Supabase.instance.client;
  final _db = DBHelper.instance;

  Future<void> pullRoster() async {
    final rows = await _supabase.from('students').select();
    await _db.replaceRoster(List<Map<String, dynamic>>.from(rows));
  }

  Future<void> pushAll() async {
    await _pushStudents();
    await _pushSessions();
    await _pushAttendance();
  }

  Future<void> _pushStudents() async {
    final unsynced = await _db.getUnsyncedStudents();
    for (final s in unsynced) {
      try {
        await _supabase.from('students').upsert({
          'id_number': s['id_number'],
          'name': s['name'],
          'dept': s['dept'],
          'year': s['year'],
        });
        await _db.markStudentSynced(s['id_number']);
      } catch (_) {
        // leave unsynced, retry next time
      }
    }
  }

  Future<void> _pushSessions() async {
    final db = await _db.database;
    final sessions = await db.query('sessions');
    for (final s in sessions) {
      try {
        await _supabase.from('sessions').upsert({
          'session_name': s['session_name'],
          'date': s['date'],
        }, onConflict: 'session_name,date');
      } catch (_) {
        // idempotent upsert, safe to retry
      }
    }
  }

  Future<void> _pushAttendance() async {
    final unsynced = await _db.getUnsyncedAttendance();
    for (final r in unsynced) {
      try {
        await _supabase.from('attendance_records').upsert({
          'session_name': r['session_name'],
          'date': r['date'],
          'student_id': r['student_id'],
          'scanned_at': r['scanned_at'],
          'is_manual': r['is_manual'] == 1,
        }, onConflict: 'session_name,date,student_id');
        await _db.markAttendanceSynced(r['local_id'] as int);
      } catch (_) {
        // leave unsynced, retry next time
      }
    }
  }
}
