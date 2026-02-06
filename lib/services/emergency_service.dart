import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

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

  // Get contacts
  Future<List<EmergencyContact>> getContacts() async {
    if (_userId == null) return [];

    try {
      final data = await _supabase
          .from('emergency_contacts')
          .select()
          .eq('user_id', _userId!);
      
      final List<dynamic> dataList = data as List<dynamic>;
      return dataList.map((json) => EmergencyContact.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching contacts: $e');
      return [];
    }
  }

  // Add a new emergency contact
  Future<bool> addContact(String name, String phone) async {
    if (_userId == null) return false;

    final contacts = await getContacts();
    if (contacts.length >= maxContacts) {
      return false;
    }

    // Assuming we have a table 'emergency_contacts' with fields: id (uuid/string), user_id, name, phone
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    try {
      await _supabase.from('emergency_contacts').insert({
        'id': id,
        'user_id': _userId,
        'name': name,
        'phone': phone,
      });
      return true;
    } catch (e) {
      print('Error adding contact: $e');
      return false;
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
      print('Error updating contact: $e');
    }
  }

  // Delete a contact
  Future<void> deleteContact(String id) async {
    if (_userId == null) return;
    try {
      await _supabase.from('emergency_contacts').delete().eq('id', id);
    } catch (e) {
      print('Error deleting contact: $e');
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
