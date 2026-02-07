import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shieldher/services/community_service.dart';
import 'package:shieldher/services/live_location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shieldher/widgets/app_header.dart';

class CommunityScreen extends StatefulWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final Function(int)? onNavigate;

  const CommunityScreen({
    super.key,
    this.scaffoldKey,
    this.onNavigate,
  });

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final CommunityService _communityService = CommunityService();
  final LiveLocationService _locationService = LiveLocationService();
  final MapController _mapController = MapController();

  List<Bubble> _bubbles = [];
  Bubble? _selectedBubble;
  List<LiveLocation> _liveLocations = [];
  List<BubbleMember> _bubbleMembers = [];
  bool _isLoading = true;
  bool _isLive = false;
  LatLng _currentLocation = const LatLng(22.5988, 72.8245);

  int _filterMode = 0; // 0 = All, 1 = Family Only, 2 = Helpers Only

  @override
  void initState() {
    super.initState();
    _loadData();
    _getCurrentLocation();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final bubbles = await _communityService.getMyBubbles();
    setState(() {
      _bubbles = bubbles;
      if (bubbles.isNotEmpty) {
        _selectedBubble = bubbles.first;
      }
      _isLoading = false;
    });

    if (_selectedBubble != null) {
      _loadBubbleData();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      // Use default
    }
  }

  Future<void> _loadBubbleData() async {
    if (_selectedBubble == null) return;

    // Load members
    final members = await _communityService.getBubbleMembers(_selectedBubble!.id);
    setState(() => _bubbleMembers = members);

    // Load locations
    List<LiveLocation> locations = [];

    if (_filterMode == 0 || _filterMode == 1) {
      final bubbleLocations = await _locationService.getBubbleMembersLocations(_selectedBubble!.id);
      locations.addAll(bubbleLocations);
    }

    if (_filterMode == 0 || _filterMode == 2) {
      final helpers = await _locationService.getNearbyHelpers();
      for (var h in helpers) {
        if (!locations.any((l) => l.oderId == h.oderId)) {
          locations.add(h);
        }
      }
    }

    setState(() => _liveLocations = locations);
  }

  Future<void> _toggleLive() async {
    if (_isLive) {
      await _locationService.goOffline();
    } else {
      await _locationService.goLive();
    }
    setState(() => _isLive = !_isLive);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isLive ? 'You are now live!' : 'You are now offline'),
        backgroundColor: _isLive ? Colors.green : Colors.grey,
      ),
    );
  }

  void _selectBubble(Bubble bubble) {
    setState(() => _selectedBubble = bubble);
    _loadBubbleData();
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: const Color(0xFFFFF8E7), // Malai white
        child: Column(
          children: [
            AppHeader(
              scaffoldKey: widget.scaffoldKey,
              showLiveStatus: true,
              isLive: _isLive,
              onLiveToggle: _toggleLive,
            ),
            _buildCategoryRow(),
            Expanded(
              child: Stack(
                children: [
                  _buildMap(),
                  if (_selectedBubble != null)
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: _buildMembersRow(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo and brand name
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC2185B), Color(0xFFAD1457)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'ShieldHer',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFC2185B),
                      letterSpacing: -0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Action buttons
          Row(
            children: [
              // Live status indicator
              GestureDetector(
                onTap: _toggleLive,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isLive ? const Color(0xFFC2185B) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isLive ? Colors.white : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isLive ? 'Live' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _isLive ? Colors.white : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Notification bell
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.notifications_none_rounded, size: 22),
                  color: Colors.black87,
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 4),
              // Menu
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.menu_rounded, size: 22),
                  color: Colors.black87,
                  onPressed: () => widget.scaffoldKey?.currentState?.openDrawer(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow() {
    return Container(
      height: 100,
      padding: const EdgeInsets.only(top: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          // All bubbles option
          _buildCategoryChip(
            icon: Icons.groups_rounded,
            label: 'All',
            color: const Color(0xFF6B7280),
            isSelected: _selectedBubble == null,
            onTap: () {
              setState(() => _selectedBubble = _bubbles.isNotEmpty ? _bubbles.first : null);
              _loadBubbleData();
            },
          ),
          // User's bubbles
          ..._bubbles.map((bubble) => _buildCategoryChip(
                icon: _getBubbleIcon(bubble.icon),
                label: bubble.name,
                color: Color(int.parse(bubble.color.replaceFirst('#', '0xFF'))),
                isSelected: _selectedBubble?.id == bubble.id,
                onTap: () => _selectBubble(bubble),
                onLongPress: () => _showBubbleOptionsDialog(bubble),
              )),
          // Add button
          _buildCategoryChip(
            icon: Icons.add_rounded,
            label: 'Add',
            color: const Color(0xFFC2185B),
            isAddButton: true,
            onTap: _showCreateBubbleDialog,
          ),
          // Join button
          _buildCategoryChip(
            icon: Icons.login_rounded,
            label: 'Join',
            color: const Color(0xFF4CAF50),
            isAddButton: true,
            onTap: _showJoinDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required IconData icon,
    required String label,
    required Color color,
    bool isSelected = false,
    bool isAddButton = false,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 70,
        margin: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isAddButton ? Colors.black : (isSelected ? color : color.withOpacity(0.12)),
                shape: BoxShape.circle,
                border: isSelected ? Border.all(color: color, width: 2.5) : null,
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ] : null,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      icon,
                      color: isAddButton ? Colors.white : (isSelected ? Colors.white : color),
                      size: 26,
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 10),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.grey.shade600,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersRow() {
    return Row(
      children: [
        // Member count badge
        GestureDetector(
          onTap: _showInviteDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_bubbleMembers.length} members',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFFC2185B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, size: 14, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Member avatars stack
        SizedBox(
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (int i = 0; i < (_bubbleMembers.length > 5 ? 5 : _bubbleMembers.length); i++)
                Positioned(
                  left: i * 28.0,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          [const Color(0xFFFF6B6B), const Color(0xFFFF8E8E)],
                          [const Color(0xFF4ECDC4), const Color(0xFF6BE5DC)],
                          [const Color(0xFF845EC2), const Color(0xFFA178DF)],
                          [const Color(0xFFFF9671), const Color(0xFFFFB899)],
                          [const Color(0xFF00C9A7), const Color(0xFF4DE0C7)],
                        ][i % 5],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _bubbleMembers[i].displayName?.isNotEmpty == true
                            ? _bubbleMembers[i].displayName![0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_bubbleMembers.length > 5)
                Positioned(
                  left: 5 * 28.0,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Center(
                      child: Text(
                        '+${_bubbleMembers.length - 5}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _buildFilterChip('All', 0),
          const SizedBox(width: 8),
          _buildFilterChip('Family', 1),
          const SizedBox(width: 8),
          _buildFilterChip('Helpers', 2),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int mode) {
    final isSelected = _filterMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _filterMode = mode);
        _loadBubbleData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFC2185B) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(initialCenter: _currentLocation, initialZoom: 14),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.shieldher',
          ),
          MarkerLayer(
            markers: [
              // Current user marker
              Marker(
                point: _currentLocation,
                width: 80,
                height: 80,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
                      ),
                      child: const Text('You', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC2185B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(color: const Color(0xFFC2185B).withOpacity(0.4), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 22),
                    ),
                  ],
                ),
              ),
              // Other members
              ..._liveLocations.map((loc) => Marker(
                    point: LatLng(loc.latitude, loc.longitude),
                    width: 80,
                    height: 70,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                          ),
                          child: Text(
                            loc.displayName ?? 'User',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: loc.isHelper ? Colors.blue : Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoLiveButton() {
    return GestureDetector(
      onTap: _toggleLive,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _isLive ? Colors.red : const Color(0xFFC2185B),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: (_isLive ? Colors.red : const Color(0xFFC2185B)).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_isLive ? Icons.stop : Icons.play_arrow, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              _isLive ? 'Go Offline' : 'Go Live',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getBubbleIcon(String iconName) {
    switch (iconName) {
      case 'family':
        return Icons.home;
      case 'trip':
        return Icons.directions_car;
      case 'work':
        return Icons.work;
      case 'gym':
        return Icons.fitness_center;
      case 'school':
        return Icons.school;
      default:
        return Icons.group;
    }
  }

  void _showCreateBubbleDialog() {
    final nameController = TextEditingController();
    String selectedIcon = 'family';
    String selectedColor = '#E91E63';

    final icons = [
      {'icon': 'family', 'display': Icons.home},
      {'icon': 'trip', 'display': Icons.directions_car},
      {'icon': 'work', 'display': Icons.work},
      {'icon': 'gym', 'display': Icons.fitness_center},
      {'icon': 'school', 'display': Icons.school},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Create Bubble'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Bubble Name (e.g. Family, Work)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Choose Icon:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: icons.map((item) {
                  final isSelected = selectedIcon == item['icon'];
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedIcon = item['icon'] as String),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFC2185B).withOpacity(0.2) : Colors.grey.shade100,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: const Color(0xFFC2185B), width: 2) : null,
                      ),
                      child: Icon(item['display'] as IconData, color: const Color(0xFFC2185B)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a bubble name')),
                  );
                  return;
                }
                final bubble = await _communityService.createBubble(
                  nameController.text.trim(),
                  icon: selectedIcon,
                  color: selectedColor,
                );
                Navigator.pop(context);
                if (bubble != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bubble created!'), backgroundColor: Colors.green),
                  );
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to create bubble. Check database.'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC2185B)),
              child: const Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showBubbleOptionsDialog(Bubble bubble) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(bubble.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.person_add, color: Color(0xFFC2185B)),
              title: const Text('Invite Members'),
              onTap: () {
                Navigator.pop(context);
                _showInviteDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blue),
              title: const Text('Share Invite Link'),
              onTap: () async {
                Navigator.pop(context);
                final link = _communityService.getInviteLink(bubble.inviteCode);
                await Share.share('Join my bubble "${bubble.name}" on ShieldHer! Use code: ${bubble.inviteCode} or link: $link');
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.orange),
              title: const Text('Leave Bubble'),
              onTap: () async {
                Navigator.pop(context);
                await _communityService.leaveBubble(bubble.id);
                _loadData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Bubble'),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Bubble?'),
                    content: const Text('This will remove the bubble for all members.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Delete', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _communityService.deleteBubble(bubble.id);
                  _loadData();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteDialog() {
    final codeController = TextEditingController();
    final usernameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Members',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // =================================
              // SHARE INVITE LINK SECTION
              // =================================
              if (_selectedBubble != null) ...[
                const Text(
                  'Share Invite Link',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                
                // Invite Code Display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFFC2185B).withOpacity(0.1), const Color(0xFFC2185B).withOpacity(0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFC2185B).withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text('Invite Code', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        _selectedBubble!.inviteCode,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: Color(0xFFC2185B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Share Buttons Row
                Row(
                  children: [
                    // WhatsApp Share
                    Expanded(
                      child: _buildShareButton(
                        icon: Icons.chat,
                        label: 'WhatsApp',
                        color: const Color(0xFF25D366),
                        onTap: () => _shareViaWhatsApp(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Share via other apps
                    Expanded(
                      child: _buildShareButton(
                        icon: Icons.share,
                        label: 'More Apps',
                        color: const Color(0xFF2196F3),
                        onTap: () => _shareViaOtherApps(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Copy Link
                    Expanded(
                      child: _buildShareButton(
                        icon: Icons.copy,
                        label: 'Copy Link',
                        color: Colors.grey.shade700,
                        onTap: () => _copyInviteLink(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
              ],

              // =================================
              // INVITE BY USERNAME SECTION
              // =================================
              const Text(
                'Invite by Username',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the username of the person you want to invite',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: usernameController,
                      decoration: InputDecoration(
                        hintText: '@username',
                        prefixIcon: const Icon(Icons.alternate_email, color: Color(0xFFC2185B)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFC2185B), width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (usernameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a username')),
                        );
                        return;
                      }
                      final success = await _communityService.inviteByUsername(
                        _selectedBubble!.id,
                        usernameController.text.trim(),
                      );
                      if (success) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invitation sent!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _loadBubbleData();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('User not found or already a member'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC2185B),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Invite', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showJoinDialog() {
    final codeController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Join a Bubble',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Have an invite code? Enter it below to join a bubble',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Enter invite code',
                prefixIcon: const Icon(Icons.vpn_key, color: Color(0xFF4CAF50)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (codeController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter an invite code')),
                    );
                    return;
                  }
                  final success = await _communityService.joinBubble(codeController.text.trim());
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Joined bubble successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadData();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid code or already a member'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Join Bubble', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildShareButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareViaWhatsApp() async {
    if (_selectedBubble == null) return;
    final inviteCode = _selectedBubble!.inviteCode;
    final bubbleName = _selectedBubble!.name;
    final link = _communityService.getInviteLink(inviteCode);
    
    final message = 'Hey! Join my safety bubble "$bubbleName" on ShieldHer app! 🛡️\n\n'
        'Use this invite code: *$inviteCode*\n\n'
        'Or click the link: $link\n\n'
        'Stay safe together! 💗';
    
    final whatsappUrl = 'whatsapp://send?text=${Uri.encodeComponent(message)}';
    
    try {
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // WhatsApp not installed, use regular share
        _shareViaOtherApps();
      }
    } catch (e) {
      _shareViaOtherApps();
    }
  }

  void _shareViaOtherApps() async {
    if (_selectedBubble == null) return;
    final inviteCode = _selectedBubble!.inviteCode;
    final bubbleName = _selectedBubble!.name;
    final link = _communityService.getInviteLink(inviteCode);
    
    final message = 'Hey! Join my safety bubble "$bubbleName" on ShieldHer app! 🛡️\n\n'
        'Use this invite code: $inviteCode\n\n'
        'Or click the link: $link\n\n'
        'Stay safe together! 💗';
    
    await Share.share(message, subject: 'Join my ShieldHer Safety Bubble');
  }

  void _copyInviteLink(BuildContext context) {
    if (_selectedBubble == null) return;
    final inviteCode = _selectedBubble!.inviteCode;
    final link = _communityService.getInviteLink(inviteCode);
    
    Clipboard.setData(ClipboardData(text: '$link\nCode: $inviteCode'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Invite link copied to clipboard!'),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }
}
