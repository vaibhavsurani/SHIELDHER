import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shieldher/services/audio_recorder_service.dart';
import 'package:shieldher/widgets/app_header.dart';

/// Record Tab content widget — audio recording and playback.
class RecordTabContent extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final VoidCallback? onNotificationTap;
  final int notificationCount;

  const RecordTabContent({
    super.key,
    required this.scaffoldKey,
    this.onNotificationTap,
    this.notificationCount = 0,
  });

  @override
  State<RecordTabContent> createState() => _RecordTabContentState();
}

class _RecordTabContentState extends State<RecordTabContent> {
  final AudioRecorderService _recorder = AudioRecorderService();
  final AudioPlayer _player = AudioPlayer();
  bool _isRecording = false;

  // Audio playback state
  String? _currentPlayingUrl;
  String? _loadingUrl;
  DateTime _loadStartTime = DateTime.now();
  bool _isPlaying = false;
  bool _isCompleted = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Timer? _positionTimer;
  Timer? _recordTimer;
  int _recordSeconds = 0;
  int _visibleCount = 5;
  Stream<List<Map<String, dynamic>>>? _recordingsStream;
  bool _isDragging = false;

  Stream<List<Map<String, dynamic>>> get recordingsStream =>
      _recordingsStream ??= _recorder.getRecordings();

  @override
  void initState() {
    super.initState();

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (state == PlayerState.playing) {
            _isCompleted = false;
            _startPositionTimer();
          } else if (state == PlayerState.paused || state == PlayerState.stopped) {
            _loadingUrl = null;
            _positionTimer?.cancel();
          } else {
            _positionTimer?.cancel();
          }
        });
      }
    });

    _player.onDurationChanged.listen((newDuration) {
      if (mounted && _loadingUrl == null) {
        setState(() => _duration = newDuration);
      }
    });

    _player.onPositionChanged.listen((newPosition) {
      if (mounted && !_isDragging && _loadingUrl == null) {
        setState(() => _position = newPosition);
      }
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isCompleted = true;
          _position = Duration.zero;
          _positionTimer?.cancel();
        });
      }
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _positionTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    DateTime lastTick = DateTime.now();

    _positionTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!mounted || !_isPlaying) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final elapsed = now.difference(lastTick);
      lastTick = now;

      Duration? p;
      try {
        p = await _player.getCurrentPosition();
      } catch (_) {}

      if (_loadingUrl != null) {
        if (p != null && p > const Duration(milliseconds: 200)) {
          setState(() {
            _loadingUrl = null;
            _position = p!;
          });
        } else {
          final timeSinceLoad = DateTime.now().difference(_loadStartTime);
          if (timeSinceLoad.inMilliseconds > 2000) {
            setState(() => _loadingUrl = null);
          } else {
            return;
          }
        }
      } else {
        if (p != null) {
          setState(() => _position = p!);
        } else {
          setState(() {
            final newPos = _position + elapsed;
            if (_duration > Duration.zero && newPos > _duration) {
              _position = _duration;
            } else {
              _position = newPos;
            }
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            AppHeader(
              scaffoldKey: widget.scaffoldKey,
              onNotificationTap: widget.onNotificationTap,
              notificationCount: widget.notificationCount,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Record',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'In case of an emergency, document a situation confidentially.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    _buildRecordingCard(),
                    const SizedBox(height: 10),
                    _buildStartButton(),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Recordings',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.grey),
                          onPressed: _refreshRecordings,
                          tooltip: 'Refresh list',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: recordingsStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red));
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Text('No recordings yet', style: TextStyle(color: Colors.grey.shade500));
                        }

                        final allRecordings = snapshot.data!;
                        final visibleRecordings = allRecordings.take(_visibleCount).toList();
                        final hasMore = allRecordings.length > _visibleCount;

                        return Column(
                          children: [
                            ...visibleRecordings.map((r) => _buildRecordingItem(r)),
                            if (hasMore)
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: TextButton(
                                  onPressed: () => setState(() => _visibleCount += 8),
                                  child: const Text('Show More'),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    await _recorder.startRecording();
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });

    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isRecording) {
        setState(() => _recordSeconds++);
        if (_recordSeconds >= 30) {
          timer.cancel();
          _stopRecording();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording stopped automatically (30s limit)')),
          );
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final url = await _recorder.stopRecording();
    if (mounted) setState(() => _isRecording = false);

    if (url != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording saved!'), backgroundColor: Colors.green),
        );
      }
      try {
        await _recorder.uploadToSupabase(url);
        _refreshRecordings();
      } catch (e) {
        debugPrint('Upload error: $e');
      }
    }
  }

  void _refreshRecordings() {
    if (mounted) {
      setState(() {
        _recordingsStream = null;
        _visibleCount = 5;
      });
    }
  }

  Future<void> _playRecording(String url) async {
    if (_currentPlayingUrl == url) {
      if (_isPlaying) {
        await _player.pause();
        setState(() => _isPlaying = false);
      } else if (_isCompleted) {
        await _player.stop();
        await _player.play(UrlSource(url));
        setState(() {
          _isPlaying = true;
          _isCompleted = false;
          _position = Duration.zero;
        });
      } else {
        await _player.resume();
        setState(() => _isPlaying = true);
      }
    } else {
      setState(() {
        _loadingUrl = url;
        _loadStartTime = DateTime.now();
        _currentPlayingUrl = url;
        _isPlaying = false;
        _position = Duration.zero;
        _isDragging = false;
        _duration = Duration.zero;
      });

      await _player.stop();
      await _player.setSource(UrlSource(url));
      await _player.seek(Duration.zero);

      Duration? duration;
      try {
        duration = await _player.getDuration();
      } catch (e) {
        debugPrint('Error getting duration: $e');
      }

      await _player.resume();

      setState(() {
        _currentPlayingUrl = url;
        _isPlaying = true;
        _isCompleted = false;
        _position = Duration.zero;
        if (duration != null) {
          _duration = duration;
        } else {
          _duration = Duration.zero;
          Future.doWhile(() async {
            if (!mounted || !_isPlaying || _currentPlayingUrl != url) return false;
            await Future.delayed(const Duration(milliseconds: 500));
            try {
              final d = await _player.getDuration();
              if (d != null && d > Duration.zero) {
                if (mounted) setState(() => _duration = d);
                return false;
              }
            } catch (_) {}
            return true;
          });
        }
      });
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildRecordingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _isRecording ? Colors.red.shade50 : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mic,
              color: _isRecording ? Colors.red : Colors.grey,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _isRecording
                ? Row(
                    children: [
                      const Expanded(child: RecordingWaveform()),
                      const SizedBox(width: 12),
                      Text(
                        '00:${_recordSeconds.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Record Audio',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Time limit: 30 seconds',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return Center(
      child: GestureDetector(
        onTap: _toggleRecording,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          decoration: BoxDecoration(
            color: _isRecording ? Colors.red : const Color(0xFFC2185B),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: (_isRecording ? Colors.red : Colors.black).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                _isRecording ? 'Stop Recording' : 'Starting Recording',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingItem(Map<String, dynamic> recording) {
    final url = recording['url'] as String? ?? '';
    final fileName = recording['file_name'] as String? ?? 'Recording';
    final createdAt = recording['created_at'] as String?;
    final lat = recording['latitude'];
    final lng = recording['longitude'];

    String timeStr = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) timeStr = DateFormat('MMM d, h:mm a').format(dt);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFC2185B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: (_loadingUrl == url)
                  ? const Padding(
                      padding: EdgeInsets.all(10.0),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC2185B)),
                    )
                  : Icon(
                      (_currentPlayingUrl == url && _isPlaying) ? Icons.pause : Icons.play_arrow,
                      color: const Color(0xFFC2185B),
                    ),
            ),
            title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
            subtitle: Text(timeStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            trailing: (lat != null && lng != null)
                ? IconButton(
                    icon: const Icon(Icons.map, color: Colors.blueAccent),
                    onPressed: () => _openMap((lat as num).toDouble(), (lng as num).toDouble()),
                  )
                : null,
            onTap: () => _playRecording(url),
          ),
          if (_currentPlayingUrl == url)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Slider(
                    value: _position.inMilliseconds.toDouble().clamp(
                        0.0, (_duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 30000.0)),
                    min: 0.0,
                    max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 30000.0,
                    activeColor: const Color(0xFFC2185B),
                    inactiveColor: Colors.grey.shade200,
                    onChanged: (value) {
                      setState(() {
                        _isDragging = true;
                        _position = Duration(milliseconds: value.toInt());
                      });
                    },
                    onChangeEnd: (value) async {
                      final position = Duration(milliseconds: value.toInt());
                      await _player.seek(position);
                      setState(() {
                        _isDragging = false;
                        _position = position;
                      });
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(_position),
                            style: const TextStyle(fontSize: 10, color: Colors.black54)),
                        Text(_formatDuration(_duration),
                            style: const TextStyle(fontSize: 10, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}

/// Animated waveform visualization shown during active recording.
class RecordingWaveform extends StatefulWidget {
  const RecordingWaveform({super.key});

  @override
  State<RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<RecordingWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(10, (index) {
            final height = 10.0 +
                (20.0 *
                    (0.5 +
                        0.5 *
                            ((index % 2 == 0 ? 1 : -1) *
                                (0.5 - (_controller.value + index / 10) % 1).abs() *
                                2)));
            return Container(
              width: 4,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }),
        );
      },
    );
  }
}
