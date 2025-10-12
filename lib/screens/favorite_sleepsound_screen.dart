import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';

class FavoriteSleepsoundScreen extends StatefulWidget {
  const FavoriteSleepsoundScreen({super.key});

  @override
  State<FavoriteSleepsoundScreen> createState() => _FavoriteSleepsoundScreenState();
}

class _FavoriteSleepsoundScreenState extends State<FavoriteSleepsoundScreen> {
  final _user = FirebaseAuth.instance.currentUser;
  final _player = AudioPlayer();

  String? _currentlyPlaying;
  bool _loading = true;
  List<_SoundItem> _favoriteSongs = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _player.setLoopMode(LoopMode.one);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    if (_user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('favorites')
          .doc(_user.uid)
          .collection('songs')
          .orderBy('timestamp', descending: true)
          .get();

      final songs = snapshot.docs.map((doc) {
        final data = doc.data();
        return _SoundItem(
          title: data['title'] ?? '',
          url: data['url'] ?? '',
          category: data['category'] ?? '',
        );
      }).toList();

      setState(() {
        _favoriteSongs = songs;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดเพลงโปรดล้มเหลว: $e')),
      );
    }
  }

  Future<void> _play(String url) async {
    if (_currentlyPlaying == url && _player.playing) {
      await _player.pause();
      setState(() {});
      return;
    }

    try {
      await _player.setUrl(url);
      await _player.play();
      setState(() => _currentlyPlaying = url);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เล่นเพลงไม่ได้: $e')),
      );
    }
  }

  Future<void> _removeFavorite(_SoundItem item) async {
    if (_user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('favorites')
        .doc(_user.uid)
        .collection('songs')
        .doc(item.title);

    try {
      await docRef.delete();
      setState(() {
        _favoriteSongs.remove(item);
        if (_currentlyPlaying == item.url) {
          _player.stop();
          _currentlyPlaying = null;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ลบ "${item.title}" ออกจากรายการโปรด')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ลบไม่สำเร็จ: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF1FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B5BE0),
        title: const Text(
          'เพลงโปรดของฉัน ❤️',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _favoriteSongs.isEmpty
              ? _buildEmptyState()
              : Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF5B5BE0), Color(0xFF9FA8DA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _favoriteSongs.length,
                    itemBuilder: (context, index) {
                      final song = _favoriteSongs[index];
                      final isPlaying = _currentlyPlaying == song.url && _player.playing;

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
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(2, 3),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          title: Text(
                            song.title,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Text(
                            song.category,
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () => _removeFavorite(song),
                              ),
                              IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.pause_circle : Icons.play_circle_fill,
                                  color: isPlaying ? Colors.cyanAccent : Colors.white70,
                                  size: 32,
                                ),
                                onPressed: () => _play(song.url),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5B5BE0), Color(0xFF9FA8DA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, color: Colors.white70, size: 80),
            SizedBox(height: 16),
            Text(
              'ยังไม่มีเพลงโปรดเลยนะ~',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              'ลองกด ❤️ ที่หน้าเสียงช่วยนอนหลับดูสิ!',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoundItem {
  final String title;
  final String url;
  final String category;

  _SoundItem({
    required this.title,
    required this.url,
    required this.category,
  });
}
