import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dream_result_screen.dart';
//import 'dart:io';

class DreamInputScreen extends StatefulWidget {
  const DreamInputScreen({super.key});

  @override
  State<DreamInputScreen> createState() => _DreamInputScreenState();
}

class _DreamInputScreenState extends State<DreamInputScreen> {
  final TextEditingController _title = TextEditingController(); //เก็บชื่อเรื่องความฝัน
  final TextEditingController _content = TextEditingController(); //เก็บเนื้อหาความฝัน

  List<String> keywords = [];
  String? selectedType;
  String? selectedEmotion;
  String selectedPrediction = 'AI';

  final List<String> dreamTypes = [
    //'Recurring dream (ฝันที่คล้ายเรื่องจริง)',
    //'Epic dream (ฝันแบบเป็นเรื่องเป็นราว)',
    //'Healing dream (ฝันเกี่ยวกับสุขภาพกาย)',
    'Normal dream (ความฝันปกติ)',
    'Nightmare (ฝันร้าย)',
    'False Awakening Dream (ฝันว่าตื่น)',
    'Lucid Dream (ความฝันที่รู้ตัวว่ากำลังฝัน)',
  ];
  final List<String> emotions = ['ความกลัว', 'ความเศร้า', 'ความตื่นเต้น', 'ความโกรธ', 'เพลิดเพลิน', 'ความประหลาดใจ'];

  @override
  void initState() {
    super.initState();
    _loadKeywords();
  }

  Future<void> _loadKeywords() async { 
    try {
      final snapshot = await FirebaseFirestore.instance.collection("dreamInt1").get(); //ดึงข้อมูลจาก dreamInt1 ทั้งหมด
      final fetched = snapshot.docs.map((doc) => doc.data()['keyword']?.toString()).whereType<String>().toSet().toList(); //ทำการดึง keyword จาก snapshot ที่ดึงข้อมมาใน Firebase มาเก็บไว้
      setState(() {
        keywords = fetched;
      });
    } catch (e) {
      print("โหลดคีย์คำไม่สำเร็จ: $e");
    }
  }

  Future<void> _handleSubmit() async {
    String dreamText = _content.text.trim();
    String titleText = _title.text.trim();
    String? matchedKeyword;

    if(dreamText.isEmpty || titleText.isEmpty) { //หากผู้ใช้งานไม่ได้กรอกข้อมูลอย่างใดอย่างหนึ่ง
      _showDialog('รบกวนกรอกข้อมูลความฝันให้ครบถ้วน');
      return;
    }

    for (var keyword in keywords) { //วนลูปเช็ค เอาคำ keywords มาเช็คในประโยค หากเจอในประโยคก็จะหยุดและเก็บคำสำคัญไว้ใน matchedKeyword
      if (dreamText.contains(keyword)) {
        matchedKeyword = keyword;
        break;
      }
    }

    if (matchedKeyword == null) {
      _showDialog("ไม่เจอคำสำคัญในความฝัน");
      return;
    }

    try {
      //ทำการค้นหาคำสำคัญ และ ดึงคำทำนายมาเก็บไว้ 
      final snapshot = await FirebaseFirestore.instance.collection("dreamInt1").where("keyword", isEqualTo: matchedKeyword).limit(1).get(); 
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        //final titleFromDB = data['content'] ?? 'ไม่พบชื่อเรื่อง';
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
        _showDialog("ไม่พบคำทำนายสำหรับ '$matchedKeyword'");
      }
    } catch (e) {
      _showDialog("ไม่สามารถดึงข้อมูลมาได้: $e");
    }

  // ตัว Demo ในการบันทึกและทำนายความฝัน
  //   Navigator.push(
  //   context,
  //   MaterialPageRoute(
  //     builder: (_) => DreamResultScreen(
  //       dreamTitle: _title.text.trim().isNotEmpty
  //           ? _title.text.trim()
  //           : 'ฝันเห็นงูตัวใหญ่ในป่าใหญ่',
  //       dreamStory: _content.text.trim().isNotEmpty
  //           ? _content.text.trim()
  //           : 'เมื่อคืนฝันเห็นงูตัวใหญ่ในป่าดงดิบเขียวขะจีเลื้อยมาพันขาและจ้องหน้าก่อนจะเลื้อยหายไป...',
  //       dreamImageUrl: 'https://it24hrs.com/wp-content/uploads/2025/01/venom-serum-ai004.jpg', 
  //       dreamInterpretation:
  //           'การฝันเห็นงูบ่งบอกถึงโอกาสในการพบเนื้อคู่ หรือมีคนแอบชอบอยู่ใกล้ ๆ คุณในชีวิตจริง',
  //       luckyNumber: '22, 64, 09',
  //     ),
  //   ),
  // );
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
        centerTitle: true,
        leading: BackButton(color: Colors.deepPurple),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ชื่อเรื่องความฝัน', style: TextStyle(fontSize: 16)),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  hintText: 'พิมพ์ชื่อเรื่องความฝัน...',
                  filled: true,
                  fillColor: Color(0xFFF5F5FF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // const Text('ภาพความฝัน'),
              // Container(
              //   height: 150,
              //   padding: const EdgeInsets.all(12),
              //   decoration: BoxDecoration(
              //     color: const Color(0xFFF0F0FF),
              //     borderRadius: BorderRadius.circular(12),
              //   ),
              //   child: const Center(child: Text('ภาพจาก AI จะแสดงที่นี่..')),
              // ),
              // const SizedBox(height: 16),

              const Text('เนื้อหาความฝัน'),
              TextField(
                controller: _content,
                maxLength: null,
                decoration: const InputDecoration(
                  hintText: 'กรอกความฝันของคุณ...',
                  filled: true,
                  fillColor: Color(0xFFF5F5FF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: selectedType,
                items: dreamTypes
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                decoration: const InputDecoration(labelText: 'ประเภทความฝัน'),
                onChanged: (value) => setState(() => selectedType = value),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: selectedEmotion,
                items: emotions
                    .map(
                      (emo) => DropdownMenuItem(value: emo, child: Text(emo)),
                    )
                    .toList(),
                decoration: const InputDecoration(
                  labelText: 'ความรู้สึกในความฝัน',
                ),
                onChanged: (value) => setState(() => selectedEmotion = value),
              ),
              const SizedBox(height: 16),

              const Text('เลือกวิธีการทำนาย'),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile(
                      title: const Text('AI'),
                      value: 'AI',
                      groupValue: selectedPrediction,
                      onChanged: (value) =>
                          setState(() => selectedPrediction = value!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile(
                      title: const Text('ตำราโหราศาสตร์ไทย'),
                      value: 'astro',
                      groupValue: selectedPrediction,
                      onChanged: (value) =>
                          setState(() => selectedPrediction = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'บันทึกความฝัน',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
