import 'package:supabase_flutter/supabase_flutter.dart';

class Bubble {
  final String id;
  final String name;
  final String icon;
  final String color;
  final String createdBy;
  final String inviteCode;
  final DateTime createdAt;
  final int memberCount;

  Bubble({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.createdBy,
    required this.inviteCode,
    required this.createdAt,
    this.memberCount = 0,
  });

  factory Bubble.fromJson(Map<String, dynamic> json) {
    return Bubble(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String? ?? 'family',
      color: json['color'] as String? ?? '#E91E63',
      createdBy: json['created_by'] as String,
      inviteCode: json['invite_code'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      memberCount: json['member_count'] as int? ?? 0,
    );
  }
}

class BubbleMember {
  final String id;
  final String bubbleId;
  final String userId;
  final String role;
  final DateTime joinedAt;
  final String? displayName;
  final String? avatarUrl;

  BubbleMember({
    required this.id,
    required this.bubbleId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.displayName,
    this.avatarUrl,
  });

  factory BubbleMember.fromJson(Map<String, dynamic> json) {
    return BubbleMember(
      id: json['id'] as String,
      bubbleId: json['bubble_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'member',
      joinedAt: DateTime.parse(json['joined_at'] as String),
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

class CommunityService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  // ==================== BUBBLES ====================

  /// Get all bubbles the current user is a member of
  Future<List<Bubble>> getMyBubbles() async {
    if (_userId == null) return [];

    try {
      // First get bubble IDs user is member of
      final memberData = await _supabase
          .from('bubble_members')
          .select('bubble_id')
          .eq('user_id', _userId!);

      final bubbleIds = (memberData as List).map((m) => m['bubble_id']).toList();
      if (bubbleIds.isEmpty) return [];

      // Then get bubble details
      final bubblesData = await _supabase
          .from('bubbles')
          .select()
          .inFilter('id', bubbleIds);

      return (bubblesData as List).map((b) => Bubble.fromJson(b)).toList();
    } catch (e) {
      print('Error fetching bubbles: $e');
      return [];
    }
  }

  /// Create a new bubble
  Future<Bubble?> createBubble(String name, {String icon = 'family', String color = '#E91E63'}) async {
    if (_userId == null) {
      print('ERROR: User not logged in (_userId is null)');
      return null;
    }

    print('Creating bubble: name=$name, icon=$icon, color=$color, userId=$_userId');

    try {
      // Step 1: Insert bubble
      print('Step 1: Inserting into bubbles table...');
      final data = await _supabase.from('bubbles').insert({
        'name': name,
        'icon': icon,
        'color': color,
        'created_by': _userId,
      }).select().single();

      print('Step 1 SUCCESS: Bubble created with data: $data');
      final bubble = Bubble.fromJson(data);

      // Step 2: Add creator as admin member
      print('Step 2: Adding creator as admin member...');
      await _supabase.from('bubble_members').insert({
        'bubble_id': bubble.id,
        'user_id': _userId,
        'role': 'admin',
      });
      print('Step 2 SUCCESS: Creator added as admin');

      return bubble;
    } catch (e, stackTrace) {
      print('ERROR creating bubble: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Join a bubble using invite code
  Future<bool> joinBubble(String inviteCode) async {
    if (_userId == null) return false;

    try {
      // Find bubble by invite code
      final bubbleData = await _supabase
          .from('bubbles')
          .select()
          .eq('invite_code', inviteCode)
          .single();

      // Add user as member
      await _supabase.from('bubble_members').insert({
        'bubble_id': bubbleData['id'],
        'user_id': _userId,
        'role': 'member',
      });

      return true;
    } catch (e) {
      print('Error joining bubble: $e');
      return false;
    }
  }

  /// Get members of a bubble
  Future<List<BubbleMember>> getBubbleMembers(String bubbleId) async {
    try {
      final data = await _supabase
          .from('bubble_members')
          .select('*, user_profiles(display_name, avatar_url)')
          .eq('bubble_id', bubbleId);

      return (data as List).map((m) {
        final profile = m['user_profiles'] as Map<String, dynamic>?;
        return BubbleMember(
          id: m['id'] as String,
          bubbleId: m['bubble_id'] as String,
          userId: m['user_id'] as String,
          role: m['role'] as String? ?? 'member',
          joinedAt: DateTime.parse(m['joined_at'] as String),
          displayName: profile?['display_name'] as String?,
          avatarUrl: profile?['avatar_url'] as String?,
        );
      }).toList();
    } catch (e) {
      print('Error fetching members: $e');
      return [];
    }
  }

  /// Leave a bubble
  Future<bool> leaveBubble(String bubbleId) async {
    if (_userId == null) return false;

    try {
      await _supabase
          .from('bubble_members')
          .delete()
          .eq('bubble_id', bubbleId)
          .eq('user_id', _userId!);
      return true;
    } catch (e) {
      print('Error leaving bubble: $e');
      return false;
    }
  }

  /// Delete a bubble (admin only)
  Future<bool> deleteBubble(String bubbleId) async {
    if (_userId == null) return false;

    try {
      await _supabase.from('bubbles').delete().eq('id', bubbleId);
      return true;
    } catch (e) {
      print('Error deleting bubble: $e');
      return false;
    }
  }

  /// Generate invite link for a bubble
  String getInviteLink(String inviteCode) {
    return 'shieldher://join/$inviteCode';
  }

  /// Invite a user to a bubble by their username
  Future<bool> inviteByUsername(String bubbleId, String username) async {
    if (_userId == null) return false;

    try {
      // Clean up username (remove @ if present)
      final cleanUsername = username.startsWith('@') ? username.substring(1) : username;
      
      // Find user by username
      final userData = await _supabase
          .from('user_profiles')
          .select('user_id')
          .eq('username', cleanUsername)
          .maybeSingle();

      if (userData == null) {
        print('User not found with username: $cleanUsername');
        return false;
      }

      final targetUserId = userData['user_id'] as String;

      // Check if user is already a member
      final existingMember = await _supabase
          .from('bubble_members')
          .select('id')
          .eq('bubble_id', bubbleId)
          .eq('user_id', targetUserId)
          .maybeSingle();

      if (existingMember != null) {
        print('User is already a member of this bubble');
        return false;
      }

      // Add user as member
      await _supabase.from('bubble_members').insert({
        'bubble_id': bubbleId,
        'user_id': targetUserId,
        'role': 'member',
      });

      return true;
    } catch (e) {
      print('Error inviting by username: $e');
      return false;
    }
  }
}
