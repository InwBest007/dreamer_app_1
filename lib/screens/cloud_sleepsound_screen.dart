import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final _firestore = FirebaseFirestore.instance;
  final _userId = FirebaseAuth.instance.currentUser?.uid;

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
  }

  @override
  void dispose() {
    _player.dispose();
    _sleepTimer?.cancel();
    _uiTimer?.cancel();
    super.dispose();
  }

  // ======================== LOAD SOUND ===========================
  Future<void> _fetchSounds() async {
    try {
      final ref = _storage.ref("sleep_sounds");
      final listResult = await ref.listAll();
      final user = FirebaseAuth.instance.currentUser;
      final favRef = _firestore.collection('favorites').doc(user?.uid).collection('songs');
      final favSnapshot = await favRef.get();
      final favoriteUrls = favSnapshot.docs.map((d) => d.id).toSet();

      final allItems = <_SoundItem>[];
      for (final item in listResult.items) {
        if (_isAudio(item.name)) {
          final url = await item.getDownloadURL();
          final category = _guessCategory(item.name);
          allItems.add(
            _SoundItem(
              title: _formatName(item.name),
              category: category,
              url: url,
              isFavorite: favoriteUrls.contains(url),
            ),
          );
        }
      }

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('โหลดเสียงล้มเหลว: $e')));
    }
  }

  bool _isAudio(String name) => name.toLowerCase().endsWith('.mp3');
  String _formatName(String file) => file.split('.').first.replaceAll('_', ' ');
  String _guessCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('rain')) return 'เสียงฝน 🌧';
    if (lower.contains('bird')) return 'เสียงนก 🐦';
    if (lower.contains('forest')) return 'เสียงป่า 🌲';
    if (lower.contains('water')) return 'เสียงน้ำ 💧';
    return 'เสียงอื่น ๆ 🌙';
  }

  // ======================== DOWNLOAD ===========================
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ดาวน์โหลดเสร็จแล้ว: $title')));
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ ดาวน์โหลดล้มเหลว: $e')));
    }
  }

  // ======================== PLAYER ===========================
  Future<void> _play(String url, String title) async {
    final localPath = await _getLocalFilePath(title);
    final useLocal = await File(localPath).exists();

    if (_currentlyPlaying == url && _player.playing) {
      await _player.pause();
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เล่นเสียงไม่ได้: $e')));
    }
  }

  // ไว้เก็บเพลงที่ชอบ 
  void _toggleFavorite(_SoundItem sound) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final favRef = _firestore
      .collection('favorites')
      .doc(user.uid)
      .collection('songs')
      .doc(sound.title); // ✅ ใช้ title แทน url

  if (sound.isFavorite) {
    await favRef.delete();
  } else {
    await favRef.set({
      'title': sound.title,
      'url': sound.url,
      'category': sound.category,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  setState(() {
    sound.isFavorite = !sound.isFavorite;
  });
}

  
  void _startSleepTimer(Duration duration) {
    _sleepDeadline = DateTime.now().add(duration);
    _sleepTimer?.cancel();
    _sleepTimer = Timer(duration, () async {
      await _player.stop();
      _cancelSleepTimer();
      setState(() => _currentlyPlaying = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🕒 ครบเวลา หยุดเสียงอัตโนมัติ')));
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
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _uiTimer?.cancel();
    setState(() {
      _sleepDeadline = null;
      _remainingText = '';
    });
  }

  void _showSleepTimerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF303F9F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          const Text('⏱ ตั้งเวลาในการเล่น', style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 10),
          for (final min in [15, 30, 60, 90])
            ListTile(
              title: Text('$min นาที', style: const TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                if (_player.playing) {
                  _startSleepTimer(Duration(minutes: min));
                } else {
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ======================== UI ===========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF1FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B5BE0),
        title: const Text('เสียงช่วยนอนหลับ 🌙', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          if (_remainingText.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text('⏱ $_remainingText', style: const TextStyle(color: Colors.white70)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
            tooltip: 'ดูเพลงโปรด',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoriteSleepsoundScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.timer, color: Colors.white),
            onPressed: _showSleepTimerDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF5B5BE0), Color(0xFF9FA8DA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _groupedSounds.entries.map((entry) {
                  final category = entry.key;
                  final sounds = entry.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
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
                            gradient: LinearGradient(
                              colors: isPlaying
                                  ? [Colors.cyanAccent.withOpacity(0.3), Colors.blueAccent.withOpacity(0.3)]
                                  : [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: const Offset(2, 3),
                              ),
                            ],
                          ),
                          child: ListTile(
                            title: Text(
                              s.title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    s.isFavorite ? Icons.favorite : Icons.favorite_border,
                                    color: s.isFavorite ? Colors.redAccent : Colors.white70,
                                  ),
                                  onPressed: () => _toggleFavorite(s),
                                ),
                                IconButton(
                                  icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle_fill),
                                  iconSize: 32,
                                  color: isPlaying ? Colors.cyanAccent : Colors.white70,
                                  onPressed: () => _play(s.url, s.title),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.download_for_offline, color: Colors.white70),
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
            ),
    );
  }
}

class _SoundItem {
  final String title;
  final String url;
  final String category;
  bool isFavorite;
  _SoundItem({required this.title, required this.url, required this.category, this.isFavorite = false});
}
