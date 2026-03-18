import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/safety_event_model.dart';
import '../../services/safety_service.dart';
import '../../providers/auth_provider.dart';

class SafetyReportScreen extends StatefulWidget {
  final String? rideId;
  final String? reportedUserId;

  const SafetyReportScreen({
    super.key,
    this.rideId,
    this.reportedUserId,
  });

  @override
  State<SafetyReportScreen> createState() => _SafetyReportScreenState();
}

class _SafetyReportScreenState extends State<SafetyReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final SafetyService _safetyService = SafetyService();

  SafetyIncidentType _selectedIncidentType = SafetyIncidentType.other;
  SafetyEventSeverity _selectedSeverity = SafetyEventSeverity.medium;
  bool _isAnonymous = false;
  bool _isSubmitting = false;
  final List<SafetyEventEvidence> _evidence = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.userModel;

      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to submit a safety report'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final eventId = await _safetyService.reportSafetyIncident(
        reporterId: currentUser.uid,
        incidentType: _selectedIncidentType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        reportedUserId: widget.reportedUserId,
        rideId: widget.rideId,
        severity: _selectedSeverity,
        evidence: _evidence,
        isAnonymous: _isAnonymous,
      );

      if (eventId != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isAnonymous
                    ? 'Anonymous safety report submitted successfully'
                    : 'Safety report submitted successfully. Reference ID: ${eventId.substring(0, 8)}...',
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        throw Exception('Failed to submit report');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildIncidentTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Incident Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<SafetyIncidentType>(
          initialValue: _selectedIncidentType,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Select incident type',
          ),
          items: SafetyIncidentType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(_getIncidentTypeDisplay(type)),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedIncidentType = value!;
            });
          },
          validator: (value) {
            if (value == null) {
              return 'Please select an incident type';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSeveritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Severity Level',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<SafetyEventSeverity>(
          initialValue: _selectedSeverity,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Select severity level',
          ),
          items: SafetyEventSeverity.values.map((severity) {
            return DropdownMenuItem(
              value: severity,
              child: Row(
                children: [
                  Icon(
                    _getSeverityIcon(severity),
                    color: _getSeverityColor(severity),
                  ),
                  const SizedBox(width: 8),
                  Text(_getSeverityDisplay(severity)),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedSeverity = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildOptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: const Text('Submit anonymously'),
          subtitle: const Text('Your identity will not be shared in this report'),
          value: _isAnonymous,
          onChanged: (value) {
            setState(() {
              _isAnonymous = value ?? false;
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  String _getIncidentTypeDisplay(SafetyIncidentType type) {
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

  String _getSeverityDisplay(SafetyEventSeverity severity) {
    switch (severity) {
      case SafetyEventSeverity.low:
        return 'Low - Minor concern';
      case SafetyEventSeverity.medium:
        return 'Medium - Moderate concern';
      case SafetyEventSeverity.high:
        return 'High - Serious concern';
      case SafetyEventSeverity.critical:
        return 'Critical - Immediate attention required';
    }
  }

  IconData _getSeverityIcon(SafetyEventSeverity severity) {
    switch (severity) {
      case SafetyEventSeverity.low:
        return Icons.info_outline;
      case SafetyEventSeverity.medium:
        return Icons.warning_amber_outlined;
      case SafetyEventSeverity.high:
        return Icons.error_outline;
      case SafetyEventSeverity.critical:
        return Icons.emergency;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Safety Incident'),
        backgroundColor: Colors.red.shade50,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.rideId != null || widget.reportedUserId != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Report Context',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (widget.rideId != null)
                        Text('Ride ID: ${widget.rideId}'),
                      if (widget.reportedUserId != null)
                        Text('User involved: ${widget.reportedUserId}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              const Text(
                'Help us understand what happened so we can ensure everyone\'s safety.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),

              _buildIncidentTypeSection(),
              const SizedBox(height: 16),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Title',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Brief title of the incident',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please provide a title';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Please describe what happened in detail...',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please provide a description';
                      }
                      if (value.trim().length < 10) {
                        return 'Please provide more detail (at least 10 characters)';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildSeveritySection(),
              const SizedBox(height: 16),

              _buildOptionsSection(),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.yellow.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Emergency?',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'If you are in immediate danger, please contact emergency services (911) directly. This form is for reporting incidents after they occur.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Submitting Report...'),
                        ],
                      )
                    : const Text(
                        'Submit Safety Report',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}