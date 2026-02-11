import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shieldher/services/emergency_service.dart';
import 'package:shieldher/services/community_service.dart';
import 'package:shieldher/services/live_location_service.dart';
import 'package:shieldher/screens/emergency_contacts_screen.dart';
import 'package:shieldher/screens/community_screen.dart';
import 'package:shieldher/screens/record_screen.dart';
import 'package:shieldher/widgets/app_header.dart';
import 'package:shieldher/widgets/sos_button.dart';
import 'package:shieldher/widgets/quick_action_button.dart';

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
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context); // Close drawer only if open
    }
    setState(() => _currentIndex = index);
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
    return RecordTabContent(
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
  
  Future<void> _openEmergencyContacts() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()));
    _loadContacts(); // Refresh contacts on return
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
