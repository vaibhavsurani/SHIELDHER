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
      final List<Future> tasks = [];

      // Level 1: SMS + WhatsApp (Parallel)
      if (level >= 1) {
        tasks.add(_sendSOSMessages());
      }

      // Level 2: + Cascade Calling (Parallel to messages)
      if (level >= 2) {
        tasks.add(_startCascadeCalling());
      }

      // Level 3: + Auto audio recording (Parallel)
      if (level >= 3) {
        tasks.add(_startAutoRecording());
      }
      
      // Fire all tasks concurrently
      await Future.wait(tasks);

      debugPrint('🆘 Emergency Level $level actions initiated');
    } catch (e) {
      debugPrint('🆘 Error executing emergency: $e');
    }
  }

  /// Level 1: Send SOS via SMS and WhatsApp concurrently
  Future<void> _sendSOSMessages() async {
    debugPrint('🆘 Level 1: Sending SOS SMS + WhatsApp concurrently...');
    
    // 1. Send SMS (Fire and forget from main flow view)
    
    _emergencyService.sendSOSAutomatic().then((sent) {
        debugPrint('🆘 SMS result: $sent');
    });
    

    // 2. Send WhatsApp to all contacts concurrently
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

    // Fire WhatsApp intents closely together
    // The delay is small just to ensure order if system is slow, but much faster than before
    for (final contact in contacts) {
      _methodsChannel.invokeMethod('sendWhatsApp', {
        'phone': contact.phone,
        'message': message,
      }).catchError((e) {
        debugPrint('🆘 WhatsApp to ${contact.name} failed: $e');
      });
      
      // Minimal delay to let the intent fire
      await Future.delayed(const Duration(milliseconds: 500)); 
    }
  }

  /// Level 2: Cascade Calling (Sequential with Timeout)
  Future<void> _startCascadeCalling() async {
    debugPrint('🆘 Level 2: Starting Cascade Calling...');
    final contacts = await _emergencyService.getContacts();
    
    if (contacts.isEmpty) {
        debugPrint('🆘 No contacts to call.');
        return;
    }

    for (int i = 0; i < contacts.length; i++) {
        final contact = contacts[i];
        debugPrint('🆘 Cascade Call ${i+1}/${contacts.length}: Calling ${contact.name}...');
        
        try {
            await _methodsChannel.invokeMethod('makePhoneCall', {
                'phone': contact.phone,
            });
        } catch (e) {
            debugPrint('🆘 Call failed: $e');
        }

        // If this is the last contact, we don't need to wait
        if (i == contacts.length - 1) break;

        debugPrint('🆘 Waiting 30s before calling next contact (if needed)...');
        // Wait 30 seconds before dialing the next person
        // If the user is on the phone, the OS handles the new dial request (usually creating a queue or replacing)
        // Ideally, we'd detect "Call Ended" state, but without READ_PHONE_STATE (high risk permission),
        // a timer is the most reliable fallback.
        await Future.delayed(const Duration(seconds: 30));
    }
    
    debugPrint('🆘 Cascade Calling sequence finished.');
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
