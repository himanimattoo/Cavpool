import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/safety_event_model.dart';
import '../../services/safety_service.dart';
import '../../providers/auth_provider.dart';

class AdminSafetyDashboard extends StatefulWidget {
  const AdminSafetyDashboard({super.key});

  @override
  State<AdminSafetyDashboard> createState() => _AdminSafetyDashboardState();
}

class _AdminSafetyDashboardState extends State<AdminSafetyDashboard>
    with TickerProviderStateMixin {
  final SafetyService _safetyService = SafetyService();
  late TabController _tabController;
  
  SafetyEventStatus? _filterStatus;
  SafetyEventSeverity? _filterSeverity;
  SafetyEventSummary? _summary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSummary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    final summary = await _safetyService.getSafetyEventSummary();
    setState(() {
      _summary = summary;
    });
  }

  Future<void> _updateEventStatus(
    String eventId,
    SafetyEventStatus newStatus, {
    String? reviewNotes,
    String? resolution,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.userModel;

    if (currentUser == null) return;

    final success = await _safetyService.updateSafetyEventStatus(
      eventId,
      newStatus,
      reviewedBy: currentUser.uid,
      reviewNotes: reviewNotes,
      resolution: resolution,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Safety event status updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      _loadSummary(); // Refresh summary
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update safety event status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getIncidentTypeDisplay(SafetyIncidentType? type) {
    if (type == null) return 'General Safety Event';
    
    switch (type) {
      case SafetyIncidentType.harassment:
        return 'Harassment';
      case SafetyIncidentType.unsafeDriving:
        return 'Unsafe Driving';
      case SafetyIncidentType.routeDeviation:
        return 'Route Deviation';
      case SafetyIncidentType.inappropriateBehavior:
        return 'Inappropriate Behavior';
      case SafetyIncidentType.vehicleIssue:
        return 'Vehicle Issue';
      case SafetyIncidentType.identityMismatch:
        return 'Identity Mismatch';
      case SafetyIncidentType.threatOrIntimidation:
        return 'Threat or Intimidation';
      case SafetyIncidentType.substanceUse:
        return 'Substance Use';
      case SafetyIncidentType.other:
        return 'Other';
    }
  }

  String _getStatusDisplay(SafetyEventStatus status) {
    switch (status) {
      case SafetyEventStatus.pending:
        return 'Pending Review';
      case SafetyEventStatus.underReview:
        return 'Under Review';
      case SafetyEventStatus.resolved:
        return 'Resolved';
      case SafetyEventStatus.escalated:
        return 'Escalated';
      case SafetyEventStatus.dismissed:
        return 'Dismissed';
    }
  }

  Color _getStatusColor(SafetyEventStatus status) {
    switch (status) {
      case SafetyEventStatus.pending:
        return Colors.orange;
      case SafetyEventStatus.underReview:
        return Colors.blue;
      case SafetyEventStatus.resolved:
        return Colors.green;
      case SafetyEventStatus.escalated:
        return Colors.red;
      case SafetyEventStatus.dismissed:
        return Colors.grey;
    }
  }

  Color _getSeverityColor(SafetyEventSeverity severity) {
    switch (severity) {
      case SafetyEventSeverity.low:
        return Colors.blue;
      case SafetyEventSeverity.medium:
        return Colors.orange;
      case SafetyEventSeverity.high:
        return Colors.red;
      case SafetyEventSeverity.critical:
        return Colors.red.shade900;
    }
  }

  Widget _buildSummaryCards() {
    if (_summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total Events',
              _summary!.totalEvents.toString(),
              Icons.report,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              'Pending',
              _summary!.pendingEvents.toString(),
              Icons.pending,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              'Critical',
              _summary!.criticalEvents.toString(),
              Icons.emergency,
              Colors.red,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              'Resolved',
              _summary!.resolvedEvents.toString(),
              Icons.check_circle,
              Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<SafetyEventStatus?>(
              initialValue: _filterStatus,
              decoration: const InputDecoration(
                labelText: 'Filter by Status',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<SafetyEventStatus?>(
                  value: null,
                  child: Text('All Statuses'),
                ),
                ...SafetyEventStatus.values.map((status) => DropdownMenuItem(
                  value: status,
                  child: Text(_getStatusDisplay(status)),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  _filterStatus = value;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<SafetyEventSeverity?>(
              initialValue: _filterSeverity,
              decoration: const InputDecoration(
                labelText: 'Filter by Severity',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<SafetyEventSeverity?>(
                  value: null,
                  child: Text('All Severities'),
                ),
                ...SafetyEventSeverity.values.map((severity) => DropdownMenuItem(
                  value: severity,
                  child: Text(severity.name.toUpperCase()),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  _filterSeverity = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    return StreamBuilder<List<SafetyEventModel>>(
      stream: _safetyService.getAllSafetyEvents(
        status: _filterStatus,
        severity: _filterSeverity,
        limit: 100,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[300],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Error loading safety events',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final events = snapshot.data ?? [];

        if (events.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.security,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No safety events found',
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: events.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            return _buildEventCard(events[index]);
          },
        );
      },
    );
  }

  Widget _buildEventCard(SafetyEventModel event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: ExpansionTile(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getSeverityColor(event.severity),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                event.severity.name.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                event.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(event.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getStatusColor(event.status).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _getStatusDisplay(event.status),
                style: TextStyle(
                  color: _getStatusColor(event.status),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _getIncidentTypeDisplay(event.incidentType),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              'Reported ${_formatDate(event.createdAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Description:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(event.description),
                const SizedBox(height: 16),
                
                if (event.rideId != null) ...[
                  Text('Ride ID: ${event.rideId}'),
                  const SizedBox(height: 8),
                ],
                
                if (event.reportedUserId != null) ...[
                  Text('Reported User: ${event.reportedUserId}'),
                  const SizedBox(height: 8),
                ],
                
                if (event.resolution != null) ...[
                  const Text(
                    'Resolution:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(event.resolution!),
                  const SizedBox(height: 16),
                ],
                
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<SafetyEventStatus>(
                        initialValue: event.status,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        items: SafetyEventStatus.values.map((status) => 
                          DropdownMenuItem(
                            value: status,
                            child: Text(_getStatusDisplay(status)),
                          ),
                        ).toList(),
                        onChanged: (newStatus) {
                          if (newStatus != null && newStatus != event.status) {
                            _showUpdateStatusDialog(event, newStatus);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showUpdateStatusDialog(
    SafetyEventModel event,
    SafetyEventStatus newStatus,
  ) async {
    final notesController = TextEditingController();
    final resolutionController = TextEditingController(text: event.resolution);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Status to ${_getStatusDisplay(newStatus)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Review Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            if (newStatus == SafetyEventStatus.resolved) ...[
              TextField(
                controller: resolutionController,
                decoration: const InputDecoration(
                  labelText: 'Resolution Details',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop({
              'notes': notesController.text,
              'resolution': resolutionController.text,
            }),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _updateEventStatus(
        event.id,
        newStatus,
        reviewNotes: result['notes'],
        resolution: result['resolution']?.isNotEmpty == true 
            ? result['resolution'] 
            : null,
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} at ${TimeOfDay.fromDateTime(date).format(context)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Event Dashboard'),
        backgroundColor: Colors.red.shade50,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Events', icon: Icon(Icons.list)),
            Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Overview Tab
          Column(
            children: [
              _buildSummaryCards(),
              const Divider(),
              _buildFilters(),
              const SizedBox(height: 16),
              Expanded(child: _buildEventsList()),
            ],
          ),
          
          // Events Tab
          Column(
            children: [
              _buildFilters(),
              const SizedBox(height: 16),
              Expanded(child: _buildEventsList()),
            ],
          ),
          
          // Analytics Tab (placeholder for future implementation)
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Analytics Dashboard',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Detailed analytics and reporting features coming soon',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}