import 'package:flutter/material.dart';
import 'db_helper.dart';

/// Notes-app style list of past sessions. Tap a session to see who
/// was scanned under it (id, name, and whether it was a manual entry).
/// Reads from the local SQLite cache, which mirrors Supabase once synced.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _db = DBHelper.instance;
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await _db.getSessionHistory();
    setState(() {
      _sessions = sessions;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(child: Text('No sessions yet'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _sessions.length,
                    itemBuilder: (context, i) {
                      final s = _sessions[i];
                      return ListTile(
                        title: Text(s['session_name'] as String),
                        subtitle: Text('${s['date']} · ${s['scan_count']} scanned'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SessionDetailScreen(
                              sessionName: s['session_name'] as String,
                              date: s['date'] as String,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class SessionDetailScreen extends StatefulWidget {
  final String sessionName;
  final String date;

  const SessionDetailScreen(
      {super.key, required this.sessionName, required this.date});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final _db = DBHelper.instance;
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _db.getSessionEntries(widget.sessionName, widget.date);
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.sessionName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(child: Text('No one scanned in this session'))
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, i) {
                    final e = _entries[i];
                    final isManual = e['is_manual'] == 1;
                    return ListTile(
                      leading: Icon(
                        isManual ? Icons.edit_note : Icons.qr_code_scanner,
                        color: isManual ? Colors.orange : Colors.green,
                      ),
                      title: Text((e['student_name'] as String?)?.isNotEmpty == true
                          ? e['student_name'] as String
                          : e['student_id'] as String),
                      subtitle: Text(
                          'ID: ${e['student_id']}${isManual ? " · manual entry" : ""}'),
                    );
                  },
                ),
    );
  }
}
