import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/tracking_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<Map<String, dynamic>> _logs = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String _selectedFilter = 'All';

  static const _filters = ['All', 'Location', 'Events'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        TrackingService.getCollectedData(),
        TrackingService.getCollectionStats(),
      ]);

      if (!mounted) return;
      setState(() {
        _logs = results[0] as List<Map<String, dynamic>>;
        _stats = results[1] as Map<String, dynamic>;
      });
    } catch (error) {
      _showSnackBar('Failed to load logs: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredLogs {
    return _logs.where((log) {
      final source = log['source_file']?.toString() ?? '';
      switch (_selectedFilter) {
        case 'Location':
          return source == 'location_data.json' || log.containsKey('latitude');
        case 'Events':
          return log.containsKey('event');
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _copyLogs() async {
    final json = const JsonEncoder.withIndent('  ').convert(_filteredLogs);
    await Clipboard.setData(ClipboardData(text: json));
    _showSnackBar('Visible logs copied to clipboard');
  }

  Future<void> _clearLogs() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text(
          'Delete locally stored sharing records? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (shouldClear != true) return;

    await TrackingService.clearAllData();
    await _loadData();
    _showSnackBar('Logs cleared');
  }

  void _showLogDetails(Map<String, dynamic> log) {
    final formatted = const JsonEncoder.withIndent('  ').convert(log);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getLogTitle(log)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              formatted,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: formatted));
              Navigator.of(context).pop();
              _showSnackBar('Log copied to clipboard');
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  String _getLogTitle(Map<String, dynamic> log) {
    final event = log['event']?.toString();
    if (event != null && event.isNotEmpty) {
      return event.replaceAll('_', ' ');
    }

    final source = log['source_file']?.toString();
    if (source == 'location_data.json') return 'Location sample';
    return 'Log record';
  }

  String _getLogSubtitle(Map<String, dynamic> log) {
    final details = log['details']?.toString();
    if (details != null && details.isNotEmpty) return details;

    final latitude = log['latitude'];
    final longitude = log['longitude'];
    if (latitude is num && longitude is num) {
      return 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}';
    }

    return 'Tap to view details';
  }

  IconData _getLogIcon(Map<String, dynamic> log) {
    final source = log['source_file']?.toString();
    if (source == 'location_data.json') return Icons.location_on_outlined;
    if (log.containsKey('event')) return Icons.event_note_outlined;
    return Icons.info_outline;
  }

  String _formatTimestamp(dynamic timestamp) {
    final parsed = DateTime.tryParse(timestamp?.toString() ?? '');
    if (parsed == null) return 'Unknown time';

    final difference = DateTime.now().difference(parsed);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildLogsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_logs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 56),
            SizedBox(height: 12),
            Text('No timeline records available'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: _filters.map((filter) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: _selectedFilter == filter,
                    onSelected: (_) => setState(() => _selectedFilter = filter),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _filteredLogs.length,
              itemBuilder: (context, index) {
                final log = _filteredLogs[index];
                return Card(
                  child: ListTile(
                    leading: Icon(_getLogIcon(log)),
                    title: Text(_getLogTitle(log)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_getLogSubtitle(log)),
                        const SizedBox(height: 4),
                        Text(_formatTimestamp(log['timestamp'])),
                      ],
                    ),
                    onTap: () => _showLogDetails(log),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: TrackingService.getLocationData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = snapshot.data ?? [];
        if (records.isEmpty) {
          return const Center(child: Text('No location samples available'));
        }

        return RefreshIndicator(
          onRefresh: _loadData,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(_getLogSubtitle(record)),
                  subtitle: Text(_formatTimestamp(record['timestamp'])),
                  onTap: () => _showLogDetails(record),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Statistics',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _buildStatRow('Total Records', _stats['total_records']),
                  _buildStatRow('Locations', _stats['location_count']),
                  _buildStatRow('Events', _stats['event_count']),
                  _buildStatRow('Data Files', _stats['total_data_files']),
                  _buildStatRow('Sharing Active',
                      TrackingService.isTracking ? 'Yes' : 'No'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, Object? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value?.toString() ?? '0',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian Admin'),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _copyLogs,
            icon: const Icon(Icons.copy),
            tooltip: 'Copy visible logs',
          ),
          IconButton(
            onPressed: _clearLogs,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear logs',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: 'Timeline'),
            Tab(icon: Icon(Icons.location_on), text: 'Location'),
            Tab(icon: Icon(Icons.analytics), text: 'Stats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLogsTab(),
          _buildLocationTab(),
          _buildStatsTab(),
        ],
      ),
    );
  }
}
