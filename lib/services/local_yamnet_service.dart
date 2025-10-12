// import 'dart:typed_data';
// import 'dart:io';
// import 'package:tflite_flutter/tflite_flutter.dart';
// import 'package:flutter/services.dart';
// import 'package:csv/csv.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:permission_handler/permission_handler.dart';

// class YamnetAnalyzer {
//   late Interpreter _interpreter;
//   late List<String> _classMap;
//   bool _isInitialized = false;

//   /// ✅ โหลดโมเดลและ class map
//   Future<void> init() async {
//     if (_isInitialized) return;
//     try {
//       _interpreter = await Interpreter.fromAsset('yamnet.tflite');
//       final csvData = await rootBundle.loadString('assets/yamnet_class_map.csv');
//       _classMap = const CsvToListConverter()
//           .convert(csvData)
//           .skip(1)
//           .map((row) => row[2].toString())
//           .toList();
//       _isInitialized = true;
//       print("✅ YAMNet model loaded (${_classMap.length} classes)");
//     } catch (e) {
//       print("🚨 Error loading YAMNet: $e");
//     }
//   }

//   /// ✅ วิเคราะห์เสียงจากไฟล์ .wav ที่ Flutter บันทึกไว้
//   Future<String> analyzeWavFile(String filePath) async {
//     if (!_isInitialized) await init();

//     try {
//       final file = File(filePath);
//       if (!await file.exists()) {
//         print("⚠️ File not found: $filePath");
//         return "file_not_found";
//       }

//       final bytes = await file.readAsBytes();
//       final buffer = bytes.buffer.asFloat32List();
//       final input = buffer.reshape([1, buffer.length]);
//       final output = List.filled(521, 0.0).reshape([1, 521]);

//       _interpreter.run(input, output);

//       int topIdx = output[0].indexOf(
//         output[0].reduce((a, b) => a > b ? a : b),
//       );

//       final label = _classMap[topIdx];
//       print("🎧 Detected sound: $label");
//       return _simplifyLabel(label);
//     } catch (e) {
//       print("🚨 Analyze error: $e");
//       return "unknown";
//     }
//   }

//   /// ✅ แปลง label จาก YAMNet ให้อยู่ในกลุ่มที่เราต้องการ
//   String _simplifyLabel(String label) {
//     final lower = label.toLowerCase();
//     if (lower.contains("snore") || lower.contains("snoring")) {
//       return "snoring";
//     } else if (lower.contains("speech") || lower.contains("talk")) {
//       return "speech";
//     } else if (lower.contains("teeth") || lower.contains("grinding")) {
//       return "bruxism";
//     } else if (lower.contains("sigh") || lower.contains("cough")) {
//       return "vocalization";
//     } else {
//       return "environment";
//     }
//   }

//   /// ✅ บันทึกผลการวิเคราะห์ลง Firestore
//   Future<void> saveToFirestore({
//     required String clipId,
//     required String sessionId,
//     required String label,
//   }) async {
//     try {
//       final firestore = FirebaseFirestore.instance;
//       await firestore.collection('sound_data').doc(clipId).update({
//         'type': label,
//         'analyzed': true,
//         'timestamp': FieldValue.serverTimestamp(),
//       });
//       await firestore.collection('sessions').doc(sessionId).update({
//         'analyzed': true,
//       });
//       print("✅ Firestore updated: clip=$clipId, label=$label");
//     } catch (e) {
//       print("🚨 Firestore update error: $e");
//     }
//   }
// }
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:cloud_firestore/cloud_firestore.dart';


const int SAMPLE_RATE = 16000;
const int CHUNK_SIZE = 15600; 
const int OUTPUT_SIZE = 521; // จำนวนคลาสของ YAMNet

class LocalYamnetService {
  late tfl.Interpreter _interpreter;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> _labels = [];
  bool _isInitialized = false;

  /// โหลดโมเดลและ label map
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _interpreter = await tfl.Interpreter.fromAsset('assets/yamnet.tflite');
      final labelData = await rootBundle.loadString('assets/yamnet_class_map.csv');
      
      // ✅ FIX 1: โหลด Label โดยข้าม Header และเลือกเฉพาะ display_name
      final lines = labelData.split('\n');
      _labels = lines.skip(1) 
          .map((line) {
            final parts = line.split(',');
            // display_name คือค่าสุดท้าย
            return parts.isNotEmpty ? parts.last.trim() : ''; 
          })
          .where((label) => label.isNotEmpty)
          .toList();

      if (_labels.length != OUTPUT_SIZE) {
         throw Exception("Label count mismatch: expected $OUTPUT_SIZE, got ${_labels.length}");
      }
      _isInitialized = true;
      debugPrint('✅ โหลดโมเดล YAMNet สำเร็จ (${_labels.length} labels)');
    } catch (e) {
      debugPrint('🚨 โหลดโมเดลล้มเหลว: $e');
    }
  }

  /// วิเคราะห์เสียงทีละไฟล์และบันทึกผลลง Firestore
  // รับ clipId มาด้วยเพื่อใช้หา Document ใน Firestore
  Future<void> analyzeAndSave(String clipId, String filePath) async {
  if (!_isInitialized) await init();

  try {
    final wavData = await _loadWavFileAsFloat32(filePath);
    if (wavData == null || wavData.length < CHUNK_SIZE) {
      await _updateFirestoreResult(clipId, 'too_short', 0.0);
      return;
    }

    List<Float32List> allPredictions = [];

    // 2. ✅ FIX 2: วนลูปแบ่งไฟล์เสียงเป็น Segment 0.975 วินาที
    for (int i = 0; i < wavData.length - CHUNK_SIZE; i += CHUNK_SIZE) {
      Float32List segment = wavData.sublist(i, i + CHUNK_SIZE);
      
      var input = segment.reshape([1, CHUNK_SIZE]);
      var output = Float32List(OUTPUT_SIZE).reshape([1, OUTPUT_SIZE]);

      _interpreter.run(input, output);
      
      // 🛑 FIX: แปลงผลลัพธ์เป็น Float32List อย่างชัดเจน
      // เนื่องจาก output[0] อาจถูกคืนค่าเป็น List<double>
      if (output[0] is List<double>) {
        allPredictions.add(Float32List.fromList(output[0]));
      } else if (output[0] is Float32List) {
        allPredictions.add(output[0] as Float32List);
      } else {
        throw Exception("Unexpected output type from TFLite: ${output[0].runtimeType}");
      }
    }

    if (allPredictions.isEmpty) {
      await _updateFirestoreResult(clipId, 'too_short', 0.0);
      return;
    }

    // 3. ✅ FIX 3: การรวมผลลัพธ์ (Aggregation Logic)
    Float32List avgScores;
    if (allPredictions.length == 1) {
        avgScores = allPredictions[0];
    } else {
        // หาค่าเฉลี่ยของ scores ทั้งหมด
        avgScores = Float32List(OUTPUT_SIZE);
        for (int j = 0; j < OUTPUT_SIZE; j++) {
            double sum = 0;
            for (var pred in allPredictions) {
                sum += pred[j];
            }
            avgScores[j] = sum / allPredictions.length;
        }
    }
    
    // หาผลลัพธ์สุดท้าย
    int topIndex = 0;
    double maxConfidence = 0.0;
    for (int i = 0; i < avgScores.length; i++) {
        if (avgScores[i] > maxConfidence) {
            maxConfidence = avgScores[i];
            topIndex = i;
        }
    }

    String label = _labels[topIndex].trim();
    debugPrint('🎧 วิเคราะห์สำเร็จ → $label (conf: ${maxConfidence.toStringAsFixed(3)})');

    await _updateFirestoreResult(clipId, _mapToFriendlyLabel(label), maxConfidence);

  } catch (e) {
    debugPrint('❌ วิเคราะห์เสียงล้มเหลว: $e');
    // อัปเดต Firestore ด้วย runtime_error
    await _updateFirestoreResult(clipId, 'runtime_error', 0.0);
  }
}

  /// อ่านไฟล์ WAV → Float32
  Future<Float32List?> _loadWavFileAsFloat32(String path) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();

      // ตัด header (44 bytes)
      final audioBytes = bytes.sublist(44);

      // แปลงจาก 16-bit PCM → float32
      final data = Int16List.view(audioBytes.buffer);
      final floatData = Float32List(data.length);
      for (int i = 0; i < data.length; i++) {
        floatData[i] = data[i] / 32768.0; // Normalization
      }
      return floatData;
    } catch (e) {
      debugPrint('⚠️ อ่านไฟล์ WAV ไม่สำเร็จ: $e');
      return null;
    }
  }

  /// 🛠️ Helper สำหรับอัปเดต Firestore (คุณอาจต้องปรับให้เข้ากับโครงสร้างของคุณ)
  Future<void> _updateFirestoreResult(String clipId, String type, double confidence) async {
      await _firestore.collection('sound_data').doc(clipId).update({
          'type': type,
          'confidence': confidence,
          'analyzed': true,
      }).catchError((error) => debugPrint("Failed to update clip $clipId: $error"));
  }

  /// แปลง label จากโมเดลให้เข้าใจง่าย
  String _mapToFriendlyLabel(String label) {
    label = label.toLowerCase();
    if (label.contains('snoring')) return 'snoring_or_bruxism';
    if (label.contains('teeth-grinding')) return 'snoring_or_bruxism';
    if (label.contains('speech')) return 'speech';
    if (label.contains('sigh') || label.contains('cough') || label.contains('groan')) return 'other_vocalization';
    return 'other';
  }
}
