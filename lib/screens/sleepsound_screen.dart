import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class SleepSoundScreen extends StatefulWidget {
  const SleepSoundScreen({super.key});

  @override
  State<SleepSoundScreen> createState() => _SleepSoundScreenState();
}

class _SleepSoundScreenState extends State<SleepSoundScreen> {
  final AudioPlayer _player = AudioPlayer();
  String? _currentlyPlaying;
  double _volume = 0.8;

  // Sleep Timer
  Duration? _sleepTimerDuration;
  Timer? _sleepTimer;
  String _remainingTimeText = "";

  // สำหรับอัปเดต UI ใน Bottom Sheet อย่างปลอดภัย
  StateSetter? _sheetSetState;
  bool _isSheetOpen = false;

  final List<_SoundItem> _sounds = const [
    _SoundItem(title: "Birdsong",  file: "assets/sleep_sounds/birdsong_3.mp3"),
    _SoundItem(title: "Birdsong",  file: "assets/sleep_sounds/birds_short.mp3"),
    _SoundItem(title: "Birdsong",  file: "assets/sleep_sounds/birds_morning.mp3"),
    _SoundItem(title: "Forestsong",file: "assets/sleep_sounds/forest_ambience_1.mp3"),
    _SoundItem(title: "Forestsong",file: "assets/sleep_sounds/forest_ambience_2.mp3"),
    _SoundItem(title: "Forestsong",file: "assets/sleep_sounds/forest-moutain.mp3"),
    _SoundItem(title: "Rainsong",  file: "assets/sleep_sounds/rain_forest_birds.mp3"),
    _SoundItem(title: "Watersong", file: "assets/sleep_sounds/water-stream.mp3"),
  ];

  @override
  void initState() {
    super.initState();
    _player.setLoopMode(LoopMode.one);
    _player.setVolume(_volume);
  }

  Future<void> _playSound(_SoundItem sound) async {
    if (_currentlyPlaying == sound.file) {
      await _player.stop();
      setState(() => _currentlyPlaying = null);
      return;
    }
    try {
      await _player.setAsset(sound.file);
      await _player.play();
      setState(() => _currentlyPlaying = sound.file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เล่นเสียงไม่ได้: ${sound.title}')),
      );
    }
  }

  // ---- Bottom Sheet (หน้าเล่นเพลงเต็มจอ) ----
  void _showPlayerModal(_SoundItem sound) {
    _isSheetOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // เก็บตัวชี้ setState ของ sheet ไว้ใช้อัปเดตจาก Timer
          _sheetSetState = setModalState;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  Text(
                    sound.title,
                    style: const TextStyle(fontSize: 22, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  IconButton(
                    iconSize: 64,
                    icon: Icon(
                      _currentlyPlaying == sound.file
                          ? Icons.pause_circle
                          : Icons.play_circle,
                      color: Colors.cyanAccent,
                    ),
                    onPressed: () => _playSound(sound),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.volume_down, color: Colors.white),
                      Expanded(
                        child: Slider(
                          value: _volume,
                          onChanged: (v) {
                            setState(() => _volume = v);
                            _player.setVolume(v);
                            // อัปเดตใน sheet ถ้ายังเปิดอยู่
                            if (_isSheetOpen && _sheetSetState != null) {
                              _sheetSetState!(() {});
                            }
                          },
                          activeColor: Colors.cyanAccent,
                        ),
                      ),
                      const Icon(Icons.volume_up, color: Colors.white),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _showSleepTimerDialog,
                    icon: const Icon(Icons.timer),
                    label: const Text("ตั้งเวลา"),
                  ),
                  if (_sleepTimerDuration != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        "จะหยุดเล่นใน $_remainingTimeText",
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      // sheet ถูกปิดแล้ว
      _isSheetOpen = false;
      _sheetSetState = null;
    });
  }

  // ---- Sleep Timer ----
  void _showSleepTimerDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [2, 60, 90].map((min) {
            return ListTile(
              title: Text("ปิดเสียงใน $min นาที"),
              onTap: () {
                Navigator.pop(context);
                _startSleepTimer(Duration(minutes: min));
              },
            );
          }).toList(),
        );
      },
    );
  }

  void _startSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepTimerDuration = duration;

    final endTime = DateTime.now().add(duration);

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = endTime.difference(DateTime.now());

      if (!mounted) {
        timer.cancel();
        return;
      }

      if (remaining.isNegative) {
        // Fade-out เล็กน้อยก่อนหยุด
        _fadeOutAndStop();
        timer.cancel();
        setState(() {
          _sleepTimerDuration = null;
          _remainingTimeText = "";
          _currentlyPlaying = null;
        });
      } else {
        setState(() {
          _remainingTimeText =
              "${remaining.inMinutes} นาที ${remaining.inSeconds % 60} วินาที";
        });
        // อัปเดต UI ใน sheet ถ้ายังเปิดอยู่
        if (_isSheetOpen && _sheetSetState != null) {
          _sheetSetState!(() {});
        }
      }
    });
  }

  Future<void> _fadeOutAndStop({Duration duration = const Duration(seconds: 3)}) async {
    final steps = 15;
    final stepDur = duration ~/ steps;
    final startVol = _volume;
    for (int i = 1; i <= steps; i++) {
      final v = startVol * (1 - i / steps);
      _player.setVolume(v.clamp(0.0, 1.0));
      await Future.delayed(stepDur);
    }
    await _player.stop();
    _player.setVolume(startVol);
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B263B),
        title: const Text(
          "เสียงช่วยหลับนอน",
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined, color: Colors.white),
            tooltip: 'หยุดทั้งหมด',
            onPressed: () {
              _sleepTimer?.cancel();
              _sleepTimerDuration = null;
              _remainingTimeText = "";
              _player.stop();
              setState(() => _currentlyPlaying = null);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Volume
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.volume_down, color: Colors.white70),
                Expanded(
                  child: Slider(
                    activeColor: Colors.cyanAccent,
                    value: _volume,
                    onChanged: (v) {
                      setState(() => _volume = v);
                      _player.setVolume(v);
                    },
                  ),
                ),
                const Icon(Icons.volume_up, color: Colors.white70),
              ],
            ),
          ),

          // List
          Expanded(
            child: ListView.separated(
              itemCount: _sounds.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemBuilder: (context, i) {
                final sound = _sounds[i];
                final isPlaying = _currentlyPlaying == sound.file;

                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2A38),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 4,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    leading: CircleAvatar(
                      backgroundColor: Colors.tealAccent.shade700,
                      child: Text(
                        sound.title.characters.first,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      sound.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      sound.file.split('/').last,
                      style: const TextStyle(color: Colors.white54),
                    ),
                    trailing: IconButton(
                      icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle_fill),
                      iconSize: 32,
                      color: isPlaying ? Colors.cyanAccent : Colors.white70,
                      onPressed: () => _showPlayerModal(sound),
                    ),
                    onTap: () => _showPlayerModal(sound),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundItem {
  final String title;
  final String file;
  const _SoundItem({required this.title, required this.file});
}
