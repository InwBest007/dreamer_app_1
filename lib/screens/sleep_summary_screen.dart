import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:intl/intl.dart';

class SummarySnoreLabStyle extends StatefulWidget {
  final String sessionId;
  const SummarySnoreLabStyle({super.key, required this.sessionId});

  @override
  State<SummarySnoreLabStyle> createState() => _SummarySnoreLabStyleState();
}

class _SummarySnoreLabStyleState extends State<SummarySnoreLabStyle> {
  Map<String, dynamic>? summary;
  bool isLoading = true;
  final _player = AudioPlayer();
  StreamSubscription<DocumentSnapshot>? _summarySub;

  @override
  void initState() {
    super.initState();
    _loadSummary(); 
  }

  @override
  void dispose() {
    _player.dispose();
    _summarySub?.cancel();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    _summarySub = FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.sessionId)
        .snapshots() 
        .listen((doc) {
          if (!doc.exists) return;

          final data = doc.data()!;
          final sessionType = (data['type'] as String? ?? 'pending').toLowerCase();
          final hasSummary = data.containsKey('summary');

          // ✅ เงื่อนไขการแสดงผล: เมื่อ analyzed เป็น true และมี field 'summary'
          if (hasSummary && (data['analyzed'] == true || sessionType == 'done')) {
            setState(() {
              summary = data['summary'] as Map<String, dynamic>?;
              isLoading = false;
              _summarySub?.cancel(); // หยุดฟังเมื่อโหลดสำเร็จแล้ว
            });
            debugPrint('✅ Summary Loaded and Ready');
          } else {
            // ยังไม่พร้อม, ยังคงแสดง Loading
            setState(() {
              isLoading = true;
            });
            debugPrint('⏳ Waiting for analysis summary...');
          }
        }, onError: (error) {
          debugPrint('🚨 Error listening to session summary: $error');
          setState(() {
            isLoading = false;
            summary = null; 
          });
        });
  }

  // 1. ปรับปรุง: เพิ่ม 'snoring_or_bruxism' และจัดการประเภทที่ไม่รู้จักให้เป็นสีเทา
  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'snoring':
      case 'snoring_or_bruxism': // รองรับชื่อเดิม
      case 'teeth_grinding':
        return Colors.red;
      case 'speech':
      case 'talk':
        return Colors.orange;
      case 'cough':
        return Colors.yellow.shade700;
      case 'scream':
        return Colors.purple;
      case 'music':
      case 'singing':
        return Colors.blue;
      case 'error_on_analyze':
      case 'unknown':
      default:
        return Colors.grey.shade400; // ให้สีเทาอ่อนสำหรับประเภทที่ไม่รู้จัก/มีปัญหา
    }
  }

  // 2. ปรับปรุง: ให้รับ DateTime และ Timestamp ได้
  String fmtTime(dynamic t) {
    if (t == null) return '-';
    DateTime date;
    if (t is Timestamp) {
      date = t.toDate();
    } else if (t is DateTime) {
      date = t;
    } else {
      return '-';
    }
    return DateFormat('HH:mm:ss').format(date);
  }

  Future<void> _play(String url) async {
    try {
      if (_player.playing) {
        await _player.stop();
      }
      // 💡 อาจต้องใช้ .setAudioSource(AudioSource.uri(Uri.parse(url))) แทน setUrl
      // แต่ setUrl มักจะใช้ได้ถ้าเป็น URL ทั่วไป
      await _player.setUrl(url); 
      await _player.play();
    } catch (e) {
      debugPrint("❌ Error playing audio: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('สรุปผลการนอนหลับ')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('กำลังวิเคราะห์ข้อมูล... กรุณารอสักครู่', style: TextStyle(fontSize: 16)),
              Text('ขั้นตอนนี้ใช้เวลานานขึ้นอยู่กับจำนวนคลิป', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (summary == null || summary!['meta'] == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('สรุปผลการนอนหลับ')),
        body: const Center(
          child: Text('ไม่พบข้อมูลสรุปสำหรับ Session นี้ หรือเกิดข้อผิดพลาดในการโหลด', style: TextStyle(color: Colors.red)),
        ),
      );
    }

    final meta = summary!['meta'] as Map<String, dynamic>;
    final types = summary!['types'] as Map<String, dynamic>;
    final timeline = summary!['timeline'] as List<dynamic>;

    // แปลง Timestamp ใน Timeline ที่เป็น DateTime กลับเป็น Timestamp (ถ้าจำเป็น)
    for (var item in timeline) {
        if (item['timestamp'] is Timestamp) {
             item['timestamp'] = (item['timestamp'] as Timestamp).toDate(); // ให้เป็น DateTime ก่อนเรียง
        }
    }
    
    // เรียง Timeline ตามเวลา
    timeline.sort((a, b) => (a['timestamp'] as DateTime).compareTo(b['timestamp'] as DateTime));
    
    // 💡 ฟังก์ชันที่ใช้ในการจัดรูปแบบชื่อประเภทเสียง
    String formatType(String t) {
      if (t == 'snoring_or_bruxism') return 'กรน/กัดฟัน';
      if (t == 'snoring') return 'กรน';
      if (t == 'speech' || t == 'talk') return 'พูดคุย';
      if (t == 'cough') return 'ไอ';
      if (t == 'scream') return 'กรีดร้อง';
      if (t == 'music' || t == 'singing') return 'ดนตรี/ร้องเพลง';
      if (t == 'error_on_analyze') return 'วิเคราะห์ล้มเหลว';
      return t.toUpperCase();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('สรุปผลการนอนหลับ')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ส่วนแสดงผลลัพธ์หลัก
            Text(
              "📊 สรุปโดยรวม (${meta['totalClips']} คลิป)",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('ความดังสูงสุด: **${(meta['peakMaxDecibel'] ?? 0).toStringAsFixed(1)} dB**', style: const TextStyle(fontSize: 16)),
            Text('ความดังเฉลี่ย: **${(meta['avgMaxDecibel'] ?? 0).toStringAsFixed(1)} dB**', style: const TextStyle(fontSize: 16)),
            Text('ระยะเวลารวม: **${meta['totalDuration']} วินาที**', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),

            // ส่วนสรุปประเภทเสียง
            Text(
              "🔊 ประเภทเสียงที่ตรวจพบ:",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (types.isEmpty)
              const Text('ไม่พบเสียงใดๆ ที่น่าสนใจ (ไม่รวมเสียงพื้นหลัง)'),
            // 3. ปรับปรุง: ใช้ formatType เพื่อแสดงชื่อประเภทเสียงที่เป็นมิตร
            ...types.keys.map((t) {
              final data = types[t] as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  "• ${formatType(t)} : ${data['count']} ครั้ง (${data['duration']} วิ)",
                  style: TextStyle(color: _typeColor(t)),
                ),
              );
            }).toList(),

            const Divider(height: 32),
            Text(
              "🎧 คลิปเสียงที่ถูกบันทึก:",
              style: Theme.of(context).textTheme.titleLarge,
            ),

            Expanded(
              child: ListView.builder(
                itemCount: timeline.length,
                itemBuilder: (ctx, i) {
                  var item = timeline[i];
                  final type = (item['type'] ?? "unknown").toLowerCase();
                  final url = item['url'] as String? ?? '';
                  
                  return Card(
                    elevation: 0.5,
                    child: ListTile(
                      // 4. ปรับปรุง: ใช้ formatType
                      leading: Icon(Icons.circle, color: _typeColor(type)),
                      title: Text("${formatType(type)} (${item['duration']} วิ)"),
                      // 5. ปรับปรุง: fmtTime รองรับ DateTime แล้ว
                      subtitle: Text(
                        "เวลา: ${fmtTime(item['timestamp'])}\n" 
                        "ความดังสูงสุด: ${(item['maxDecibel'] ?? 0).toStringAsFixed(1)} dB",
                      ),
                      // 6. ตรวจสอบ url ว่าว่างเปล่าหรือไม่
                      trailing: url.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.play_arrow),
                              onPressed: () => _play(url),
                            )
                          : const Icon(Icons.cloud_off, color: Colors.grey),
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