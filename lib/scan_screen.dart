import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'db_helper.dart';

class ScanScreen extends StatefulWidget {
  final String sessionName;
  final String date; // yyyy-MM-dd

  const ScanScreen({super.key, required this.sessionName, required this.date});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _db = DBHelper.instance;
  final MobileScannerController _controller = MobileScannerController();

  bool _cooldown = false; // 2s guard against double-scanning
  String? _lastStatusMessage;
  Color _statusColor = Colors.grey;
  List<String> _recentScans = [];

  @override
  void initState() {
    super.initState();
    _db.ensureSession(widget.sessionName, widget.date);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_cooldown) return;

    final code = capture.barcodes.first.rawValue;
    if (code == null) return;

    setState(() => _cooldown = true);
    // 2 second cooldown after each successful trigger, to prevent double-scanning
    Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _cooldown = false);
    });

    final student = await _db.lookupStudent(code);

    if (student == null) {
      _promptManualEntry(code);
      return;
    }

    await _db.addAttendance(
        widget.sessionName, widget.date, code, student['name'] as String);
    setState(() {
      _lastStatusMessage = '${student['name']} scanned';
      _statusColor = Colors.green;
      _recentScans.add(code);
    });
  }

  void _promptManualEntry(String scannedId) {
    final nameCtrl = TextEditingController();
    final deptCtrl = TextEditingController();
    final yearCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ID not found — manual entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ID: $scannedId'),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: deptCtrl, decoration: const InputDecoration(labelText: 'Dept')),
            TextField(controller: yearCtrl, decoration: const InputDecoration(labelText: 'Year')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await _db.addLocalStudent(
                  scannedId, nameCtrl.text, deptCtrl.text, yearCtrl.text);
              await _db.addAttendance(
                  widget.sessionName, widget.date, scannedId, nameCtrl.text,
                  isManual: true);
              setState(() {
                _lastStatusMessage = '${nameCtrl.text} added & scanned (manual)';
                _statusColor = Colors.orange;
                _recentScans.add(scannedId);
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add & Scan'),
          ),
        ],
      ),
    );
  }

  Future<void> _undoLast() async {
    if (_recentScans.isEmpty) return;
    await _db.undoLastScan(widget.sessionName, widget.date);
    setState(() {
      _recentScans.removeLast();
      _lastStatusMessage = 'Last scan undone';
      _statusColor = Colors.grey;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.sessionName)),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: MobileScanner(controller: _controller, onDetect: _onDetect),
          ),
          Container(
            color: _statusColor.withOpacity(0.2),
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            child: Text(
              _lastStatusMessage ?? 'Scan an ID to begin',
              style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  onPressed: _recentScans.isEmpty ? null : _undoLast,
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo last scan'),
                ),
                Text('${_recentScans.length} scanned'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
