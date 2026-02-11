import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shieldher/services/audio_recorder_service.dart';
import 'package:shieldher/services/emergency_service.dart';
import 'package:shieldher/services/community_service.dart';
import 'package:shieldher/services/live_location_service.dart';
import 'package:shieldher/screens/emergency_contacts_screen.dart';
import 'package:shieldher/screens/community_screen.dart';
import 'package:shieldher/widgets/app_header.dart';
import 'package:shieldher/widgets/sos_button.dart';
import 'package:shieldher/widgets/quick_action_button.dart'; // Added

import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';


import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  final EmergencyService _emergencyService = EmergencyService();
  final CommunityService _communityService = CommunityService();
  final LiveLocationService _liveLocationService = LiveLocationService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  List<BubbleInvite> _pendingInvites = [];
  List<EmergencyContact> _contacts = []; // For Quick Contacts

  static const platform = MethodChannel('com.example.shieldher/methods');

  @override
  void initState() {
    super.initState();
    _loadPendingInvites();
    _loadContacts(); 
    
    // Register lifecycle observer to handle app background/close
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When app goes to background or is closed, set user as offline
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.detached || 
        state == AppLifecycleState.inactive) {
      _liveLocationService.goOffline();
    }
  }

  Future<void> _loadPendingInvites() async {
    final invites = await _communityService.getPendingInvites();
    if (mounted) setState(() => _pendingInvites = invites);
  }

  Future<void> _loadContacts() async {
    final contacts = await _emergencyService.getContacts();
    if (mounted) setState(() => _contacts = contacts);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _navigateTo(int index) {
    setState(() => _currentIndex = index);
    Navigator.pop(context); // Close drawer
  }
  
  void _showNotificationsDialog() async {
    await _loadPendingInvites();
    // Reusing existing notification dialog logic (simplified for brevity in this replacement)
    // ... (Keep existing implementation or refactor)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
         constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
             if (_pendingInvites.isEmpty)
              const Center(child: Text("No notifications"))
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _pendingInvites.length,
                  itemBuilder: (context, index) {
                    final invite = _pendingInvites[index];
                    return ListTile(
                      title: Text('Invite from ${invite.inviterName}'),
                      subtitle: Text('Bubble: ${invite.bubbleName}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () async {
                              await _communityService.acceptInvite(invite.id);
                              Navigator.pop(context);
                              _loadPendingInvites();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () async {
                              await _communityService.declineInvite(invite.id);
                              Navigator.pop(context);
                              _loadPendingInvites();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey.shade50, // Slight grey background for contrast
      drawer: _buildDrawer(),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          CommunityScreen(
            scaffoldKey: _scaffoldKey,
            onNavigate: (index) => setState(() => _currentIndex = index),
            onNotificationTap: _showNotificationsDialog,
            notificationCount: _pendingInvites.length,
          ),
          _buildRecordTab(),
          _buildProfileTab(),
        ],
      ),
    );
  }

  // ==================== DRAWER (Kept same) ====================
  Widget _buildDrawer() {
     return Drawer(
      child: Container(
        color: Colors.white,
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
            const Divider(color: Color(0xFFC2185B)),
            ListTile(
              leading: const Icon(Icons.contacts, color: Color(0xFFC2185B)),
              title: const Text('Emergency Contacts', style: TextStyle(color: Colors.black87)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.grey),
              title: const Text('Logout', style: TextStyle(color: Colors.black87)),
              onTap: () {
                Navigator.pop(context);
                _showLogoutDialog();
              },
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

  // ==================== HOME TAB (REDESIGNED) ====================
  Widget _buildHomeTab() {
    return SafeArea(
      child: Column(
        children: [
          // Header
          AppHeader(
            scaffoldKey: _scaffoldKey,
            showLiveStatus: false, // We use a custom card now
            onNotificationTap: _showNotificationsDialog,
            notificationCount: _pendingInvites.length,
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Live Location Status
                  _buildLiveStatusCard(),
                  const SizedBox(height: 24),
                  
                  // 2. SOS Button (Centerpiece)
                    SOSButton(
                      onPressed: _sendSOS,
                      width: double.infinity,
                      height: 180,
                    ),
                  const SizedBox(height: 32),
                  
                  // 3. Emergency Services
                  const Text(
                    "Emergency Services",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildServiceButton(Icons.local_police, "Police", Colors.blue, "100"),
                      _buildServiceButton(Icons.medical_services, "Ambulance", Colors.red, "108"),
                      _buildServiceButton(Icons.support_agent, "Helpline", Colors.purple, "1091"),
                      _buildServiceButton(Icons.call, "Contact", Colors.green, "custom"), // Calls priority contact
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // 4. Safety Tools Grid
                   const Text(
                    "Safety Tools",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2, // Adjusted to prevent overflow on smaller screens
                    children: [
                      QuickActionButton(
                        icon: Icons.phone_in_talk, 
                        label: "Fake Call", 
                        onTap: _testFakeCall,
                        color: Colors.orange,
                      ),
                      QuickActionButton(
                        icon: Icons.mic, 
                        label: "Record Audio", 
                        onTap: () => _navigateTo(2), // Go to Record Tab
                        color: Colors.teal,
                      ),
                      QuickActionButton(
                        icon: Icons.videocam, 
                        label: "Record Video", 
                        onTap: () {
                          // Todo: Implement video recording
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Video Recording coming soon!")));
                        },
                        color: Colors.indigo,
                      ),
                       QuickActionButton(
                        icon: Icons.directions_walk, 
                        label: "Safe Journey", 
                        onTap: () {
                           // Todo: Implement Safe Journey
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Safe Journey coming soon!")));
                        },
                        color: Colors.pink,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                   // 5. Trusted Contacts
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Trusted Contacts",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      TextButton(
                        onPressed: _openEmergencyContacts, 
                        child: const Text("Manage", style: TextStyle(color: Color(0xFFC2185B)))
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _contacts.length + 1, // +1 for Add button
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Column(
                              children: [
                                Material(
                                  color: Colors.grey.shade200,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    onTap: _openEmergencyContacts,
                                    customBorder: const CircleBorder(),
                                    child: const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Icon(Icons.add, color: Colors.black54),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text("Add", style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          );
                        }
                        final contact = _contacts[index - 1];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFFAB47BC), // Brand purple
                                child: Text(
                                  contact.name.isNotEmpty ? contact.name[0].toUpperCase() : "?",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                contact.name.split(" ")[0], // First name only
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                   const SizedBox(height: 24),
                   
                   // 6. Stealth Indicators
                   Container(
                     padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                     decoration: BoxDecoration(
                       color: Colors.grey.shade100,
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceAround,
                       children: [
                         _buildStealthIndicator(Icons.vibration, "Shake to SOS", true),
                         Container(width: 1, height: 24, color: Colors.grey.shade300),
                         _buildStealthIndicator(Icons.power_settings_new, "Power Button (3x)", true),
                       ],
                     ),
                   ),
                   const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLiveStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFC2185B).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC2185B).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.my_location, color: Color(0xFFC2185B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "You are safe", // Dynamic based on status
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                ),
                Text(
                  "Location sharing is off",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          Switch(
            value: false, // Todo: Connect to real state
            onChanged: (val) {
              // Toggle logic
            },
            activeColor: const Color(0xFFC2185B),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceButton(IconData icon, String label, Color color, String number) {
    return Column(
      children: [
        Material(
          elevation: 2,
          shape: const CircleBorder(),
          color: Colors.white,
          child: InkWell(
            onTap: () async {
              final Uri launchUri = Uri(
                scheme: 'tel',
                path: number == "custom" ? ( _contacts.isNotEmpty ? _contacts.first.phone : "112") : number,
              );
              if (await canLaunchUrl(launchUri)) {
                await launchUrl(launchUri);
              }
            },
            customBorder: const CircleBorder(),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: color, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
  
  Widget _buildStealthIndicator(IconData icon, String label, bool enabled) {
    return Row(
      children: [
        Icon(icon, size: 16, color: enabled ? Colors.green : Colors.grey),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: enabled ? Colors.black87 : Colors.grey,
            fontWeight: enabled ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // ==================== OTHER TABS (Placeholders/Simplified) ====================
  Widget _buildRecordTab() {
    return _RecordTabContent(
      scaffoldKey: _scaffoldKey,
      onNotificationTap: _showNotificationsDialog,
      notificationCount: _pendingInvites.length,
    );
  }

  Widget _buildProfileTab() {
    // Keeping profile simple for now
    final user = Supabase.instance.client.auth.currentUser;
    return SafeArea(
      child: Column(
        children: [
          AppHeader(
            scaffoldKey: _scaffoldKey,
            onNotificationTap: _showNotificationsDialog,
            notificationCount: _pendingInvites.length,
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Color(0xFFC2185B),
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(user?.email ?? 'User', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _showLogoutDialog,
                    child: const Text("Logout"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== LOGIC ACTIONS ====================


  Future<void> _testFakeCall() async {
    try {
      await platform.invokeMethod('startFakeCall');
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: ${e.message}")));
      }
    }
  }
  
  void _openEmergencyContacts() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()));
  }

  Future<void> _sendSOS() async {
    // ... (Keep existing SOS logic)
     if (!mounted) return;
    
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
    await _liveLocationService.goOffline();
    await Supabase.instance.client.auth.signOut();
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
  void _showSosDialog() {
    _sendSOS();
  }
}

// ==================== RECORD TAB WIDGET ====================
class _RecordTabContent extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final VoidCallback? onNotificationTap;
  final int notificationCount;
  
  const _RecordTabContent({
    required this.scaffoldKey,
    this.onNotificationTap,
    this.notificationCount = 0,
  });

  @override
  State<_RecordTabContent> createState() => _RecordTabContentState();
}




class _RecordTabContentState extends State<_RecordTabContent> {
  final AudioRecorderService _recorder = AudioRecorderService();
  final AudioPlayer _player = AudioPlayer();
  bool _isRecording = false;
  
  // Audio playback state
  String? _currentPlayingUrl;
  String? _loadingUrl;
  DateTime _loadStartTime = DateTime.now();
  bool _isPlaying = false;
  bool _isCompleted = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Timer? _positionTimer;
  Timer? _recordTimer; // Auto-stop timer
  int _recordSeconds = 0;
  int _visibleCount = 5; // Pagination limit
  Stream<List<Map<String, dynamic>>>? _recordingsStream;
  bool _isDragging = false;

  Stream<List<Map<String, dynamic>>> get recordingsStream =>
      _recordingsStream ??= _recorder.getRecordings();

  @override
  void initState() {
    super.initState();
    // Use the lazy getter if needed, but here just ensure listener setup
    
    // Listen to player state changes
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (state == PlayerState.playing) {
            // _loadingUrl = null; // Defer clearing to timer to prevent jitter
            _isCompleted = false;
            _startPositionTimer();
          } else if (state == PlayerState.paused || state == PlayerState.stopped) {
             _loadingUrl = null; // Clear if stopped/paused
             _positionTimer?.cancel();
          } else {
            _positionTimer?.cancel();
          }
        });
      }
    });

    // Listen to audio duration
    _player.onDurationChanged.listen((newDuration) {
      if (mounted && _loadingUrl == null) {
        setState(() => _duration = newDuration);
      }
    });

    // Listen to audio position
    _player.onPositionChanged.listen((newPosition) {
      if (mounted && !_isDragging && _loadingUrl == null) {
        setState(() => _position = newPosition);
      }
    });

    // Reset state when audio completes
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
            _isPlaying = false;
            _isCompleted = true;
            _position = Duration.zero;
            _positionTimer?.cancel();
        });
      }
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _positionTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    DateTime lastTick = DateTime.now();
    
    _positionTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!mounted || !_isPlaying) {
        timer.cancel();
        return;
      }
      
      final now = DateTime.now();
      final elapsed = now.difference(lastTick);
      lastTick = now;

      if (_isDragging) return;

      final p = await _player.getCurrentPosition();
      
      // Handle loading state logic
      if (_loadingUrl != null) {
        // Only accept if position is valid AND close to zero (avoid ghost position from prev track)
        if (p != null && p > Duration.zero && p < const Duration(milliseconds: 500)) {
           // Audio has started playing!
           setState(() {
             _loadingUrl = null;
             _position = p;
           });
        } else {
           // Still buffering or broken/ghost position reported
           final timeSinceLoad = DateTime.now().difference(_loadStartTime);
           if (timeSinceLoad.inMilliseconds > 2000) {
              // Timeout: Assume player is broken and force start
              setState(() => _loadingUrl = null);
           } else {
              // Wait for buffer...
              return;
           }
        }
      } else {
        // Normal playback
        if (p != null) {
          setState(() => _position = p);
        } else {
          // Dead reckoning
          setState(() {
            final newPos = _position + elapsed;
            if (_duration > Duration.zero && newPos > _duration) {
               _position = _duration;
            } else {
               _position = newPos;
            }
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            AppHeader(
              scaffoldKey: widget.scaffoldKey,
              onNotificationTap: widget.onNotificationTap,
              notificationCount: widget.notificationCount,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Record',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'In case of an emergency, document a situation confidentially.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    _buildRecordingCard(),
                    const SizedBox(height: 10),
                    _buildStartButton(),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Recordings',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.grey),
                          onPressed: _refreshRecordings,
                          tooltip: 'Refresh list',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: recordingsStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red));
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Text('No recordings yet', style: TextStyle(color: Colors.grey.shade500));
                        }
                        
                        final allRecordings = snapshot.data!;
                        final visibleRecordings = allRecordings.take(_visibleCount).toList();
                        final hasMore = allRecordings.length > _visibleCount;
                        
                        return Column(
                          children: [
                            ...visibleRecordings.map((r) => _buildRecordingItem(r)),
                            if (hasMore)
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _visibleCount += 8;
                                    });
                                  },
                                  child: const Text('Show More'),
                                ),
                              ),
                          ],
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

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
      await _recorder.startRecording();
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });
      
      // Auto-stop after 30 seconds (with UI update)
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _isRecording) {
           setState(() {
             _recordSeconds++;
           });
           
           if (_recordSeconds >= 30) {
             timer.cancel();
             _stopRecording();
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Recording stopped automatically (30s limit)')),
             );
           }
        } else {
          timer.cancel();
        }
      });
  }

  Future<void> _stopRecording() async {
      _recordTimer?.cancel();
      final url = await _recorder.stopRecording();
      if (mounted) {
        setState(() => _isRecording = false);
      }

      if (url != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording saved!'), backgroundColor: Colors.green),
          );
        }
        // Upload to Supabase
        try {
          await _recorder.uploadToSupabase(url);
          // Refresh the list after upload
          _refreshRecordings();
        } catch (e) {
          print('Upload error: $e');
        }
      }
  }

  void _refreshRecordings() {
    if (mounted) {
      setState(() {
        _recordingsStream = null; // Force reload
        _visibleCount = 5; // Reset pagination
      });
    }
  }

  Future<void> _playRecording(String url) async {
    if (_currentPlayingUrl == url) {
      if (_isPlaying) {
        await _player.pause();
        setState(() => _isPlaying = false);
      } else if (_isCompleted) {
        // Restart from beginning
        await _player.stop();
        await _player.play(UrlSource(url));
        setState(() {
          _isPlaying = true;
          _isCompleted = false;
          _position = Duration.zero;
        });
      } else {
        // Resume from pause
        await _player.resume();
        setState(() => _isPlaying = true);
      }
    } else {
      // Reset state immediately for new track
      setState(() {
        _loadingUrl = url; // Set loading state
        _loadStartTime = DateTime.now(); // Track when loading started
        _currentPlayingUrl = url; // Set current immediately so UI expands
        _isPlaying = false; // Kill the timer immediately to prevent old track updates!
        _position = Duration.zero;
        _isDragging = false;
        _duration = Duration.zero; 
      });

      await _player.stop();
      
      // Use setSource for better control
      await _player.setSource(UrlSource(url));
      
      // Force reset position to avoid "ghost" position from previous track
      await _player.seek(Duration.zero);
      
      // Attempt to get duration
      Duration? duration;
      try {
        duration = await _player.getDuration();
      } catch (e) {
        print('Error getting duration: $e');
      }
      
      await _player.resume();
      
      setState(() {
        _currentPlayingUrl = url;
        _isPlaying = true;
        _isCompleted = false;
        _position = Duration.zero;
        if (duration != null) {
          _duration = duration;
        } else {
          _duration = Duration.zero;
          // Poll for duration
          Future.doWhile(() async {
            if (!mounted || !_isPlaying || _currentPlayingUrl != url) return false;
            await Future.delayed(const Duration(milliseconds: 500));
            try {
              final d = await _player.getDuration();
              if (d != null && d > Duration.zero) {
                if (mounted) setState(() => _duration = d);
                return false;
              }
            } catch (_) {}
            return true;
          });
        }
      });
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
              color: _isRecording ? Colors.red.shade50 : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mic,
              color: _isRecording ? Colors.red : Colors.grey,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _isRecording
                ? Row(
                    children: [
                      const Expanded(child: RecordingWaveform()),
                      const SizedBox(width: 12),
                      Text(
                        '00:${_recordSeconds.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Record Audio',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Time limit: 30 seconds',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
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
            color: _isRecording ? Colors.red : const Color(0xFFC2185B),
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
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFC2185B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: (_loadingUrl == url)
                  ? const Padding(
                      padding: EdgeInsets.all(10.0),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFC2185B)),
                    )
                  : Icon(
                      (_currentPlayingUrl == url && _isPlaying)
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: const Color(0xFFC2185B),
                    ),
            ),
// ...
            title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
            subtitle: Text(timeStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            trailing: (lat != null && lng != null)
                ? IconButton(
                    icon: const Icon(Icons.map, color: Colors.blueAccent),
                    onPressed: () => _openMap((lat as num).toDouble(), (lng as num).toDouble()),
                  )
                : null,
            onTap: () => _playRecording(url),
          ),
          if (_currentPlayingUrl == url)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Slider(
                    value: (_position.inMilliseconds.toDouble().clamp(0.0, (_duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 30000.0))),
                    min: 0.0,
                    max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 30000.0,
                    activeColor: const Color(0xFFC2185B),
                    inactiveColor: Colors.grey.shade200,
                    onChanged: (value) {
                      // Update UI immediately (no seek here to prevent lag)
                      setState(() {
                         _isDragging = true;
                         _position = Duration(milliseconds: value.toInt());
                      });
                    },
                    onChangeEnd: (value) async {
                      final position = Duration(milliseconds: value.toInt());
                      await _player.seek(position);
                      setState(() {
                        _isDragging = false;
                        _position = position;
                      });
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: const TextStyle(fontSize: 10, color: Colors.black54),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: const TextStyle(fontSize: 10, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}

class RecordingWaveform extends StatefulWidget {
  const RecordingWaveform({Key? key}) : super(key: key);

  @override
  State<RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<RecordingWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(10, (index) {
            // Create a pseudo-random height based on index and controller value
            final height = 10.0 + 
                (20.0 * (0.5 + 0.5 *  
                    ((index % 2 == 0 ? 1 : -1) * 
                     (0.5 - (_controller.value + index / 10) % 1).abs() * 2)
                    ));
            return Container(
              width: 4,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }),
        );
      },
    );
  }
}
