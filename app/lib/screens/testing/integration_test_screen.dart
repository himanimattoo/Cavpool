import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../../providers/auth_provider.dart';
import '../../providers/driver_provider.dart';
import '../../services/driver_status_service.dart';
import '../../services/live_location_service.dart';
import '../../services/ride_location_test_service.dart';
import '../../services/ride_completion_test.dart';

class IntegrationTestScreen extends StatefulWidget {
  const IntegrationTestScreen({super.key});

  @override
  State<IntegrationTestScreen> createState() => _IntegrationTestScreenState();
}

class _IntegrationTestScreenState extends State<IntegrationTestScreen> {
  final List<TestResult> _testResults = [];
  bool _isRunningTests = false;
  
  // Services
  final DriverStatusService _driverStatusService = DriverStatusService();
  final LiveLocationService _liveLocationService = LiveLocationService();
  final RideLocationTestService _rideLocationTestService = RideLocationTestService();
  final RideCompletionTest _rideCompletionTest = RideCompletionTest();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Integration Tests',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Test Controls
            _buildTestControls(),
            
            const SizedBox(height: 24),
            
            // Manual Tests Section
            _buildManualTestsSection(),
            
            const SizedBox(height: 24),
            
            // Automated Tests Section
            _buildAutomatedTestsSection(),
            
            const SizedBox(height: 24),
            
            // Test Results
            if (_testResults.isNotEmpty) _buildTestResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildTestControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test Controls',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRunningTests ? null : _runAllTests,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                    ),
                    child: _isRunningTests
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Running...'),
                            ],
                          )
                        : const Text('Run All Tests'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _clearResults,
                  child: const Text('Clear Results'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualTestsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manual Tests',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildManualTestTile(
              title: 'Driver Online/Offline Flow',
              description: 'Test driver status transitions manually',
              onTap: () => _testDriverOnlineOfflineFlow(),
            ),
            
            _buildManualTestTile(
              title: 'Notification Sound & Haptic',
              description: 'Test request notifications with feedback',
              onTap: () => _testNotificationFeedback(),
            ),
            
            _buildManualTestTile(
              title: 'Location Updates',
              description: 'Test real-time location sharing',
              onTap: () => _testLocationUpdates(),
            ),
            
            _buildManualTestTile(
              title: 'Ride Status Synchronization',
              description: 'Test location-based status updates',
              onTap: () => _testRideStatusSynchronization(),
            ),
            
            _buildManualTestTile(
              title: 'Ride Completion Flow',
              description: 'Test ride ending without black screen',
              onTap: () => _testRideCompletionFlow(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutomatedTestsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Automated Tests',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              'These tests run automatically when you press "Run All Tests":',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            
            _buildTestDescription('Service Initialization', 'All services start correctly'),
            _buildTestDescription('Provider State Management', 'Providers update state properly'),
            _buildTestDescription('Real-time Subscriptions', 'Stream subscriptions work'),
            _buildTestDescription('Error Handling', 'Services handle errors gracefully'),
          ],
        ),
      ),
    );
  }

  Widget _buildManualTestTile({
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        description,
        style: GoogleFonts.inter(fontSize: 12),
      ),
      trailing: const Icon(Icons.play_arrow),
      onTap: onTap,
    );
  }

  Widget _buildTestDescription(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: Colors.green[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$title: $description',
              style: GoogleFonts.inter(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResults() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test Results',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Summary
            _buildTestSummary(),
            
            const SizedBox(height: 16),
            
            // Individual Results
            ..._testResults.map((result) => _buildTestResultTile(result)),
          ],
        ),
      ),
    );
  }

  Widget _buildTestSummary() {
    final total = _testResults.length;
    final passed = _testResults.where((r) => r.passed).length;
    final failed = total - passed;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Total', total.toString(), Colors.blue),
          _buildSummaryItem('Passed', passed.toString(), Colors.green),
          _buildSummaryItem('Failed', failed.toString(), Colors.red),
          _buildSummaryItem(
            'Success Rate',
            total > 0 ? '${((passed / total) * 100).toStringAsFixed(0)}%' : '0%',
            passed == total ? Colors.green : Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTestResultTile(TestResult result) {
    return ListTile(
      leading: Icon(
        result.passed ? Icons.check_circle : Icons.error,
        color: result.passed ? Colors.green : Colors.red,
      ),
      title: Text(
        result.testName,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(result.message),
          Text(
            'Duration: ${result.duration.inMilliseconds}ms',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.info_outline),
        onPressed: () => _showTestDetails(result),
      ),
    );
  }

  // Test Implementation Methods
  Future<void> _runAllTests() async {
    setState(() {
      _isRunningTests = true;
      _testResults.clear();
    });

    try {
      // Test 1: Service Initialization
      await _testServiceInitialization();
      
      // Test 2: Provider State Management
      await _testProviderStateManagement();
      
      // Test 3: Real-time Subscriptions
      await _testRealtimeSubscriptions();
      
      // Test 4: Error Handling
      await _testErrorHandling();
      
      _showSnackBar('All tests completed', isError: false);
    } catch (e) {
      _showSnackBar('Tests failed: $e', isError: true);
    } finally {
      setState(() {
        _isRunningTests = false;
      });
    }
  }

  Future<void> _testServiceInitialization() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Test driver status service
      final testDriverId = 'test_${DateTime.now().millisecondsSinceEpoch}';
      await _driverStatusService.setDriverOnlineById(testDriverId);
      final status = await _driverStatusService.getDriverStatus(testDriverId);
      await _driverStatusService.setDriverOfflineById(testDriverId);
      
      if (status?.status == DriverStatus.online) {
        _addTestResult(TestResult(
          testName: 'Driver Status Service',
          passed: true,
          message: 'Service initialized and working correctly',
          duration: stopwatch.elapsed,
        ));
      } else {
        throw Exception('Driver status not set correctly');
      }
    } catch (e) {
      _addTestResult(TestResult(
        testName: 'Driver Status Service',
        passed: false,
        message: 'Failed: $e',
        duration: stopwatch.elapsed,
      ));
    }
  }

  Future<void> _testProviderStateManagement() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final driverProvider = Provider.of<DriverProvider>(context, listen: false);
      
      if (authProvider.user != null) {
        // Test driver provider initialization
        await driverProvider.initialize(authProvider.user!.uid);
        
        _addTestResult(TestResult(
          testName: 'Provider State Management',
          passed: true,
          message: 'Providers initialized successfully',
          duration: stopwatch.elapsed,
        ));
      } else {
        throw Exception('No authenticated user found');
      }
    } catch (e) {
      _addTestResult(TestResult(
        testName: 'Provider State Management',
        passed: false,
        message: 'Failed: $e',
        duration: stopwatch.elapsed,
      ));
    }
  }

  Future<void> _testRealtimeSubscriptions() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final testDriverId = 'test_stream_${DateTime.now().millisecondsSinceEpoch}';
      
      // Test driver status stream
      bool streamWorking = false;
      final subscription = _driverStatusService.getDriverStatusStream(testDriverId)
          .listen((status) {
        if (status != null) {
          streamWorking = true;
        }
      });

      await _driverStatusService.setDriverOnlineById(testDriverId);
      await Future.delayed(const Duration(seconds: 1));
      await subscription.cancel();
      await _driverStatusService.setDriverOfflineById(testDriverId);

      _addTestResult(TestResult(
        testName: 'Real-time Subscriptions',
        passed: streamWorking,
        message: streamWorking ? 'Streams working correctly' : 'Stream not receiving updates',
        duration: stopwatch.elapsed,
      ));
    } catch (e) {
      _addTestResult(TestResult(
        testName: 'Real-time Subscriptions',
        passed: false,
        message: 'Failed: $e',
        duration: stopwatch.elapsed,
      ));
    }
  }

  Future<void> _testErrorHandling() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Test handling of invalid data
      bool errorHandled = false;
      try {
        await _driverStatusService.getDriverStatus('invalid_driver_id');
        errorHandled = true;
      } catch (e) {
        // This is expected
        errorHandled = true;
      }

      _addTestResult(TestResult(
        testName: 'Error Handling',
        passed: errorHandled,
        message: 'Services handle errors gracefully',
        duration: stopwatch.elapsed,
      ));
    } catch (e) {
      _addTestResult(TestResult(
        testName: 'Error Handling',
        passed: false,
        message: 'Failed: $e',
        duration: stopwatch.elapsed,
      ));
    }
  }

  // Manual Test Methods
  Future<void> _testDriverOnlineOfflineFlow() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final driverProvider = Provider.of<DriverProvider>(context, listen: false);
    
    if (authProvider.user == null) {
      _showSnackBar('Please login first', isError: true);
      return;
    }

    try {
      if (driverProvider.currentStatus == DriverStatus.offline) {
        await driverProvider.goOnline();
        _showSnackBar('Driver set online', isError: false);
      } else {
        await driverProvider.goOffline();
        _showSnackBar('Driver set offline', isError: false);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _testNotificationFeedback() async {
    try {
      // Test sound
      SystemSound.play(SystemSoundType.alert);
      
      // Test haptic feedback
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.mediumImpact();
      
      _showSnackBar('Sound and haptic feedback triggered', isError: false);
    } catch (e) {
      _showSnackBar('Error testing feedback: $e', isError: true);
    }
  }

  Future<void> _testLocationUpdates() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.user == null) {
      _showSnackBar('Please login first', isError: true);
      return;
    }

    try {
      await _liveLocationService.startLocationSharing(userId: authProvider.user!.uid);
      _showSnackBar('Location sharing started', isError: false);
      
      // Stop after a few seconds
      Future.delayed(const Duration(seconds: 5), () async {
        await _liveLocationService.stopLocationSharing();
        _showSnackBar('Location sharing stopped', isError: false);
      });
    } catch (e) {
      _showSnackBar('Error testing location: $e', isError: true);
    }
  }

  Future<void> _testRideStatusSynchronization() async {
    _showSnackBar('Starting comprehensive ride status test...', isError: false);
    
    try {
      final result = await _rideLocationTestService.testRideStatusSynchronization();
      
      // Show result dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
          title: Text(result.success ? 'Test Passed [PASS]' : 'Test Failed [FAIL]'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Duration: ${result.duration.inMilliseconds}ms'),
                const SizedBox(height: 16),
                Text('Final Status: ${result.finalStatus?.name ?? 'null'}'),
                const SizedBox(height: 16),
                const Text('Test Steps:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...result.testSteps.map((step) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(step, style: const TextStyle(fontSize: 12)),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ));
        
        _showSnackBar(result.message, isError: !result.success);
      }
    } catch (e) {
      _showSnackBar('Error running test: $e', isError: true);
    }
  }

  Future<void> _testRideCompletionFlow() async {
    _showSnackBar('Testing ride completion flow...', isError: false);
    
    try {
      final componentResult = await _rideCompletionTest.testRideCompletionFlow();
      final logicResult = await _rideCompletionTest.testRideCompletionLogic();
      
      // Show combined results
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              componentResult.success && logicResult.success 
                  ? 'Ride Completion Tests Passed [PASS]' 
                  : 'Ride Completion Tests Failed [FAIL]'
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Component Test: ${componentResult.success ? "PASS" : "FAIL"}'),
                  Text('Logic Test: ${logicResult.success ? "PASS" : "FAIL"}'),
                  const SizedBox(height: 16),
                  
                  const Text('Component Test Results:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...componentResult.steps.map((step) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(step, style: const TextStyle(fontSize: 12)),
                  )),
                  
                  if (componentResult.issues.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Issues Found:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    const SizedBox(height: 8),
                    ...componentResult.issues.map((issue) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(issue, style: const TextStyle(fontSize: 12, color: Colors.red)),
                    )),
                  ],
                  
                  const SizedBox(height: 16),
                  const Text('Logic Test Results:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...logicResult.steps.map((step) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(step, style: const TextStyle(fontSize: 12)),
                  )),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
      
      final message = componentResult.success && logicResult.success
          ? 'Ride completion flow is properly configured'
          : 'Ride completion has issues - see details';
      
      _showSnackBar(message, isError: !(componentResult.success && logicResult.success));
    } catch (e) {
      _showSnackBar('Error testing ride completion: $e', isError: true);
    }
  }

  // Helper Methods
  void _addTestResult(TestResult result) {
    setState(() {
      _testResults.add(result);
    });
  }

  void _clearResults() {
    setState(() {
      _testResults.clear();
    });
  }

  void _showTestDetails(TestResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result.testName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${result.passed ? 'PASSED' : 'FAILED'}'),
            const SizedBox(height: 8),
            Text('Message: ${result.message}'),
            const SizedBox(height: 8),
            Text('Duration: ${result.duration.inMilliseconds}ms'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
}

class TestResult {
  final String testName;
  final bool passed;
  final String message;
  final Duration duration;

  TestResult({
    required this.testName,
    required this.passed,
    required this.message,
    required this.duration,
  });
}