import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shieldher/services/emergency_service.dart';
import 'package:shieldher/services/audio_recorder_service.dart';

/// Service that listens for power button SOS triggers from native Android
/// and orchestrates emergency actions based on the level.
class PowerButtonSOSService {
  static const MethodChannel _sosChannel = MethodChannel('com.example.shieldher/sos');
  static const MethodChannel _methodsChannel = MethodChannel('com.example.shieldher/methods');
  
  static final PowerButtonSOSService _instance = PowerButtonSOSService._internal();
  factory PowerButtonSOSService() => _instance;
  PowerButtonSOSService._internal();

  final EmergencyService _emergencyService = EmergencyService();
  final AudioRecorderService _audioRecorderService = AudioRecorderService();
  
  bool _isInitialized = false;

  /// Initialize the SOS listener. Call this once at app startup.
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    
    _sosChannel.setMethodCallHandler((call) async {
      if (call.method == 'triggerSOSLevel') {
        final level = call.arguments['level'] as int;
        debugPrint('🆘 SOS Triggered! Level: $level');
        await _executeEmergency(level);
      }
    });
    
    debugPrint('PowerButtonSOSService initialized');
  }

  /// Execute emergency actions based on level
  Future<void> _executeEmergency(int level) async {
    try {
      // Level 1: SMS + WhatsApp with location
      if (level >= 1) {
        await _sendSOSMessages();
      }

      // Level 2: + Call all emergency contacts
      if (level >= 2) {
        await _callAllContacts();
      }

      // Level 3: + Auto audio recording
      if (level >= 3) {
        await _startAutoRecording();
      }

      debugPrint('🆘 Emergency Level $level actions completed');
    } catch (e) {
      debugPrint('🆘 Error executing emergency: $e');
    }
  }

  /// Level 1: Send SOS via SMS and WhatsApp
  Future<void> _sendSOSMessages() async {
    debugPrint('🆘 Level 1: Sending SOS SMS + WhatsApp...');
    
    // Send SMS (uses existing EmergencyService)
    final smsSent = await _emergencyService.sendSOSAutomatic();
    debugPrint('🆘 SMS sent: $smsSent');

    // Send WhatsApp to all contacts
    final contacts = await _emergencyService.getContacts();
    final userName = await _emergencyService.getUserName();
    final position = await _emergencyService.getCurrentLocation();

    String message;
    if (position != null) {
      final mapsLink = 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
      message = '🆘 EMERGENCY SOS from $userName! I need help immediately! My location: $mapsLink';
    } else {
      message = '🆘 EMERGENCY SOS from $userName! I need help immediately! Location unavailable.';
    }

    for (final contact in contacts) {
      try {
        await _methodsChannel.invokeMethod('sendWhatsApp', {
          'phone': contact.phone,
          'message': message,
        });
        // Small delay between WhatsApp messages to avoid overwhelming
        await Future.delayed(const Duration(milliseconds: 1500));
      } catch (e) {
        debugPrint('🆘 WhatsApp to ${contact.name} failed: $e');
      }
    }
  }

  /// Level 2: Call all emergency contacts
  Future<void> _callAllContacts() async {
    debugPrint('🆘 Level 2: Calling all emergency contacts...');
    
    final contacts = await _emergencyService.getContacts();
    
    for (final contact in contacts) {
      try {
        debugPrint('🆘 Calling ${contact.name} (${contact.phone})...');
        await _methodsChannel.invokeMethod('makePhoneCall', {
          'phone': contact.phone,
        });
        // Wait a bit between calls - user needs to end each call
        // In practice, only the first call can be made automatically
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('🆘 Call to ${contact.name} failed: $e');
      }
    }
  }

  /// Level 3: Start auto audio recording loop (3 chunks of 15s)
  Future<void> _startAutoRecording() async {
    debugPrint('🆘 Level 3: Starting auto audio recording loop...');
    
    try {
      final hasPermission = await _audioRecorderService.hasPermission();
      if (!hasPermission) {
        debugPrint('🆘 Audio recording permission not granted');
        return;
      }

      // Record 3 chunks
      for (int i = 0; i < 3; i++) {
        debugPrint('🆘 Recording chunk ${i + 1}/3 initializing...');
        
        // Ensure valid state before starting
        if (await _audioRecorderService.isRecording) {
            await _audioRecorderService.stopRecording();
        }

        // Capture specific start time for this chunk
        final chunkStartTime = DateTime.now();

        await _audioRecorderService.startRecording();
        debugPrint('🆘 Recording chunk ${i + 1}/3 started at $chunkStartTime');
        
        // Wait exactly 15 seconds
        await Future.delayed(const Duration(seconds: 15));
        
        // Stop and get path
        debugPrint('🆘 Chunk ${i + 1}/3 stopping...');
        final filePath = await _audioRecorderService.stopRecording();
        debugPrint('🆘 Chunk ${i + 1}/3 stopped. Path: $filePath');

        if (filePath != null) {
          // Upload in background (fire and forget for the loop)
          _audioRecorderService.uploadToSupabase(
            filePath, 
            startTime: chunkStartTime 
          ).then((url) {
            debugPrint('🆘 Chunk ${i + 1} uploaded: $url');
          }).catchError((e) {
            debugPrint('🆘 Chunk ${i + 1} upload failed: $e');
          });
        } else {
             debugPrint('🆘 Chunk ${i + 1} failed: No file path returned');
        }
        
        // No artificial delay between chunks to minimize gap
      }
      
      debugPrint('🆘 Audio recording loop completed');

    } catch (e) {
      debugPrint('🆘 Error in recording loop: $e');
    }
  }

  void dispose() {
    _audioRecorderService.dispose();
  }
}
