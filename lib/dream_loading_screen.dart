// dream_loading_screen.dart
import 'package:flutter/material.dart';

class DreamLoadingScreen extends StatefulWidget {
  final Future<Map<String, dynamic>> Function() processDream; // ฟังก์ชันประมวลผล
  const DreamLoadingScreen({super.key, required this.processDream});

  @override
  State<DreamLoadingScreen> createState() => _DreamLoadingScreenState();
}

class _DreamLoadingScreenState extends State<DreamLoadingScreen> {
  double progress = 0.0;
  String statusText = "กำลังประมวลผลความฝันของคุณ...";

  @override
  void initState() {
    super.initState();
    _simulateProgress();
    _processDream();
  }

  // จำลองแถบโหลดไหลขึ้นทีละนิด (ระหว่างรอผลจริง)
  void _simulateProgress() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return false;
      setState(() {
        if (progress < 0.9) {
          progress += 0.05;
        }
      });
      return progress < 0.9;
    });
  }

  // เรียกฟังก์ชันประมวลผลจริง
  Future<void> _processDream() async {
    try {
      final result = await widget.processDream();
      if (!mounted) return;

      setState(() {
        progress = 1.0;
        statusText = "ประมวลผลเสร็จสิ้น ✨";
      });

      await Future.delayed(const Duration(seconds: 1));

      // ไปหน้าผลลัพธ์
      Navigator.pushReplacementNamed(
        context,
        '/result',
        arguments: result,
      );
    } catch (e) {
      setState(() {
        statusText = "เกิดข้อผิดพลาด: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 8),
            ],
          ),
          width: 300,
          height: 200,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  )),
              const SizedBox(height: 24),

              // ใช้ ClipRRect เพื่อให้ LinearProgressIndicator มุมโค้ง
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.deepPurple.shade100,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                ),
              ),

              const SizedBox(height: 16),
              Text("${(progress * 100).toInt()}%",
                  style: const TextStyle(fontSize: 14, color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}
