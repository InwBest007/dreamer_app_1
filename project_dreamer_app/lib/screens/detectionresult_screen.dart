import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DetectionResultScreen extends StatelessWidget {
  final DateTime sleepDate;

  const DetectionResultScreen({super.key, required this.sleepDate});

  String formatDate(DateTime date) {
    final formatter = DateFormat('EEEE ที่ d MMM yyyy', 'th_TH');
    return formatter.format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ผลการตรวจจับเสียง'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'วันที่นอน: ${formatDate(sleepDate)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text('สรุปเสียงที่บันทึกไว้', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('• ระยะเวลาการนอน: 23:00 - 07:00 น.'),
            const Text('• เสียงที่พบ: กรนเบา 4 ครั้ง, กรนดัง 2 ครั้ง'),
            const Text('• คะแนนความผิดปกติ: 22/100'),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // ไว้เชื่อมไปยังเสียงที่บันทึกไว้ หรือแสดงกราฟ
                },
                child: const Text('ดูกราฟเสียง'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
