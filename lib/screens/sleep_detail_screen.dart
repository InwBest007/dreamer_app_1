import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

class SleepDetailScreen extends StatefulWidget {
  final String sessionId;

  const SleepDetailScreen({super.key, required this.sessionId});

  @override
  State<SleepDetailScreen> createState() => _SleepDetailScreenState();
}

class _SleepDetailScreenState extends State<SleepDetailScreen> {
  Map<String, dynamic>? summary;
  List<QueryDocumentSnapshot> soundClips = [];
  bool isLoading = true;
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadSessionData();
  }

  Future<void> _loadSessionData() async {
    try {
      final sessionDoc = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .get();

      final clipsQuery = await FirebaseFirestore.instance
          .collection('sound_data')
          .where('sessionId', isEqualTo: widget.sessionId)
          .orderBy('timestamp', descending: false)
          .get();

      setState(() {
        summary = sessionDoc.data();
        soundClips = clipsQuery.docs;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("⚠️ Error loading data: $e");
      setState(() => isLoading = false);
    }
  }

  String _fmtTime(dynamic ts) {
    try {
      if (ts == null) return "-";
      if (ts is Timestamp) {
        return DateFormat('HH:mm:ss').format(ts.toDate());
      } else if (ts is DateTime) {
        return DateFormat('HH:mm:ss').format(ts);
      }
      return "-";
    } catch (_) {
      return "-";
    }
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case "snoring":
      case "snoring_or_bruxism":
        return Colors.orange;
      case "bruxism":
        return Colors.purple;
      case "speech":
        return Colors.blue;
      case "other":
      case "other_vocalization":
        return Colors.grey;
      default:
        return Colors.teal;
    }
  }

  Future<void> _playSound(String url) async {
    try {
      await _player.setUrl(url);
      await _player.play();
    } catch (e) {
      debugPrint("🎧 Error playing sound: $e");
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("รายละเอียดการนอน")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (summary == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("รายละเอียดการนอน")),
        body: const Center(child: Text("ไม่พบข้อมูลของเซสชันนี้")),
      );
    }

    final meta = summary?['summary']?['meta'] ?? {};
    final avgDb = (meta['avgMaxDecibel'] ?? 0).toDouble();
    final peakDb = (meta['peakMaxDecibel'] ?? 0).toDouble();
    final totalClips = (meta['totalClips'] ?? 0).toInt();
    final date = summary?['timestamp'] as Timestamp?;

    return Scaffold(
      appBar: AppBar(
        title: const Text("รายละเอียดการนอน"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 ส่วนสรุป
            Card(
              color: Colors.deepPurple.shade50,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "คืนวันที่ ${DateFormat('EEEE ที่ d MMM yyyy', 'th_TH').format(date!.toDate())}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text("ระดับเสียงเฉลี่ย: ${avgDb.toStringAsFixed(1)} dB"),
                    Text("ความดังสูงสุด: ${peakDb.toStringAsFixed(1)} dB"),
                    Text("คลิปเสียงทั้งหมด: $totalClips"),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),
            const Text(
              "🎧 รายการเสียงที่บันทึกได้",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: soundClips.isEmpty
                  ? const Center(
                      child: Text("ยังไม่มีคลิปเสียงในเซสชันนี้"),
                    )
                  : ListView.builder(
                      itemCount: soundClips.length,
                      itemBuilder: (context, index) {
                        final clip = soundClips[index].data() as Map<String, dynamic>;
                        final type = clip['type'] ?? 'unknown';
                        final time = _fmtTime(clip['timestamp']);
                        final duration = (clip['duration'] ?? 0).toString();
                        final url = clip['filePath'] ?? clip['url'];

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: Icon(Icons.circle, color: _typeColor(type)),
                            title: Text("$type (${duration}s)"),
                            subtitle: Text("เวลา: $time"),
                            trailing: IconButton(
                              icon: const Icon(Icons.play_arrow),
                              onPressed: () => _playSound(url),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
