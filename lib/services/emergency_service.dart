import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class EmergencyContact {
  final String id;
  final String name;
  final String phone;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
    );
  }
}

class EmergencyService {
  static const int maxContacts = 5;
  static const platform = MethodChannel('com.example.shieldher/methods');
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  // Get contacts with offline support
  Future<List<EmergencyContact>> getContacts() async {
    if (_userId == null) return [];

    try {
      // 1. Try Network
      final data = await _supabase
          .from('emergency_contacts')
          .select()
          .eq('user_id', _userId!);
      
      final List<dynamic> dataList = data as List<dynamic>;
      final contacts = dataList.map((json) => EmergencyContact.fromJson(json)).toList();

      // 2. Save to Cache
      await _cacheContacts(contacts);
      
      return contacts;
    } catch (e) {
      debugPrint('Error fetching contacts from network: $e');
      // 3. Fallback to Cache
      return await _getCachedContacts();
    }
  }

  Future<void> _cacheContacts(List<EmergencyContact> contacts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonString = jsonEncode(contacts.map((c) => c.toJson()).toList());
      await prefs.setString('cached_emergency_contacts', jsonString);
    } catch (e) {
      debugPrint('Error caching contacts: $e');
    }
  }

  Future<List<EmergencyContact>> _getCachedContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString('cached_emergency_contacts');
      
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        return jsonList.map((json) => EmergencyContact.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error reading cached contacts: $e');
    }
    return [];
  }

  // Add a new emergency contact
  Future<bool> addContact(String name, String phone) async {
    if (_userId == null) return false;

    // Use cached contacts for the limit check to support offline
    final contacts = await getContacts();
    if (contacts.length >= maxContacts) {
      return false;
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final newContact = EmergencyContact(id: id, name: name, phone: phone);

    // Optimized: Add to local cache immediately (Optimistic UI)
    contacts.add(newContact);
    await _cacheContacts(contacts);

    try {
      // Try Network Insert
      await _supabase.from('emergency_contacts').insert({
        'id': id,
        'user_id': _userId,
        'name': name,
        'phone': phone,
      });
      return true;
    } catch (e) {
      debugPrint('Network add failed, queuing for sync: $e');
      // Network failed? We already added to cache, so it works offline.
      // We should queue this for later sync.
      await _addToContactUploadQueue(newContact);
      return true; // Return true so UI shows success!
    }
  }

  Future<void> _addToContactUploadQueue(EmergencyContact contact) async {
     try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString('pending_contact_uploads');
      List<EmergencyContact> queue = [];
      
      if (jsonString != null) {
         final List<dynamic> list = jsonDecode(jsonString);
         queue = list.map((json) => EmergencyContact.fromJson(json)).toList();
      }
      
      queue.add(contact);
      
      final String newJsonString = jsonEncode(queue.map((c) => c.toJson()).toList());
      await prefs.setString('pending_contact_uploads', newJsonString);
    } catch (e) {
      debugPrint('Error queuing contact: $e');
    }
  }

  Future<void> syncPendingContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString('pending_contact_uploads');
      if (jsonString == null) return;

      List<dynamic> list = jsonDecode(jsonString);
      List<EmergencyContact> queue = list.map((json) => EmergencyContact.fromJson(json)).toList();
      List<EmergencyContact> remaining = [];

      debugPrint('Sync pending contacts: ${queue.length} items');

      for (var contact in queue) {
        try {
           await _supabase.from('emergency_contacts').insert({
            'id': contact.id,
            'user_id': _userId,
            'name': contact.name,
            'phone': contact.phone,
          });
        } catch (e) {
           debugPrint('Retry add contact failed: $e');
           remaining.add(contact);
        }
      }

      if (remaining.isNotEmpty) {
         final String newJsonString = jsonEncode(remaining.map((c) => c.toJson()).toList());
         await prefs.setString('pending_contact_uploads', newJsonString);
      } else {
         await prefs.remove('pending_contact_uploads');
      }

    } catch (e) {
      debugPrint('Error syncing contacts: $e');
    }
  }

  // Update an existing contact
  Future<void> updateContact(String id, String name, String phone) async {
    if (_userId == null) return;
    try {
       await _supabase.from('emergency_contacts').update({
        'name': name,
        'phone': phone,
      }).eq('id', id);
    } catch (e) {
      debugPrint('Error updating contact: $e');
    }
  }

  // Delete a contact
  Future<void> deleteContact(String id) async {
    if (_userId == null) return;
    try {
      await _supabase.from('emergency_contacts').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting contact: $e');
    }
  }

  // Get user name (from metadata)
  Future<String> getUserName() async {
    final metadata = _supabase.auth.currentUser?.userMetadata;
    return metadata?['name'] ?? 'User';
  }

  // Check and request location permission
  Future<bool> checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // Get current location with better error handling
  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await checkLocationPermission();
      if (!hasPermission) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      // Try to get last known position as fallback
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  // Send SOS SMS automatically to all emergency contacts via native Android
  Future<bool> sendSOSAutomatic() async {
    final contacts = await getContacts();
    if (contacts.isEmpty) {
      return false;
    }

    // Get user name and location
    final userName = await getUserName();
    final position = await getCurrentLocation();

    String message;
    if (position != null) {
      final mapsLink = 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
      message = 'EMERGENCY SOS from $userName! I need help immediately! My location: $mapsLink';
    } else {
      message = 'EMERGENCY SOS from $userName! I need help immediately! Location unavailable - please try to contact me!';
    }

    // Try to send via native Android
    try {
      final phoneNumbers = contacts.map((c) => c.phone).toList();
      final result = await platform.invokeMethod('sendSMS', {
        'phones': phoneNumbers,
        'message': message,
      });
      if (result == true) {
        return true;
      }
    } catch (e) {
      // Native SMS failed, fall back to SMS app
    }

    // Fallback: open SMS app
    return await _sendSOSViaApp(contacts, message);
  }

  // Fallback: open SMS app
  Future<bool> _sendSOSViaApp(List<EmergencyContact> contacts, String message) async {
    final phoneNumbers = contacts.map((c) => c.phone).join(',');
    final smsUri = Uri(
      scheme: 'sms',
      path: phoneNumbers,
      queryParameters: {'body': message},
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Share location (for the Share Location button)
  Future<bool> shareLocation() async {
    final position = await getCurrentLocation();
    if (position == null) {
      return false;
    }

    final mapsLink = 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
    final message = 'Here is my current location: $mapsLink';

    final smsUri = Uri(
      scheme: 'sms',
      queryParameters: {'body': message},
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
