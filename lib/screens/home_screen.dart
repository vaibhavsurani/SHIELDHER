import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shieldher/services/audio_recorder_service.dart';
import 'package:shieldher/services/emergency_service.dart';
import 'package:shieldher/screens/emergency_contacts_screen.dart';
import 'package:shieldher/screens/community_screen.dart';
import 'package:shieldher/widgets/app_header.dart';

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
  late AnimationController _orbitController;
  late Animation<double> _pulseAnimation;
  final EmergencyService _emergencyService = EmergencyService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const platform = MethodChannel('com.example.shieldher/methods');

  // Sample member data for orbiting avatars
  final List<Map<String, dynamic>> _members = [
    {'name': 'Work', 'color': Colors.orange, 'icon': Icons.work},
    {'name': 'College', 'color': Colors.blue, 'icon': Icons.school},
    {'name': 'Home', 'color': Colors.green, 'icon': Icons.home},
    {'name': 'School', 'color': Colors.purple, 'icon': Icons.menu_book},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    _orbitController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  void _navigateTo(int index) {
    setState(() => _currentIndex = index);
    Navigator.pop(context); // Close drawer
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFFF8E7), // Malai white
      drawer: _buildDrawer(),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          CommunityScreen(
            scaffoldKey: _scaffoldKey,
            onNavigate: (index) => setState(() => _currentIndex = index),
          ),
          _buildRecordTab(),
          _buildProfileTab(),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: const Color(0xFFFFF8E7), // Malai white
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFC2185B), Color(0xFFAB47BC)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo.png',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.shield, size: 36, color: Color(0xFFC2185B)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "ShieldHer",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(Icons.home, 'Home', 0),
            _buildDrawerItem(Icons.map, 'Community', 1),
            _buildDrawerItem(Icons.mic, 'Record', 2),
            _buildDrawerItem(Icons.person, 'Profile', 3),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.contacts, color: Color(0xFFC2185B)),
              title: const Text('Emergency Contacts'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Color(0xFFC2185B)),
              title: const Text('Settings'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, int index) {
    final isSelected = _currentIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFFC2185B) : Colors.grey),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFFC2185B) : Colors.black87,
        ),
      ),
      selected: isSelected,
      selectedTileColor: const Color(0xFFC2185B).withOpacity(0.1),
      onTap: () => _navigateTo(index),
    );
  }

  // ==================== HOME TAB ====================
  Widget _buildHomeTab() {
    return SafeArea(
      child: Column(
        children: [
          AppHeader(scaffoldKey: _scaffoldKey),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  _buildSOSRadar(),
                  const SizedBox(height: 40),
                  _buildSOSButton(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/logo.png',
                width: 32,
                height: 32,
                errorBuilder: (_, __, ___) => const Icon(Icons.favorite, color: Color(0xFFC2185B), size: 28),
              ),
              const SizedBox(width: 8),
              const Text(
                "I'M SAFE",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC2185B),
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.black54),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.black87),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSOSRadar() {
    return SizedBox(
      width: 320,
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse rings
          ...List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final delay = index * 0.3;
                final animValue = ((_pulseController.value + delay) % 1.0);
                return Container(
                  width: 160 + (animValue * 160),
                  height: 160 + (animValue * 160),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFC2185B).withOpacity(0.3 * (1 - animValue)),
                      width: 2,
                    ),
                  ),
                );
              },
            );
          }),
          // Pink gradient background circle
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFC2185B).withOpacity(0.15),
                  const Color(0xFFC2185B).withOpacity(0.05),
                ],
              ),
            ),
          ),
          // Center bell icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFC2185B), Color(0xFFD81B60)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC2185B).withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.notifications_active, color: Colors.white, size: 40),
          ),
          // Orbiting member avatars
          AnimatedBuilder(
            animation: _orbitController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: List.generate(_members.length, (index) {
                  final angle = (2 * pi * index / _members.length) + (_orbitController.value * 2 * pi);
                  final radius = 130.0;
                  final x = radius * cos(angle);
                  final y = radius * sin(angle);
                  final member = _members[index];

                  return Transform.translate(
                    offset: Offset(x, y),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on, color: Colors.white, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                member['name'],
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: member['color'],
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: (member['color'] as Color).withOpacity(0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Icon(member['icon'], color: Colors.white, size: 24),
                        ),
                      ],
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSOSButton() {
    return GestureDetector(
      onTap: _sendSOS,
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFC2185B), Color(0xFFD81B60)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC2185B).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'SOS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
        ),
      ),
    );
  }

  // ==================== RECORD TAB ====================
  Widget _buildRecordTab() {
    return _RecordTabContent(scaffoldKey: _scaffoldKey);
  }

  // ==================== PROFILE TAB ====================
  Widget _buildProfileTab() {
    final user = Supabase.instance.client.auth.currentUser;
    return SafeArea(
      child: Column(
        children: [
          AppHeader(scaffoldKey: _scaffoldKey),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFC2185B), Color(0xFFAB47BC)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFC2185B).withOpacity(0.3),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 50),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.email ?? 'User',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 40),
                  _buildProfileOption(Icons.phone, 'Fake Call', _testFakeCall),
                  _buildProfileOption(Icons.location_on, 'Share Location', _shareLocation),
                  _buildProfileOption(Icons.contacts, 'Emergency Contacts', _openEmergencyContacts),
                  _buildProfileOption(Icons.settings, 'Settings', () {}),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFC2185B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFFC2185B)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  // ==================== ACTIONS ====================
  Future<void> _testFakeCall() async {
    try {
      await platform.invokeMethod('startFakeCall');
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${e.message}")),
        );
      }
    }
  }

  Future<void> _shareLocation() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Getting location...'), duration: Duration(seconds: 1)),
    );
    await _emergencyService.shareLocation();
  }

  void _openEmergencyContacts() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()));
  }

  Future<void> _sendSOS() async {
    final contacts = await _emergencyService.getContacts();
    if (contacts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add emergency contacts first!'), backgroundColor: Colors.orange),
        );
        _openEmergencyContacts();
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.sos, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Send SOS Alert?'),
          ],
        ),
        content: Text('Send emergency SMS to ${contacts.length} contact(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('SEND SOS', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sending SOS...'), duration: Duration(seconds: 2)),
      );
      await _emergencyService.sendSOSAutomatic();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOS sent successfully!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
  }
}

// ==================== RECORD TAB WIDGET ====================
class _RecordTabContent extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  const _RecordTabContent({required this.scaffoldKey});

  @override
  State<_RecordTabContent> createState() => _RecordTabContentState();
}

class _RecordTabContentState extends State<_RecordTabContent> {
  final AudioRecorderService _recorder = AudioRecorderService();
  final AudioPlayer _player = AudioPlayer();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final url = await _recorder.stopRecording();
      setState(() => _isRecording = false);
      if (url != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording saved!'), backgroundColor: Colors.green),
        );
        // Upload to Supabase
        try {
          await _recorder.uploadToSupabase(url);
        } catch (e) {
          print('Upload error: $e');
        }
      }
    } else {
      await _recorder.startRecording();
      setState(() => _isRecording = true);
    }
  }

  Future<void> _playRecording(String url) async {
    await _player.play(UrlSource(url));
  }

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FFF8), Color(0xFFE8F5E9)],
          ),
        ),
        child: Column(
          children: [
            AppHeader(scaffoldKey: widget.scaffoldKey),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Record',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'In case of an emergency, document a situation confidentially.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    _buildRecordingCard(),
                    const SizedBox(height: 30),
                    _buildStartButton(),
                    const SizedBox(height: 30),
                    const Text(
                      'Recent Recordings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _recorder.getRecordings(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Text('No recordings yet', style: TextStyle(color: Colors.grey.shade500));
                        }
                        final recordings = snapshot.data!.take(5).toList();
                        return Column(
                          children: recordings.map((r) => _buildRecordingItem(r)).toList(),
                        );
                      },
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/logo.png',
                width: 32,
                height: 32,
                errorBuilder: (_, __, ___) => const Icon(Icons.favorite, color: Color(0xFFC2185B), size: 28),
              ),
              const SizedBox(width: 8),
              const Text(
                "I'M SAFE",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFC2185B)),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.black54), onPressed: () {}),
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.black87),
                onPressed: () => widget.scaffoldKey.currentState?.openDrawer(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _isRecording ? Colors.red.shade100 : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isRecording ? Icons.stop : Icons.mic,
              color: _isRecording ? Colors.red : Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isRecording ? 'Recording...' : 'Recording',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'In case of an emergency, document a situation confidentially.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_isRecording)
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return Center(
      child: GestureDetector(
        onTap: _toggleRecording,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          decoration: BoxDecoration(
            color: _isRecording ? Colors.red : Colors.black87,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: (_isRecording ? Colors.red : Colors.black).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                _isRecording ? 'Stop Recording' : 'Starting Recording',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingItem(Map<String, dynamic> recording) {
    final url = recording['url'] as String? ?? '';
    final fileName = recording['file_name'] as String? ?? 'Recording';
    final createdAt = recording['created_at'] as String?;
    final lat = recording['latitude'];
    final lng = recording['longitude'];

    String timeStr = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) timeStr = DateFormat('MMM d, h:mm a').format(dt);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFC2185B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.play_arrow, color: Color(0xFFC2185B)),
        ),
        title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(timeStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        trailing: (lat != null && lng != null)
            ? IconButton(
                icon: const Icon(Icons.map, color: Colors.blueAccent),
                onPressed: () => _openMap((lat as num).toDouble(), (lng as num).toDouble()),
              )
            : null,
        onTap: () => _playRecording(url),
      ),
    );
  }
}
