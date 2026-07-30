import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'sync_service.dart';
import 'scan_screen.dart';
import 'history_screen.dart';

// TODO: fill in from Supabase project settings > API
const supabaseUrl = 'https://jwoqpdupvqqbkgeaawwv.supabase.co';
const supabaseAnonKey = 'sb_publishable_AFWwx4XOXKGDwTt-9k-zZQ_rd5X9Qc_';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance Scanner',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sync = SyncService();
  final _sessionCtrl = TextEditingController();
  String _syncStatus = 'Not synced yet';

  @override
  void initState() {
    super.initState();
    _trySync();
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) _trySync();
    });
  }

  Future<void> _trySync() async {
    try {
      await _sync.pushAll();
      await _sync.pullRoster();
      setState(() => _syncStatus = 'Synced ${DateTime.now().toLocal()}');
    } catch (e) {
      print('Sync error: $e');
      setState(() => _syncStatus = 'Offline — using cached roster');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Session History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_syncStatus, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            TextField(
              controller: _sessionCtrl,
              decoration: const InputDecoration(
                labelText: 'Session name',
                hintText: 'e.g. General Meeting - July 27',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (_sessionCtrl.text.trim().isEmpty) return;
                final date = DateTime.now().toIso8601String().substring(0, 10);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScanScreen(
                      sessionName: _sessionCtrl.text.trim(),
                      date: date,
                    ),
                  ),
                ).then((_) => _load()); // refresh sync status after returning
              },
              child: const Text('Start Scanning'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.history),
              label: const Text('View Session History'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _load() {
    setState(() {});
  }
}
