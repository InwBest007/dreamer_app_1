// DreamInputScreen.dart (เพิ่ม nlp แบบ 100%)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dream_loading_screen.dart';

class DreamInputScreen extends StatefulWidget {
  const DreamInputScreen({super.key});

  @override
  State<DreamInputScreen> createState() => _DreamInputScreenState();
}

class _DreamInputScreenState extends State<DreamInputScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();

  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    // ตั้งค่าเริ่มต้นเป็นวันนี้
    selectedDate = DateTime.now();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is DateTime) {
      selectedDate = args;
    }
  }

  List<String> selectedTypes = [];
  List<String> selectedEmotions = [];
  String selectedPrediction = 'Astrology';

  final List<String> predictionModels = [
    'Astrology',
    'AI',
  ];

  final List<String> dreamTypes = [
    'ความฝันปกติ',
    'ฝันร้าย',
    'ฝันว่าตื่น',
    'ความฝันที่รู้ตัวว่ากำลังฝัน',
  ];
  final List<String> emotions = [
    'กลัว',
    'เศร้า',
    'ตื่นเต้น',
    'โกรธ',
    'เพลิดเพลิน',
    'ประหลาดใจ'
  ];

  String baseUrl = "http://100.104.205.64:8000"; // TailScale IP ของ Server

  Future<void> _handleSubmit() async {
    String dreamText = _content.text.trim();
    String titleText = _title.text.trim();

    if (dreamText.isEmpty || titleText.isEmpty) {
      _showDialog('รบกวนกรอกข้อมูลความฝันให้ครบถ้วน');
      return;
    }

    try {
      // ✅ เรียก check_typo endpoint เพื่อขอเวอร์ชันที่ระบบแก้คำผิด (เบากว่า /analyze เพราะไม่ยิงรูป/semantic)
      String correctedText = dreamText;
      bool correctionAvailable = false;

      try {
        final resp = await http
            .post(
              Uri.parse("$baseUrl/check_typo"),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({"dream": dreamText}),
            )
            .timeout(const Duration(seconds: 30));

        if (resp.statusCode == 200) {
          final map = jsonDecode(resp.body);

          // server ใหม่คืน:
          // {
          //   "original_text": ...,
          //   "corrected_text": ...,
          //   "tokens": [...],
          //   "changed": true/false
          // }

          String? serverCorrected = (map['corrected_text'] as String?)?.trim();

          List<dynamic>? correctedTokens;
          if (map['tokens'] != null && map['tokens'] is List) {
            correctedTokens = List<dynamic>.from(map['tokens']);
          } else if (map['corrected_tokens'] != null &&
              map['corrected_tokens'] is List) {
            // เผื่อกรณีในอนาคตมี key นี้
            correctedTokens = List<dynamic>.from(map['corrected_tokens']);
          }

          // เลือก candidate จาก corrected_text เป็นหลัก ถ้าไม่มี ค่อย fallback ไป tokens.join('')
          String candidate = dreamText;
          if (serverCorrected != null && serverCorrected.isNotEmpty) {
            candidate = serverCorrected;
          } else if (correctedTokens != null && correctedTokens.isNotEmpty) {
            candidate = correctedTokens.map((e) => e.toString()).join('');
          }

          if (candidate.trim().isNotEmpty && candidate.trim() != dreamText) {
            correctedText = candidate;
            correctionAvailable = true;
          }
        }
      } catch (e) {
        // ถ้าเรียก check_typo ไม่ได้ ไม่ต้องบล็อกผู้ใช้ — จะ fallback ไปใช้ต้นฉบับ
        print("Correction check failed: $e");
      }

      // ถ้ามีการแก้และแก้ต่างจากต้นฉบับ: ให้ผู้ใช้เลือกยืนยันหรือยกเลิก
      String textToSave = dreamText;
      if (correctionAvailable) {
        final useCorrected = await _showCorrectionDialog(
            original: dreamText, corrected: correctedText);
        if (useCorrected == true) {
          textToSave = correctedText;
        } else {
          textToSave = dreamText;
        }
      } else {
        textToSave = dreamText;
      }

      // บันทึกความฝันลง Firestore (ใช้ textToSave ตามการตัดสินของผู้ใช้)
      final docRef =
          await FirebaseFirestore.instance.collection("dreamEntries").add({
        "title": titleText,
        "content": textToSave,
        // เก็บเป็น array (หรือแปลงเป็นสตริงถ้าต้องการเก็บแบบเดิม)
        "type": selectedTypes.isNotEmpty ? selectedTypes : ["ไม่ระบุ"],
        "emotion": selectedEmotions.isNotEmpty ? selectedEmotions : ["ไม่ระบุ"],
        "date": selectedDate, // ใช้วันที่ที่ผู้ใช้เลือก
        "model": selectedPrediction,
      });

      final dreamId = docRef.id;

      _title.clear();
      _content.clear();
      setState(() {
        selectedTypes = [];
        selectedEmotions = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("บันทึกความฝันสำเร็จ ✨")),
      );

      // หน้ารอประมวลผล: ส่ง textToSave ไปประมวลผลต่อ
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DreamLoadingScreen(
            processDream: () async {
              // ใช้ baseUrl ที่กำหนดไว้ข้างบน (server/proxy)
              final endpoint =
                  (selectedPrediction == "AI") ? "/analyze_ai" : "/analyze";

              final response = await http
                  .post(
                    Uri.parse("$baseUrl$endpoint"),
                    headers: {
                      "Content-Type": "application/json",
                      // ลบ x-api-key ออกจาก client — server/proxy ควรจะเป็นตัวส่ง header นี้ (secure)
                    },
                    body: jsonEncode({"dream": textToSave}),
                  )
                  .timeout(const Duration(minutes: 3));

              if (response.statusCode == 200) {
                final result = jsonDecode(response.body);
                String imageUrl = result['image_url'] ?? '';

                List<Map<String, dynamic>> interpretations = [];
                String luckyNumbersString = '';
                if (selectedPrediction == "Astrology") {
                  List matchedKeywords = result['matched_keywords'] ?? [];

                  // เตรียม matched list (trim) และแบ่ง batch เพื่อ whereIn
                  final matched =
                      matchedKeywords.map((e) => e.toString().trim()).toList();

                  // Debug: แสดง matched keywords
                  print("[DEBUG] Matched keywords from model: $matched");

                  final List<List<String>> batches = [];
                  for (var i = 0; i < matched.length; i += 10) {
                    batches.add(
                        matched.sublist(i, (i + 10).clamp(0, matched.length)));
                  }

                  // Debug: แสดง batches ที่จะส่งไปหา Firestore
                  print(
                      "[DEBUG] Firestore batches (size=${batches.length}): $batches");

                  List<QueryDocumentSnapshot> allDocs = [];
                  for (final batch in batches) {
                    if (batch.isEmpty) continue;
                    final snap = await FirebaseFirestore.instance
                        .collection("dreamInt1")
                        .where("keyword", whereIn: batch)
                        .get();
                    print(
                        "[DEBUG] Firestore returned ${snap.docs.length} docs for batch: $batch");
                    allDocs.addAll(snap.docs);
                  }

                  // เก็บผลแมตช์แบบ mapping: keyword -> info
                  Map<String, Map<String, dynamic>> interpretationMap = {};

                  // นอกจากนี้เก็บ debug mapping: doc keyword -> matched_from (list of source tokens)
                  Map<String, dynamic> debugMatches =
                      {}; // for returning / logging

                  for (var doc in allDocs) {
                    final Map<String, dynamic>? data =
                        doc.data() as Map<String, dynamic>?;

                    if (data == null) continue;

                    final String? keywordRaw = data['keyword']?.toString();
                    if (keywordRaw == null || keywordRaw.isEmpty) continue;

                    final String keyword = keywordRaw;

                    final String interpretationText =
                        data['interpretation']?.toString() ?? 'ไม่พบคำทำนาย';
                    final String numberText =
                        data['luckynumber']?.toString() ?? '-';

                    // หาแหล่งที่มาจาก matched list (อาจจะตรงตัว)
                    final List<String> matchedFrom = matched
                        .where((m) => m == keyword)
                        .map((e) => e.toString())
                        .toList();

                    // ถ้าต้องการ fuzzy matching (เช่น synonyms) ให้เติม logic ที่นี่:
                    // เช่น หาใน synonyms map หรือบาง pattern
                    // final List<String> matchedSynonyms = ... (optional)

                    interpretationMap[keyword] = {
                      'keyword': keyword,
                      'interpretation': interpretationText,
                      'luckynumber': numberText,
                      'doc_id': doc.id,
                    };

                    debugMatches[keyword] = {
                      'doc_id': doc.id,
                      'matched_from': matchedFrom,
                      'interpretation': interpretationText,
                      'luckynumber': numberText,
                    };

                    // Debug: พิมพ์แต่ละแมตช์
                    print(
                        "[DEBUG] Matched DB doc -> keyword: $keyword, doc_id: ${doc.id}, matched_from: $matchedFrom, luckynumber: $numberText");
                  }

                  interpretations = interpretationMap.values.toList();

                  final uniqueLuckyNumbers = interpretations
                      .map((e) => e['luckynumber'] ?? '-')
                      .toSet()
                      .toList();
                  luckyNumbersString = uniqueLuckyNumbers.join(', ');

                  // Debug summary
                  print(
                      "[DEBUG] Interpretation count: ${interpretations.length}, unique lucky numbers: $uniqueLuckyNumbers");
                  print("[DEBUG] Debug matches map: $debugMatches");
                  //final debug_matches_to_return = debugMatches;
                } else {
                  interpretations = [
                    {
                      'keyword': 'AI Model',
                      'interpretation':
                          result['ai_interpretation'] ?? 'ไม่มีคำทำนาย',
                      'luckynumber': result['ai_luckynumber'] ?? '-',
                    }
                  ];
                  luckyNumbersString = result['ai_luckynumber'] ?? '-';
                }

                return {
                  'dreamId': dreamId,
                  'dreamTitle': titleText,
                  'dreamStory': textToSave,
                  'dreamImageUrl': imageUrl,
                  'dreamInterpretation': interpretations,
                  'luckyNumber': luckyNumbersString,
                  'model': selectedPrediction,
                };
              } else {
                throw Exception(
                    "API Error: ${response.statusCode} ${response.body}");
              }
            },
          ),
        ),
      );
    } catch (e) {
      _showDialog("ไม่สามารถประมวลผลได้: $e");
    }
  }

// helper dialog: คืนค่า true = ใช้ corrected, false = ยกเลิกใช้ corrected
  Future<bool?> _showCorrectionDialog(
      {required String original, required String corrected}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('ระบบแนะนำการแก้คำผิด'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ต้นฉบับ:'),
              const SizedBox(height: 6),
              Text(original),
              const Divider(),
              const Text('เวอร์ชันที่ระบบแก้คำผิด:'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(corrected),
              ),
              const SizedBox(height: 12),
              const Text('หากต้องการบันทึกเวอร์ชันที่ระบบแก้กรุณากด "ยืนยัน"'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstDate = now.subtract(const Duration(days: 30));

    if (selectedDate.isAfter(now)) selectedDate = now;
    if (selectedDate.isBefore(firstDate)) selectedDate = firstDate;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: firstDate,
      lastDate: now,
      locale: const Locale('th', 'TH'), // แสดงภาษาไทย
    );

    if (pickedDate != null) {
      if (!mounted) return;
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'บันทึกความฝัน',
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
              // ฟิลด์เลือกวันที่
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "วันที่บันทึก: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today,
                        color: Colors.deepPurple),
                    onPressed: _pickDate,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              const Text('ชื่อเรื่องความฝัน'),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "กรอกชื่อเรื่อง",
                ),
              ),
              const SizedBox(height: 12),
              const Text('เนื้อหาความฝัน'),
              TextField(
                controller: _content,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "กรอกเนื้อหาความฝัน",
                ),
              ),
              const SizedBox(height: 16),
              const Text("ประเภทความฝัน"),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: dreamTypes.map((type) {
                  final selected = selectedTypes.contains(type);
                  return FilterChip(
                    label: Text(type),
                    selected: selected,
                    checkmarkColor: Colors.white,
                    selectedColor: Colors.deepPurple,
                    showCheckmark: true,
                    onSelected: (isSelected) {
                      setState(() {
                        if (isSelected) {
                          selectedTypes.add(type);
                        } else {
                          selectedTypes.remove(type);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              const Text("อารมณ์ความฝัน"),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: emotions.map((emo) {
                  final selected = selectedEmotions.contains(emo);
                  return FilterChip(
                    label: Text(emo),
                    selected: selected,
                    checkmarkColor: Colors.white,
                    selectedColor: Colors.deepPurple,
                    showCheckmark: true,
                    onSelected: (isSelected) {
                      setState(() {
                        if (isSelected) {
                          selectedEmotions.add(emo);
                        } else {
                          selectedEmotions.remove(emo);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),
              const Text("เลือกโมเดลการทำนาย"),
              DropdownButtonFormField<String>(
                value: selectedPrediction,
                items: predictionModels.map((model) {
                  return DropdownMenuItem(value: model, child: Text(model));
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    selectedPrediction = val!;
                  });
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text("บันทึกความฝัน"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// IPv4 ฝั่ง server: 192.168.1.10
// ทดสอบจากฝั่ง client (curl / PowerShell)
// curl -v http://<YOUR_IP>:8000/health

/*
curl -X POST "http://<YOUR_IP>:8000/analyze_ai" \
  -H "Content-Type: application/json" \
  -d '{"dream":"ฝันว่าตั้งท้องได้ลูกชาย"}'
*/
