import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shieldher/services/audio_recorder_service.dart';
import 'package:shieldher/services/emergency_service.dart';
import 'package:shieldher/screens/emergency_contacts_screen.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final EmergencyService _emergencyService = EmergencyService();

  // Channel for native communication
  static const platform = MethodChannel('com.example.shieldher/methods');

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
            ],
          ),
        ),
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomeTab(),
            _buildRecordTab(),
            _buildProfileTab(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: const Color(0xFFE91E63),
              unselectedItemColor: Colors.white54,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.mic_outlined),
                  activeIcon: Icon(Icons.mic),
                  label: 'Record',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== HOME TAB ====================
  Widget _buildHomeTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // App Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ShieldHer',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_outlined, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Status Shield with Pulse Animation
            Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: child,
                  );
                },
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE91E63),
                        Color(0xFFAB47BC),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE91E63).withOpacity(0.5),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield, size: 70, color: Colors.white),
                      SizedBox(height: 8),
                      Text(
                        'PROTECTED',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 50),

            // Emergency Trigger Card
            _buildGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blueAccent.withOpacity(0.3),
                              Colors.purpleAccent.withOpacity(0.3),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.volume_up, color: Colors.blueAccent),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Emergency Trigger',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Press Power and Volume Up buttons simultaneously to activate the Fake Call screen secretly.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.call,
                    label: 'Fake Call',
                    color: const Color(0xFFE91E63),
                    onTap: _testFakeCall,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.location_on,
                    label: 'Share Location',
                    color: Colors.orangeAccent,
                    onTap: _shareLocation,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.contacts,
                    label: 'Emergency\nContacts',
                    color: Colors.greenAccent,
                    onTap: _openEmergencyContacts,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.sos,
                    label: 'SOS Alert',
                    color: Colors.redAccent,
                    onTap: _sendSOS,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 100), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _testFakeCall() async {
    try {
      await platform.invokeMethod('startFakeCall');
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to trigger: ${e.message}")),
        );
      }
    }
  }

  Future<void> _shareLocation() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Getting your location...'),
        duration: Duration(seconds: 1),
      ),
    );

    final success = await _emergencyService.shareLocation();
    if (mounted) {
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get location. Please enable GPS.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openEmergencyContacts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EmergencyContactsScreen()),
    );
  }

  Future<void> _sendSOS() async {
    // Check if there are contacts first
    final contacts = await _emergencyService.getContacts();
    if (contacts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add emergency contacts first!'),
            backgroundColor: Colors.orange,
          ),
        );
        _openEmergencyContacts();
      }
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.sos, color: Colors.redAccent, size: 28),
            SizedBox(width: 12),
            Text('Send SOS Alert?', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'This will AUTOMATICALLY send an emergency SMS with your location to ${contacts.length} contact(s).',
          style: TextStyle(color: Colors.white.withAlpha(180)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withAlpha(180))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('SEND SOS NOW'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Sending SOS to emergency contacts...'),
              ],
            ),
            duration: Duration(seconds: 5),
            backgroundColor: Colors.redAccent,
          ),
        );
      }

      final success = await _emergencyService.sendSOSAutomatic();
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '✓ SOS sent to ${contacts.length} contact(s)!'
                  : 'SMS app opened. Please send the message.',
            ),
            backgroundColor: success ? Colors.green : Colors.orange,
          ),
        );
      }
    }
  }

  // ==================== RECORD TAB ====================
  Widget _buildRecordTab() {
    return const _RecordTabContent();
  }

  // ==================== PROFILE TAB ====================
  Widget _buildProfileTab() {
    final user = Supabase.instance.client.auth.currentUser;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Profile Header
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFFAB47BC)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE91E63).withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.person, size: 60, color: Colors.white),
            ),

            const SizedBox(height: 20),

            Text(
              user?.email ?? 'User',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Protected',
                style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w600),
              ),
            ),

            const SizedBox(height: 40),

            // Settings List
            _buildSettingsItem(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              onTap: () {},
            ),
            _buildSettingsItem(
              icon: Icons.security_outlined,
              title: 'Privacy & Security',
              onTap: () {},
            ),
            _buildSettingsItem(
              icon: Icons.people_outline,
              title: 'Emergency Contacts',
              onTap: () {},
            ),
            _buildSettingsItem(
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: () {},
            ),
            _buildSettingsItem(
              icon: Icons.info_outline,
              title: 'About',
              onTap: () {},
            ),

            const SizedBox(height: 20),

            // Logout Button
            GestureDetector(
              onTap: () async {
                await Supabase.instance.client.auth.signOut();
              },
              child: _buildGlassCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: Colors.red.shade300),
                    const SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.red.shade300,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // App Version
            Text(
              'ShieldHer v1.0.0',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white70),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white38),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== RECORD TAB CONTENT (Separate StatefulWidget) ====================
class _RecordTabContent extends StatefulWidget {
  const _RecordTabContent();

  @override
  State<_RecordTabContent> createState() => _RecordTabContentState();
}

class _RecordTabContentState extends State<_RecordTabContent>
    with SingleTickerProviderStateMixin {
  final AudioRecorderService _recorderService = AudioRecorderService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isUploading = false;
  int _duration = 0;
  String? _playingUrl;
  late AnimationController _recordingAnimController;

  @override
  void initState() {
    super.initState();
    _recordingAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _recorderService.durationStream.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration);
      }
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() => _playingUrl = null);
      }
    });
  }

  @override
  void dispose() {
    _recordingAnimController.dispose();
    _recorderService.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playRecording(String url) async {
    try {
      if (_playingUrl == url) {
        await _audioPlayer.stop();
        setState(() => _playingUrl = null);
      } else {
        await _audioPlayer.play(UrlSource(url));
        setState(() => _playingUrl = url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playback failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch maps')),
          );
        }
      }
    } catch (e) {
      print('Error launching map: $e');
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Stop recording
      setState(() => _isRecording = false);
      _recordingAnimController.stop();

      final path = await _recorderService.stopRecording();
      if (path != null) {
        setState(() => _isUploading = true);
        try {
          await _recorderService.uploadToSupabase(path);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Recording uploaded successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload failed: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        setState(() => _isUploading = false);
      }
    } else {
      // Start recording
      try {
        await _recorderService.startRecording();
        setState(() {
          _isRecording = true;
          _duration = 0;
        });
        _recordingAnimController.repeat(reverse: true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            const SizedBox(height: 10),

            const Text(
              'Voice Recording',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 20),

            // Recording UI (Compact)
            if (_isUploading)
               const Column(
                 children: [
                   CircularProgressIndicator(color: Color(0xFFE91E63)),
                   SizedBox(height: 16),
                   Text('Uploading...', style: TextStyle(color: Colors.white70)),
                 ],
               )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Timer
                   Column(
                     children: [
                       Text(
                        '00:${_duration.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                       Text(
                        _isRecording ? 'Recording...' : 'Ready',
                        style: TextStyle(
                          color: _isRecording ? Colors.redAccent : Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                     ],
                   ),

                  // Record Button
                  GestureDetector(
                    onTap: _isUploading ? null : _toggleRecording,
                    child: AnimatedBuilder(
                      animation: _recordingAnimController,
                      builder: (context, child) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isRecording
                                ? Colors.red.withOpacity(0.2)
                                : const Color(0xFFE91E63).withOpacity(0.2),
                            border: Border.all(
                              color: _isRecording
                                  ? Colors.red.withOpacity(_recordingAnimController.value)
                                  : const Color(0xFFE91E63).withOpacity(0.5),
                              width: 2,
                            ),
                            boxShadow: _isRecording
                                ? [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.5),
                                      blurRadius: 20 * _recordingAnimController.value,
                                      spreadRadius: 5 * _recordingAnimController.value,
                                    )
                                  ]
                                : [],
                          ),
                          child: Icon(
                            _isRecording ? Icons.stop : Icons.mic,
                            size: 32,
                            color: _isRecording ? Colors.red : const Color(0xFFE91E63),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 30),
            Divider(color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 10),

            // Recordings List Header
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recent Recordings',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Recordings List
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _recorderService.getRecordings(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading recordings: ${snapshot.error}', style: TextStyle(color: Colors.red.shade300)));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mic_none, size: 48, color: Colors.white.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          Text(
                            'No recordings yet',
                            style: TextStyle(color: Colors.white.withOpacity(0.5)),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    padding: const EdgeInsets.only(bottom: 100), // Space for nav bar
                    itemBuilder: (context, index) {
                      final data = docs[index];
                      final url = data['url'] as String;
                      final fileName = data['file_name'] as String? ?? 'Audio Recording'; // Note: field name in DB is file_name
                      // Supabase returns ISO 8601 string for timestamps
                      final createdAtStr = data['created_at'] as String?;
                      final dateStr = createdAtStr != null
                          ? DateFormat('MMM d, h:mm a').format(DateTime.parse(createdAtStr).toLocal())
                          : 'Just now';
                      final isPlaying = _playingUrl == url;
                      final id = data['id'].toString();

                      return Dismissible(
                        key: Key(id),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) {
                           _recorderService.deleteRecording(id, url);
                           // Optimistic update handled by stream
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isPlaying ? const Color(0xFFE91E63) : Colors.transparent,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isPlaying ? const Color(0xFFE91E63).withOpacity(0.2) : Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                color: isPlaying ? const Color(0xFFE91E63) : Colors.white,
                              ),
                            ),
                            title: Text(
                              fileName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              dateStr,
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                            ),
                            trailing: (data['latitude'] != null && data['longitude'] != null)
                                ? IconButton(
                                    icon: const Icon(Icons.map, color: Colors.blueAccent),
                                    onPressed: () {
                                      _openMap(
                                        (data['latitude'] as num).toDouble(),
                                        (data['longitude'] as num).toDouble(),
                                      );
                                    },
                                    tooltip: 'View Location',
                                  )
                                : null,
                            onTap: () => _playRecording(url),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
