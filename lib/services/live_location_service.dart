import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveLocation {
  final String oderId;
  final double latitude;
  final double longitude;
  final double speed;
  final double heading;
  final bool isLive;
  final bool isHelper;
  final DateTime updatedAt;
  final String? displayName;
  final String? avatarUrl;

  LiveLocation({
    required this.oderId,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.heading,
    required this.isLive,
    required this.isHelper,
    required this.updatedAt,
    this.displayName,
    this.avatarUrl,
  });

  factory LiveLocation.fromJson(Map<String, dynamic> json) {
    final profile = json['user_profiles'] as Map<String, dynamic>?;
    return LiveLocation(
      oderId: json['user_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      speed: (json['speed'] as num?)?.toDouble() ?? 0,
      heading: (json['heading'] as num?)?.toDouble() ?? 0,
      isLive: json['is_live'] as bool? ?? false,
      isHelper: json['is_helper'] as bool? ?? false,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      displayName: profile?['display_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
    );
  }
}

class LiveLocationService {
  // Singleton instance
  static final LiveLocationService _instance = LiveLocationService._internal();

  factory LiveLocationService() {
    return _instance;
  }

  LiveLocationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<Position>? _positionSubscription;
  bool _isLive = false;
  bool _isHelper = false;

  String? get _userId => _supabase.auth.currentUser?.id;
  bool get isLive => _isLive;
  bool get isHelper => _isHelper;

  // ==================== LOCATION UPDATES ====================

  /// Start sharing live location
  Future<bool> goLive() async {
    if (_userId == null) return false;

    final hasPermission = await checkLocationPermission();
    if (!hasPermission) return false;

    _isLive = true;

    // Start listening to location updates
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
      _updateLocation(position);
    });

    // Immediately update with current position
    final position = await Geolocator.getCurrentPosition();
    await _updateLocation(position);

    return true;
  }

  /// Stop sharing live location
  Future<void> goOffline() async {
    _isLive = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;

    if (_userId != null) {
      try {
        // Use UPDATE instead of UPSERT to avoid NOT NULL constraint issues
        // This only works if user already has a record (which they should after going live)
        await _supabase.from('live_locations')
            .update({
              'is_live': false,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', _userId!);
        debugPrint('Successfully went offline');
      } catch (e) {
        debugPrint('Error going offline: $e');
      }
    }
  }

  /// Toggle helper mode
  Future<void> setHelperMode(bool enabled) async {
    _isHelper = enabled;
    if (_userId != null) {
      try {
        await _supabase.from('live_locations').upsert({
          'user_id': _userId,
          'is_helper': enabled,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Error setting helper mode: $e');
      }
    }
  }

  /// Update location in database
  Future<void> _updateLocation(Position position) async {
    if (_userId == null || !_isLive) return;

    try {
      await _supabase.from('live_locations').upsert({
        'user_id': _userId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed': position.speed,
        'heading': position.heading,
        'is_live': true,
        'is_helper': _isHelper,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  // ==================== FETCH LOCATIONS ====================

  /// Save user's last known location (call once when app starts or periodically)
  /// This ensures every user has a location record, even if they never go "live"
  Future<void> saveLastLocation() async {
    if (_userId == null) return;
    
    try {
      final hasPermission = await checkLocationPermission();
      if (!hasPermission) return;
      
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      
      await _supabase.from('live_locations').upsert({
        'user_id': _userId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed': 0,
        'heading': position.heading,
        'is_live': false, // This is just a background save, not going live
        'is_helper': _isHelper,
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('Saved last location for user');
    } catch (e) {
      debugPrint('Error saving last location: $e');
    }
  }

  /// Get live locations of bubble members (excludes current user)
  Future<List<LiveLocation>> getBubbleMembersLocations(String bubbleId) async {
    try {
      debugPrint('Fetching members for bubble: $bubbleId');
      // First get member user IDs
      final members = await _supabase
          .from('bubble_members')
          .select('user_id')
          .eq('bubble_id', bubbleId);

      debugPrint('Raw members found: ${members.length}');
      final userIds = (members as List).map((m) => m['user_id']).toList();
      
      // Remove current user from the list - we don't need to show ourselves
      userIds.remove(_userId);
      debugPrint('Member IDs after removing current user: ${userIds.length}');
      
      if (userIds.isEmpty) {
        debugPrint('No other members in this bubble.');
        return [];
      }

      // Get their locations (both live and last known)
      // Note: This will only return users who have a record in live_locations table
      final locations = await _supabase
          .from('live_locations')
          .select('*, user_profiles(display_name, avatar_url)')
          .inFilter('user_id', userIds);

      debugPrint('Fetched ${(locations as List).length} location records from DB');
      if (locations.isEmpty) {
         debugPrint('WARNING: Other members exist but have no location history yet.');
      }
      
      return locations.map((l) => LiveLocation.fromJson(l)).toList();
    } catch (e) {
      debugPrint('Error fetching bubble locations: $e');
      return [];
    }
  }

  /// Get nearby helpers (users with is_helper = true and is_live = true)
  Future<List<LiveLocation>> getNearbyHelpers() async {
    try {
      final locations = await _supabase
          .from('live_locations')
          .select('*, user_profiles(display_name, avatar_url)')
          .eq('is_live', true)
          .eq('is_helper', true);

      return (locations as List).map((l) => LiveLocation.fromJson(l)).toList();
    } catch (e) {
      debugPrint('Error fetching helpers: $e');
      return [];
    }
  }

  /// Stream of live locations for real-time updates
  Stream<List<Map<String, dynamic>>> streamBubbleLocations(String bubbleId) {
    return _supabase
        .from('live_locations')
        .stream(primaryKey: ['user_id'])
        .eq('is_live', true);
  }

  // ==================== PERMISSIONS ====================

  Future<bool> checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  /// Dispose resources
  void dispose() {
    _positionSubscription?.cancel();
  }
}
