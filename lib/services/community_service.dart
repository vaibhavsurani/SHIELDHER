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

      // Fetch member count for each bubble
      List<Bubble> bubbles = [];
      for (var b in bubblesData as List) {
        final countData = await _supabase
            .from('bubble_members')
            .select('id')
            .eq('bubble_id', b['id']);
        
        final memberCount = (countData as List).length;
        b['member_count'] = memberCount;
        bubbles.add(Bubble.fromJson(b));
      }
      
      return bubbles;
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
      // Step 1: Get raw members
      final memberData = await _supabase
          .from('bubble_members')
          .select()
          .eq('bubble_id', bubbleId);

      if ((memberData as List).isEmpty) return [];

      // Step 2: Get user IDs
      final userIds = memberData.map((m) => m['user_id'] as String).toList();

      // Step 3: Fetch profiles
      final profilesData = await _supabase
          .from('user_profiles')
          .select('user_id, display_name, avatar_url')
          .inFilter('user_id', userIds);

      // Create a map for easy lookup
      final profileMap = {
        for (var p in profilesData as List) p['user_id']: p
      };

      // Step 4: Merge results
      return memberData.map((m) {
        final userId = m['user_id'] as String;
        final profile = profileMap[userId];
        
        return BubbleMember(
          id: m['id'] as String,
          bubbleId: m['bubble_id'] as String,
          userId: userId,
          role: m['role'] as String? ?? 'member',
          joinedAt: DateTime.parse(m['joined_at'] as String),
          displayName: profile?['display_name'] as String? ?? 'Unknown',
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

  // ==================== INVITES ====================

  /// Invite a user to a bubble by their username (creates pending invite)
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

      // Can't invite yourself
      if (targetUserId == _userId) {
        print('Cannot invite yourself');
        return false;
      }

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

      // Check if there's already a pending invite
      final existingInvite = await _supabase
          .from('bubble_invites')
          .select('id')
          .eq('bubble_id', bubbleId)
          .eq('invitee_id', targetUserId)
          .eq('status', 'pending')
          .maybeSingle();

      if (existingInvite != null) {
        print('There is already a pending invite for this user');
        return false;
      }

      // Create pending invite
      await _supabase.from('bubble_invites').insert({
        'bubble_id': bubbleId,
        'inviter_id': _userId,
        'invitee_id': targetUserId,
        'status': 'pending',
      });

      return true;
    } catch (e) {
      print('Error inviting by username: $e');
      return false;
    }
  }

  /// Get pending invites for current user
  Future<List<BubbleInvite>> getPendingInvites() async {
    if (_userId == null) return [];

    try {
      // First get all pending invites for this user
      final inviteData = await _supabase
          .from('bubble_invites')
          .select()
          .eq('invitee_id', _userId!)
          .eq('status', 'pending');

      print('Pending invites found: ${(inviteData as List).length}');

      List<BubbleInvite> invites = [];
      for (var invite in inviteData) {
        // Get bubble info
        String bubbleName = 'Unknown Bubble';
        String bubbleIcon = 'family';
        try {
          final bubble = await _supabase
              .from('bubbles')
              .select('name, icon')
              .eq('id', invite['bubble_id'])
              .single();
          bubbleName = bubble['name'] as String? ?? 'Unknown Bubble';
          bubbleIcon = bubble['icon'] as String? ?? 'family';
        } catch (e) {
          print('Error fetching bubble: $e');
        }

        // Get inviter name
        String inviterName = 'Someone';
        try {
          final inviter = await _supabase
              .from('user_profiles')
              .select('display_name')
              .eq('user_id', invite['inviter_id'])
              .single();
          inviterName = inviter['display_name'] as String? ?? 'Someone';
        } catch (e) {
          print('Error fetching inviter: $e');
        }

        invites.add(BubbleInvite(
          id: invite['id'] as String,
          bubbleId: invite['bubble_id'] as String,
          bubbleName: bubbleName,
          bubbleIcon: bubbleIcon,
          inviterName: inviterName,
          createdAt: DateTime.parse(invite['created_at'] as String),
        ));
      }

      return invites;
    } catch (e) {
      print('Error fetching pending invites: $e');
      return [];
    }
  }

  /// Accept an invite
  Future<bool> acceptInvite(String inviteId) async {
    if (_userId == null) return false;

    try {
      // Get the invite details
      final invite = await _supabase
          .from('bubble_invites')
          .select('bubble_id')
          .eq('id', inviteId)
          .single();

      final bubbleId = invite['bubble_id'] as String;

      // Check if already a member to avoid unique constraint error
      final existingMember = await _supabase
          .from('bubble_members')
          .select('id')
          .eq('bubble_id', bubbleId)
          .eq('user_id', _userId!)
          .maybeSingle();

      if (existingMember == null) {
         // Add user as member
         await _supabase.from('bubble_members').insert({
           'bubble_id': bubbleId,
           'user_id': _userId,
           'role': 'member',
           'joined_at': DateTime.now().toIso8601String(), // Explicitly set join time if needed
         });
      }

      // Update invite status
      await _supabase
          .from('bubble_invites')
          .update({'status': 'accepted'})
          .eq('id', inviteId);

      return true;
    } catch (e) {
      print('Error accepting invite: $e');
      return false;
    }
  }

  /// Decline an invite
  Future<bool> declineInvite(String inviteId) async {
    if (_userId == null) return false;

    try {
      await _supabase
          .from('bubble_invites')
          .update({'status': 'declined'})
          .eq('id', inviteId);

      return true;
    } catch (e) {
      print('Error declining invite: $e');
      return false;
    }
  }
}

/// Model for bubble invites
class BubbleInvite {
  final String id;
  final String bubbleId;
  final String bubbleName;
  final String bubbleIcon;
  final String inviterName;
  final DateTime createdAt;

  BubbleInvite({
    required this.id,
    required this.bubbleId,
    required this.bubbleName,
    required this.bubbleIcon,
    required this.inviterName,
    required this.createdAt,
  });
}
