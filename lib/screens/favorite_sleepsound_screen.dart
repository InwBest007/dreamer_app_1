import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';

class FavoriteSleepsoundScreen extends StatefulWidget{
  const FavoriteSleepsoundScreen({super.key});

  @override
  State<FavoriteSleepsoundScreen> createState() => _FavoriteSleepsoundScreenState();
}

class _FavoriteSleepsoundScreenState extends State<FavoriteSleepsoundScreen>{
  final _user = FirebaseAuth.instance.currentUser;
  final _player = AudioPlayer();

  String? _currentlyPlaying;
  bool _loading = true;
  List<_SoundItem> _favoriteSongs = [];

  @override
  void initState(){
    super.initState();
    _loadFavorites();
    _player.setLoopMode(LoopMode.one);
  }

  @override
  void dispose(){
    _player.dispose();
    super.dispose();
  }
  Future<void> _loadFavorites() async {
    if(_user == null) return;

    try{
      final snapshot = await FirebaseFirestore.instance.collection('favorites').doc(_user.uid).collection('songs').orderBy('timestamp', descending: true).get();
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
      if(!mounted) return;
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
      if (!mounted) return;
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
        .doc(item.title); // ใช้ title เป็น document ID

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ลบไม่สำเร็จ: $e')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B263B),
        title: const Text('เพลงโปรด ❤️', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _favoriteSongs.isEmpty
              ? const Center(
                  child: Text('ยังไม่มีเพลงโปรดเลยนะ~', style: TextStyle(color: Colors.white70)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _favoriteSongs.length,
                  itemBuilder: (context, index) {
                    final song = _favoriteSongs[index];
                    final isPlaying = _currentlyPlaying == song.url && _player.playing;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2A38),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(song.title, style: const TextStyle(color: Colors.white)),
                        subtitle: Text(song.category, style: const TextStyle(color: Colors.white54)),
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
                                size: 30,
                              ),
                              onPressed: () => _play(song.url),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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