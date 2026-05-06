import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shieldher/services/emergency_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AudioRecorderService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isRecording = false;
  Timer? _timer;
  int _recordingDuration = 0;


  bool get isRecording => _isRecording;
  int get recordingDuration => _recordingDuration;

  // Stream controller for duration updates
  final StreamController<int> _durationController = StreamController<int>.broadcast();
  Stream<int> get durationStream => _durationController.stream;

  Future<bool> hasPermission() async {
    return await _audioRecorder.hasPermission();
  }

  Future<void> startRecording() async {
    if (_isRecording) return;

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission not granted');
    }

    _recordingDuration = 0;
    _isRecording = true;

    // Configure recording
    const config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 128000,
      sampleRate: 44100,
    );

    if (kIsWeb) {
      // For web, record to a blob
      await _audioRecorder.start(config, path: '');
    } else {
      // For mobile, record to a persistent file
      final dir = await getApplicationDocumentsDirectory();
      // Create a specific subdirectory for recordings to keep things organized
      final recordingDir = Directory('${dir.path}/sos_recordings');
      if (!await recordingDir.exists()) {
        await recordingDir.create(recursive: true);
      }
      final path = '${recordingDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(config, path: path);
    }

    // Start timer
    // Start timer for duration tracking only
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _recordingDuration++;
      _durationController.add(_recordingDuration);
    });
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    _timer?.cancel();
    _isRecording = false;
    final path = await _audioRecorder.stop();
    return path;
  }

  Future<void> syncPendingUploads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString('pending_audio_uploads');
      if (jsonString == null) return;

      List<dynamic> list = jsonDecode(jsonString);
      List<Map<String, dynamic>> queue = List<Map<String, dynamic>>.from(list);
      List<Map<String, dynamic>> remaining = [];

      debugPrint('Sync pending uploads: ${queue.length} items');

      for (var item in queue) {
        final path = item['path'];
        // Use a safe timestamp default if parsing fails
        final timestamp = item['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
        
        try {
          final file = File(path);
          if (await file.exists()) {
             // Generate filename consistent with original logic
             final user = _supabase.auth.currentUser;
             if (user != null) {
                final fileName = '${user.id}/$timestamp.m4a';
                await _uploadFileToSupabase(file, fileName, timestamp);
                // On success, delete local file
                await file.delete();
                debugPrint('Offine upload success: $path');
             } else {
               remaining.add(item); // User not logged in, keep in queue
             }
          } else {
            debugPrint('Pending file not found, removing from queue: $path');
          }
        } catch (e) {
          debugPrint('Retry upload failed for $path: $e');
          remaining.add(item); // Keep in queue
        }
      }

      // Update queue
      if (remaining.isNotEmpty) {
        await prefs.setString('pending_audio_uploads', jsonEncode(remaining));
      } else {
        await prefs.remove('pending_audio_uploads');
      }

    } catch (e) {
      debugPrint('Error syncing pending uploads: $e');
    }
  }

  Future<void> _addToUploadQueue(String filePath, int timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString('pending_audio_uploads');
      List<Map<String, dynamic>> queue = [];
      
      if (jsonString != null) {
         final List<dynamic> list = jsonDecode(jsonString);
         queue = List<Map<String, dynamic>>.from(list);
      }
      
      queue.add({
        'path': filePath,
        'timestamp': timestamp,
      });
      
      await prefs.setString('pending_audio_uploads', jsonEncode(queue));
      debugPrint('Added recording to offline queue: $filePath');
    } catch (e) {
      debugPrint('Error adding to upload queue: $e');
    }
  }

  // Refactored primitive upload function
  Future<String> _uploadFileToSupabase(File file, String fileName, int timestamp) async {
    final bucket = 'audio_recordings';
    await _supabase.storage.from(bucket).upload(fileName, file);
    
    final downloadUrl = _supabase.storage.from(bucket).getPublicUrl(fileName);
      
    // Fetch location (might be outdated if offline, but better than nothing)
    // In a real offline scenario, we should have cached the location with the recording metadata.
    // For now, valid location or null is acceptable.
    final Position? position = await EmergencyService().getCurrentLocation();
      
    // Convert to IST (UTC + 5:30)
    final dateUtc = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
    final dateIst = dateUtc.add(const Duration(hours: 5, minutes: 30));
    final formattedDate = "${dateIst.year}-${dateIst.month.toString().padLeft(2, '0')}-${dateIst.day.toString().padLeft(2, '0')}";
    final formattedTime = "${dateIst.hour.toString().padLeft(2, '0')}:${dateIst.minute.toString().padLeft(2, '0')}:${dateIst.second.toString().padLeft(2, '0')}";
      
    await _saveToSupabase(
      _supabase.auth.currentUser!.id, 
      downloadUrl, 
      fileName: 'Audio $formattedDate $formattedTime',
      latitude: position?.latitude,
      longitude: position?.longitude,
    );
    return downloadUrl;
  }

  Future<String?> uploadToSupabase(String? filePath, {DateTime? startTime}) async {
    if (filePath == null || filePath.isEmpty) return null;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated'); // Cannot upload or queue without user ID context practically
    }

    // Try to sync old items first
    syncPendingUploads();

    // Use provided start time or current time
    final timestamp = (startTime ?? DateTime.now()).millisecondsSinceEpoch;
    final fileName = '${user.id}/$timestamp.m4a';

    try {
      if (kIsWeb) {
        throw Exception("Web upload not supported in offline mode yet");
      } else {
        final file = File(filePath);
        if (!file.existsSync()) {
             throw Exception('File not found at path: $filePath');
        }
        
        // Return URL on success
        final url = await _uploadFileToSupabase(file, fileName, timestamp);
        
        // If successful, we can delete the local persistent file to save space?
        // User asked to "delete from local" on success.
        try { await file.delete(); } catch (_) {}
        
        return url;
      }
    } catch (e) {
      debugPrint('Upload failed, queuing for offline: $e');
      // Queue for later
      if (!kIsWeb) {
         await _addToUploadQueue(filePath, timestamp);
      }
      return null;
    }
  }

  Future<void> _saveToSupabase(String userId, String url, {required String fileName, double? latitude, double? longitude}) async {
    // Assuming table 'audio_recordings'
    await _supabase.from('audio_recordings').insert({
      'user_id': userId,
      'url': url,
      'file_name': fileName,
      'latitude': latitude,
      'longitude': longitude,
      // 'created_at': DateTime.now().toIso8601String(), // Supabase usually handles created_at
    });
  }

  Stream<List<Map<String, dynamic>>> getRecordings() {
    final user = _supabase.auth.currentUser;
    if (user == null) return const Stream.empty();

    return _supabase
        .from('audio_recordings')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
  }

  Future<void> deleteRecording(String id, String url) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
        // Delete from Database
        await _supabase
            .from('audio_recordings')
            .delete()
            .eq('id', id);
            
        // Delete from Storage
        // Extract filename from URL or store storage path in DB.
        // URL is: https://.../storage/v1/object/public/audio_recordings/USER_ID/TIMESTAMP.m4a
        // Path is: USER_ID/TIMESTAMP.m4a
        
        final uri = Uri.parse(url);
        final pathSegments = uri.pathSegments;
        // pathSegments usually: [storage, v1, object, public, audio_recordings, USER_ID, TIMESTAMP.m4a]
        // We want the part after bucket name.
        final bucketIndex = pathSegments.indexOf('audio_recordings');
        if (bucketIndex != -1 && bucketIndex + 1 < pathSegments.length) {
            final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
            await _supabase.storage.from('audio_recordings').remove([filePath]);
        }
    } catch (e) {
        debugPrint("Error deleting recording: $e");
    }
  }

  void dispose() {
    _timer?.cancel();
    _durationController.close();
    _audioRecorder.dispose();
  }
}
