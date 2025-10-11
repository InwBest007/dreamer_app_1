import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:project_dreamer_app/screens/sleep_detail_screen.dart';

class DetectionResultScreen extends StatelessWidget {
  const DetectionResultScreen({super.key});

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    final date = ts.toDate();
    return DateFormat('EEEE ที่ d MMM yyyy', 'th_TH').format(date);
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '-';
    final date = ts.toDate();
    return DateFormat('HH:mm', 'th_TH').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('ประวัติการนอนย้อนหลัง'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sessions')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'ยังไม่มีข้อมูลการนอนบันทึกไว้',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final sessions = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final doc = sessions[index];
              final data = doc.data() as Map<String, dynamic>;

              final ts = data['timestamp'] as Timestamp?;
              final type = (data['type'] ?? 'pending').toString();
              final avgDb = (data['summary']?['meta']?['avgMaxDecibel'] ?? 0)
                  .toDouble();
              final peakDb = (data['summary']?['meta']?['peakMaxDecibel'] ?? 0)
                  .toDouble();
              final totalClips = (data['summary']?['meta']?['totalClips'] ?? 0)
                  .toInt();

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: _getStatusColor(type),
                    child: const Icon(
                      Icons.nightlight_round,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  title: Text(
                    _formatDate(ts),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('เวลาเริ่ม: ${_formatTime(ts)} น.'),
                        Text(
                          'ระดับเสียงเฉลี่ย: ${avgDb.toStringAsFixed(1)} dB',
                        ),
                        Text('ความดังสูงสุด: ${peakDb.toStringAsFixed(1)} dB'),
                        Text('คลิปเสียงทั้งหมด: $totalClips'),
                      ],
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.deepPurple,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SleepDetailScreen(sessionId: doc.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String type) {
    switch (type.toLowerCase()) {
      case 'done':
        return Colors.teal;
      case 'pending':
        return Colors.grey;
      case 'error':
        return Colors.redAccent;
      default:
        return Colors.deepPurple;
    }
  }
}
