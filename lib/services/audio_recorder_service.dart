import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shieldher/services/emergency_service.dart';

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
      // For mobile, record to a file
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
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

  Future<String?> uploadToSupabase(String? filePath, {DateTime? startTime}) async {
    if (filePath == null || filePath.isEmpty) return null;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Use provided start time or current time
    final timestamp = (startTime ?? DateTime.now()).millisecondsSinceEpoch;
    final fileName = '${user.id}/$timestamp.m4a';
    final bucket = 'audio_recordings';

    try {
      if (kIsWeb) {
        // For web, the path is a blob URL, but for Supabase we need bytes
        // But record package on web returns blob URL. fetching bytes from blob URL might be tricky in dart without dart:html
        // Actually, Supabase storage uploadBinary accepts Uint8List.
        // We might need to fetch the blob data.
        // However, record package returns a Blob URL on web.
        // A simpler way for web might be to rely on the fact that we can't easily read blob from url in plain dart IO.
        // But let's try to assume we can get bytes.
        // NOTE: 'record' on web returns a blob URI.
        throw Exception("Web upload not fully implemented in this migration snippet without extra http call to get blob data");
      } else {
        final file = File(filePath);
        if (!file.existsSync()) {
             throw Exception('File not found at path: $filePath');
        }
        await _supabase.storage.from(bucket).upload(fileName, file);
      }
      
      final downloadUrl = _supabase.storage.from(bucket).getPublicUrl(fileName);
      
      // Fetch location
      final Position? position = await EmergencyService().getCurrentLocation();
      
      // Convert to IST (UTC + 5:30)
      final dateUtc = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
      final dateIst = dateUtc.add(const Duration(hours: 5, minutes: 30));
      final formattedDate = "${dateIst.year}-${dateIst.month.toString().padLeft(2, '0')}-${dateIst.day.toString().padLeft(2, '0')}";
      final formattedTime = "${dateIst.hour.toString().padLeft(2, '0')}:${dateIst.minute.toString().padLeft(2, '0')}:${dateIst.second.toString().padLeft(2, '0')}";
      
      await _saveToSupabase(
        user.id, 
        downloadUrl, 
        fileName: 'Audio $formattedDate $formattedTime',
        latitude: position?.latitude,
        longitude: position?.longitude,
      );
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload audio: $e');
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
