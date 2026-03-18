import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../scripts/test_ride_generator.dart';

/// Interactive test widget for ride booking system
/// Provides easy access to automated test scenarios
class RideBookingTestWidget extends StatefulWidget {
  const RideBookingTestWidget({super.key});

  @override
  State<RideBookingTestWidget> createState() => _RideBookingTestWidgetState();
}

class _RideBookingTestWidgetState extends State<RideBookingTestWidget> {
  final TestRideGenerator _testGenerator = TestRideGenerator();
  TestResults? _lastResults;
  bool _isRunning = false;
  bool _showResults = false;
  String _outputLog = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ride Booking System Tests',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF232F3E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Test Overview Card
            _buildOverviewCard(),
            const SizedBox(height: 16),
            
            // Test Scenarios
            _buildTestScenariosCard(),
            const SizedBox(height: 16),
            
            // Test Controls
            _buildTestControlsCard(),
            const SizedBox(height: 16),
            
            // Results Section
            if (_showResults) _buildResultsCard(),
            
            // Output Log
            if (_outputLog.isNotEmpty) _buildOutputLogCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFE57200)),
                const SizedBox(width: 8),
                Text(
                  'Test Overview',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'This test suite creates realistic ride scenarios using UVA area locations:',
              style: GoogleFonts.inter(),
            ),
            const SizedBox(height: 8),
            _buildLocationsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationsList() {
    return Column(
      children: [
        _buildLocationGroup('📍 Start Locations:', [
          '1920 Jefferson Park Ave (UVA area)',
          '1620 Jefferson Park Ave (Near campus)',
          '301 15th St NW (Downtown Charlottesville)',
        ]),
        const SizedBox(height: 8),
        _buildLocationGroup('🎯 Destinations:', [
          'Dulles International Airport',
          'Arlington Business District',
          'Historic District, Manassas',
        ]),
        const SizedBox(height: 8),
        _buildLocationGroup('👥 Test Users:', [
          'Driver: 0V55sbIpRNNvOD2ekBPRqDVyLMk1',
          'Rider 1: 4HddyRh70GSk9TwQ3r8GAy4I0NK2',
          'Rider 2: rCUu3nNHPlgbSr4tLCfHRncnKAv2',
        ]),
      ],
    );
  }

  Widget _buildLocationGroup(String title, List<String> locations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        ...locations.map((location) => Padding(
          padding: const EdgeInsets.only(left: 16, top: 2),
          child: Text(
            '• $location',
            style: GoogleFonts.inter(fontSize: 13),
          ),
        )),
      ],
    );
  }

  Widget _buildTestScenariosCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route, color: Color(0xFFE57200)),
                const SizedBox(width: 8),
                Text(
                  'Test Scenarios',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildScenarioTile(
              '✈️ Dulles Airport Run',
              'Multiple passengers, different pickups → same destination',
              'Tests route optimization for airport runs',
            ),
            _buildScenarioTile(
              '💼 Arlington Business Trip',
              'Professional ride with business preferences',
              'Tests preference matching and professional settings',
            ),
            _buildScenarioTile(
              '🏛️ Manassas Historic District',
              'Weekend cultural trip with flexible timing',
              'Tests weekend scheduling and cultural destinations',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioTile(String title, String description, String testFocus) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.inter(fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Focus: $testFocus',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestControlsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.play_arrow, color: Color(0xFFE57200)),
                const SizedBox(width: 8),
                Text(
                  'Test Controls',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Run Tests Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRunning ? null : _runTestScenarios,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE57200),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: _isRunning 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.rocket_launch),
                label: Text(
                  _isRunning ? 'Running Tests...' : 'Generate Test Data',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Cleanup Button
            if (_lastResults != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _cleanupTestData,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.delete_sweep),
                  label: Text(
                    'Cleanup Test Data',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard() {
    if (_lastResults == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _lastResults!.failedTests.isEmpty ? Icons.check_circle : Icons.error,
                  color: _lastResults!.failedTests.isEmpty ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Test Results',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Summary Stats
            Row(
              children: [
                Expanded(child: _buildStatCard('✅ Successful', '${_lastResults!.successfulTests.length}', Colors.green)),
                const SizedBox(width: 8),
                Expanded(child: _buildStatCard('❌ Failed', '${_lastResults!.failedTests.length}', Colors.red)),
                const SizedBox(width: 8),
                Expanded(child: _buildStatCard('🚗 Rides', '${_lastResults!.createdRides.length}', Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _buildStatCard('🎫 Requests', '${_lastResults!.createdRequests.length}', Colors.orange)),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Next Steps
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎯 Next Steps:',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...const [
                    '1. Open Driver tab → check for pending requests',
                    '2. Accept/decline requests to test workflow',
                    '3. View "All Passengers" to see pickup/dropoff details',
                    '4. Test route optimization with multiple pickups',
                    '5. Update passenger statuses during ride execution',
                  ].map((step) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      step,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOutputLogCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.terminal, color: Color(0xFFE57200)),
                    const SizedBox(width: 8),
                    Text(
                      'Execution Log',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => setState(() => _outputLog = ''),
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear log',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _outputLog,
                  style: GoogleFonts.robotoMono(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runTestScenarios() async {
    setState(() {
      _isRunning = true;
      _showResults = false;
      _outputLog = '';
    });

    try {
      _log('🚀 Starting test scenario generation...');
      
      // Generate test scenario
      final scenario = await _testGenerator.generateTestScenario();
      _log('✅ Generated scenario: ${scenario.name}');
      _log('📝 ${scenario.description}');
      _log('🧪 Test cases: ${scenario.testCases.length}');
      
      // Execute tests
      _log('\n⚡ Executing test scenarios...');
      final results = await _testGenerator.executeTestScenario(scenario);
      
      setState(() {
        _lastResults = results;
        _showResults = true;
      });
      
      _log('\n🎉 Test execution completed!');
      _log('✅ Successful: ${results.successfulTests.length}');
      _log('❌ Failed: ${results.failedTests.length}');
      _log('🚗 Rides created: ${results.createdRides.length}');
      _log('🎫 Requests created: ${results.createdRequests.length}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test data generated successfully! Check the Driver tab for requests.'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
      
    } catch (e) {
      _log('❌ Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test generation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  Future<void> _cleanupTestData() async {
    if (_lastResults == null) return;
    
    try {
      _log('🧹 Cleaning up test data...');
      await _testGenerator.cleanupTestData(_lastResults!);
      _log('✅ Cleanup completed');
      
      setState(() {
        _lastResults = null;
        _showResults = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test data cleaned up successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _log('❌ Cleanup error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cleanup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _log(String message) {
    setState(() {
      _outputLog += '$message\n';
    });
  }
}