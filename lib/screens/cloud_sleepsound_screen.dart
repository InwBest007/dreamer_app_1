import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'favorite_sleepsound_screen.dart';

class CloudSleepSoundScreen extends StatefulWidget {
  const CloudSleepSoundScreen({super.key});

  @override
  State<CloudSleepSoundScreen> createState() => _CloudSleepSoundScreenState();
}

class _CloudSleepSoundScreenState extends State<CloudSleepSoundScreen> {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AudioPlayer _player = AudioPlayer();
  final _userId = FirebaseAuth.instance.currentUser?.uid;
  final _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  Map<String, List<_SoundItem>> _groupedSounds = {};
  String? _currentlyPlaying;

  Timer? _sleepTimer;
  Duration? _sleepDuration;
  DateTime? _sleepDeadline;
  String _remainingText = '';

  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    _fetchSounds();

    _player.setLoopMode(LoopMode.one);
    _player.playerStateStream.listen((s) {
      print('[🎧] state=${s.processingState}, playing=${s.playing}');
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _sleepTimer?.cancel();
    _uiTimer?.cancel();
    super.dispose();
  }

 Future<void> _fetchSounds() async {
  try {
    final ref = _storage.ref("sleep_sounds");
    final listResult = await ref.listAll();
    final allItems = <_SoundItem>[];

    // ✅ 1. โหลดรายการ Favorite จาก Firestore
    final user = FirebaseAuth.instance.currentUser;
    final favRef = FirebaseFirestore.instance
        .collection('favorites')
        .doc(user?.uid)
        .collection('songs');

    final favSnapshot = await favRef.get();
    final favoriteUrls = favSnapshot.docs.map((doc) => doc.id).toSet();

    // ✅ 2. โหลดเสียงทั้งหมดจาก Firebase Storage
    for (final item in listResult.items) {
      if (_isAudio(item.name)) {
        final url = await item.getDownloadURL();
        final category = _guessCategory(item.name);
        final isFavorite = favoriteUrls.contains(url); // เช็คว่า URL นี้ถูกกด Favorite หรือยัง

        allItems.add(
          _SoundItem(
            title: _formatName(item.name),
            category: category,
            url: url,
            isFavorite: isFavorite,
          ),
        );
      }
    }

    // ✅ 3. จัดกลุ่มตามหมวดหมู่
    final Map<String, List<_SoundItem>> grouped = {};
    for (var item in allItems) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    setState(() {
      _groupedSounds = grouped;
      _loading = false;
    });
  } catch (e) {
    setState(() => _loading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('โหลดเสียงล้มเหลว: $e')),
    );
  }
}


  bool _isAudio(String name) => name.toLowerCase().endsWith('.mp3');

  String _formatName(String fileName) {
    final name = fileName.split('.').first.replaceAll(RegExp(r'[_\-]+'), ' ');
    return name.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }

  String _guessCategory(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.contains('rain')) return 'เสียงฝน 🌧';
    if (lower.contains('bird')) return 'เสียงนก 🐦';
    if (lower.contains('forest')) return 'เสียงธรรมชาติ 🌲';
    if (lower.contains('water') || lower.contains('stream')) return 'เสียงน้ำไหล 💧';
    return 'เสียงอื่น ๆ 🌙';
  }
  Future<String> _getLocalFilePath(String title) async {
  final dir = await getApplicationDocumentsDirectory();
  return '${dir.path}/$title.mp3';
}

Future<bool> _isDownloaded(String title) async {
  final path = await _getLocalFilePath(title);
  return File(path).exists();
}

Future<void> _downloadFile(String url, String title) async {
  final path = await _getLocalFilePath(title);
  try {
    await Dio().download(url, path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ดาวน์โหลดเสร็จแล้ว: $title')));
    setState(() {}); // Refresh ปุ่มดาวน์โหลด
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ ดาวน์โหลดล้มเหลว: $e')));
  }
}

  Future<void> _play(String url, String title) async {
  final localPath = await _getLocalFilePath(title);
  final useLocal = await File(localPath).exists();

  if (_currentlyPlaying == url) {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    setState(() {});
    return;
  }

  await _player.stop();
  _cancelSleepTimer();

  try {
    if (useLocal) {
      await _player.setFilePath(localPath);
    } else {
      await _player.setUrl(url);
    }
    await _player.play();
    setState(() => _currentlyPlaying = url);

    if (_sleepDuration != null) {
      _startSleepTimer(_sleepDuration!);
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('เล่นเสียงไม่ได้: $e')),
    );
  }
}

  void _toggleFavorite(_SoundItem sound) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final favRef = FirebaseFirestore.instance
      .collection('favorites')
      .doc(user.uid)
      .collection('songs')
      .doc(sound.title); // ใช้ title เป็น id เอกสาร

  if (sound.isFavorite) {
    await favRef.delete(); // ❌ ลบออกจาก favorite
  } else {
    await favRef.set({
      'title': sound.title,
      'url': sound.url,
      'category': sound.category,
      'timestamp': FieldValue.serverTimestamp(),
    }); // ✅ เพิ่มเข้า favorite
  }

  setState(() {
    sound.isFavorite = !sound.isFavorite;
  });
}


  void _startSleepTimer(Duration duration) {
    _sleepDeadline = DateTime.now().add(duration);
    _sleepDuration = duration;

    _sleepTimer?.cancel();
    _sleepTimer = Timer(duration, () async {
      await _player.stop();
      setState(() {
        _currentlyPlaying = null;
        _remainingText = '';
        _sleepDuration = null;
        _sleepDeadline = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⏱ ครบเวลา หยุดเสียงอัตโนมัติ')),
      );
    });

    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sleepDeadline == null) return;
      final remaining = _sleepDeadline!.difference(DateTime.now());
      if (remaining.isNegative) {
        _remainingText = '';
        _uiTimer?.cancel();
        return;
      }
      setState(() {
        _remainingText = '${remaining.inMinutes} นาที ${remaining.inSeconds % 60} วินาที';
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('⏱ จะหยุดเสียงใน ${duration.inMinutes} นาที')),
    );
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _uiTimer?.cancel();
    setState(() {
      _sleepDuration = null;
      _sleepDeadline = null;
      _remainingText = '';
    });
  }

  void _showSleepTimerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2A38),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('ตั้งเวลาในการเล่นเพลง', style: TextStyle(color: Colors.white)),
          ),
          for (final min in [15, 30, 60, 90, 120])
            ListTile(
              title: Text('$min นาที', style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                if (_player.playing) {
                  _startSleepTimer(Duration(minutes: min));
                } else {
                  _sleepDuration = Duration(minutes: min);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('⏱ จะเริ่มนับเมื่อเริ่มเล่นเสียง')),
                  );
                }
              },
            ),
          ListTile(
            title: const Text('ยกเลิกการตั้งเวลา', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(context);
              _cancelSleepTimer();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('❌ ยกเลิก Sleep Timer แล้ว')),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B263B),
        title: const Text('เสียงช่วยนอนหลับ', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_remainingText.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text('⏱ $_remainingText', style: const TextStyle(color: Colors.greenAccent)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
            tooltip: 'ดูเพลงโปรด',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoriteSleepsoundScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.timer, color: Colors.white),
            onPressed: _showSleepTimerDialog,
          ),
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined, color: Colors.white),
            onPressed: () async {
              await _player.stop();
              _cancelSleepTimer();
              setState(() => _currentlyPlaying = null);
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _groupedSounds.entries.map((entry) {
                final category = entry.key;
                final sounds = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...sounds.map((s) {
                      final isPlaying = _currentlyPlaying == s.url && _player.playing;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2A38),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: Text(s.title, style: const TextStyle(color: Colors.white)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ❤️ ปุ่ม Favorite
                              IconButton(
                                icon: Icon(
                                  s.isFavorite ? Icons.favorite : Icons.favorite_border,
                                  color: s.isFavorite ? Colors.redAccent : Colors.white70,
                                ),
                                onPressed: () => _toggleFavorite(s),
                              ),

                              // ▶️ ปุ่มเล่นเสียง
                              IconButton(
                                icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle_fill),
                                iconSize: 32,
                                color: isPlaying ? Colors.cyanAccent : Colors.white70,
                                onPressed: () => _play(s.url, s.title),
                              ),

                              IconButton(
                                icon: const Icon(Icons.download_for_offline),
                                color: Colors.white70,
                                onPressed: () async {
                                  final isDownloaded = await _isDownloaded(s.title);
                                  if (isDownloaded) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('📂 โหลดไว้แล้ว: ${s.title}')),
                                    );
                                  } else {
                                    await _downloadFile(s.url, s.title);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              }).toList(),
            ),
    );
  }
}

class _SoundItem {
  final String title;
  final String url;
  final String category;
  bool isFavorite; //ไว้บันทึกเพลงโปรด

  _SoundItem({required this.title, required this.url, required this.category, this.isFavorite = false,});

  //String get fileName => Uri.parse(url).pathSegments.last;
}
