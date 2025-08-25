import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dream_result_screen.dart';

class DreamInputScreen extends StatefulWidget {
  const DreamInputScreen({super.key});

  @override
  State<DreamInputScreen> createState() => _DreamInputScreenState();
}

class _DreamInputScreenState extends State<DreamInputScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();

  String? selectedType;
  String? selectedEmotion;
  String selectedPrediction = 'AI';

  final List<String> dreamTypes = [
    'Normal dream (ความฝันปกติ)',
    'Nightmare (ฝันร้าย)',
    'False Awakening Dream (ฝันว่าตื่น)',
    'Lucid Dream (ความฝันที่รู้ตัวว่ากำลังฝัน)',
  ];
  final List<String> emotions = [
    'ความกลัว', 'ความเศร้า', 'ความตื่นเต้น',
    'ความโกรธ', 'เพลิดเพลิน', 'ความประหลาดใจ'
  ];

  Future<void> _handleSubmit() async {
  String dreamText = _content.text.trim();
  String titleText = _title.text.trim();

  if (dreamText.isEmpty || titleText.isEmpty) {
    _showDialog('รบกวนกรอกข้อมูลความฝันให้ครบถ้วน');
    return;
  }

  try {
    // บันทึกความฝันลง Firestore ก่อน
    await FirebaseFirestore.instance.collection("dreamEntries").add({
      "title": titleText,
      "content": dreamText,
      "type": selectedType ?? "ไม่ระบุ",
      "emotion": selectedEmotion ?? "ไม่ระบุ",
      "date": DateTime.now(),
    });

    // ล้างค่า input
    _title.clear();
    _content.clear();

    // แจ้งผู้ใช้
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("บันทึกความฝันเรียบร้อย ✨")),
    );

    // เรียก FastAPI
    final response = await http.post(
      Uri.parse("http://10.0.2.2:8000/analyze"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"dream": dreamText}),
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      List matchedKeywords = result['matched_keywords'];

      if (matchedKeywords.isEmpty) {
        _showDialog("ไม่เจอคำสำคัญในความฝัน");
        return;
      }

      // ใช้ keyword ไปค้น Firestore อีกครั้ง
      final snapshot = await FirebaseFirestore.instance
          .collection("dreamInt1")
          .where("keyword", isEqualTo: matchedKeywords.first)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final interpretation = data['interpretation'] ?? 'ไม่พบคำทำนาย';
        final luckNumber = data['luckynumber'] ?? '-';
        final imageUrl = data['imageUrl'] ?? 'https://placehold.co/300x300';

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DreamResultScreen(
              dreamTitle: titleText,
              dreamStory: dreamText,
              dreamImageUrl: imageUrl,
              dreamInterpretation: interpretation,
              luckyNumber: luckNumber,
            ),
          ),
        );
      } else {
        _showDialog("ไม่พบคำทำนายสำหรับ '${matchedKeywords.first}'");
      }
    } else {
      _showDialog("API มีปัญหา: ${response.body}");
    }
  } catch (e) {
    _showDialog("ไม่สามารถประมวลผลได้: $e");
  }
}

  void _showDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("แจ้งเตือน"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ตกลง"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ModalRoute.of(context)!.settings.arguments as DateTime;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'บันทึกความฝัน ของวันที่ (${selectedDate.day}/${selectedDate.month}/${selectedDate.year})',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ชื่อเรื่องความฝัน'),
              TextField(controller: _title),
              const SizedBox(height: 12),
              const Text('เนื้อหาความฝัน'),
              TextField(controller: _content),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _handleSubmit,
                child: const Text("บันทึกความฝัน"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
