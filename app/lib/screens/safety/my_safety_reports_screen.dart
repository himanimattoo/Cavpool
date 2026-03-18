import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/safety_event_model.dart';
import '../../services/safety_service.dart';
import '../../providers/auth_provider.dart';

class MySafetyReportsScreen extends StatefulWidget {
  const MySafetyReportsScreen({super.key});

  @override
  State<MySafetyReportsScreen> createState() => _MySafetyReportsScreenState();
}

class _MySafetyReportsScreenState extends State<MySafetyReportsScreen> {
  final SafetyService _safetyService = SafetyService();
  Stream<List<SafetyEventModel>>? _reportsStream;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  void _loadReports() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.userModel;

    if (currentUser != null) {
      setState(() {
        _reportsStream = _safetyService.getUserSafetyEvents(currentUser.uid);
      });
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

  Widget _buildReportCard(SafetyEventModel event) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
            const SizedBox(height: 8),
            
            Row(
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  _getIncidentTypeDisplay(event.incidentType),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.flag_outlined,
                  size: 16,
                  color: _getSeverityColor(event.severity),
                ),
                const SizedBox(width: 4),
                Text(
                  event.severity.name.toUpperCase(),
                  style: TextStyle(
                    color: _getSeverityColor(event.severity),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            Text(
              event.description,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(event.createdAt),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (event.isAnonymous)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Anonymous',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
            
            if (event.resolution != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resolution:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.resolution!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.userModel;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Safety Reports'),
        ),
        body: const Center(
          child: Text('Please log in to view your safety reports.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Safety Reports'),
        backgroundColor: Colors.red.shade50,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/safety/report');
            },
            tooltip: 'New Report',
          ),
        ],
      ),
      body: _reportsStream == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<SafetyEventModel>>(
              stream: _reportsStream,
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
                          'Error loading safety reports',
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

                final reports = snapshot.data ?? [];

                if (reports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.security,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No safety reports yet',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'If you experience any safety concerns, you can report them here.',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/safety/report');
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Report an Incident'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: reports.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemBuilder: (context, index) {
                    return _buildReportCard(reports[index]);
                  },
                );
              },
            ),
    );
  }
}