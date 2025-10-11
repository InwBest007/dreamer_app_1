import 'dart:typed_data';
import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

class YamnetAnalyzer {
  late Interpreter _interpreter;
  late List<String> _classMap;
  bool _isInitialized = false;

  /// ✅ โหลดโมเดลและ class map
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _interpreter = await Interpreter.fromAsset('yamnet.tflite');
      final csvData = await rootBundle.loadString('assets/yamnet_class_map.csv');
      _classMap = const CsvToListConverter()
          .convert(csvData)
          .skip(1)
          .map((row) => row[2].toString())
          .toList();
      _isInitialized = true;
      print("✅ YAMNet model loaded (${_classMap.length} classes)");
    } catch (e) {
      print("🚨 Error loading YAMNet: $e");
    }
  }

  /// ✅ วิเคราะห์เสียงจากไฟล์ .wav ที่ Flutter บันทึกไว้
  Future<String> analyzeWavFile(String filePath) async {
    if (!_isInitialized) await init();

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print("⚠️ File not found: $filePath");
        return "file_not_found";
      }

      final bytes = await file.readAsBytes();
      final buffer = bytes.buffer.asFloat32List();
      final input = buffer.reshape([1, buffer.length]);
      final output = List.filled(521, 0.0).reshape([1, 521]);

      _interpreter.run(input, output);

      int topIdx = output[0].indexOf(
        output[0].reduce((a, b) => a > b ? a : b),
      );

      final label = _classMap[topIdx];
      print("🎧 Detected sound: $label");
      return _simplifyLabel(label);
    } catch (e) {
      print("🚨 Analyze error: $e");
      return "unknown";
    }
  }

  /// ✅ แปลง label จาก YAMNet ให้อยู่ในกลุ่มที่เราต้องการ
  String _simplifyLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains("snore") || lower.contains("snoring")) {
      return "snoring";
    } else if (lower.contains("speech") || lower.contains("talk")) {
      return "speech";
    } else if (lower.contains("teeth") || lower.contains("grinding")) {
      return "bruxism";
    } else if (lower.contains("sigh") || lower.contains("cough")) {
      return "vocalization";
    } else {
      return "environment";
    }
  }

  /// ✅ บันทึกผลการวิเคราะห์ลง Firestore
  Future<void> saveToFirestore({
    required String clipId,
    required String sessionId,
    required String label,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('sound_data').doc(clipId).update({
        'type': label,
        'analyzed': true,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await firestore.collection('sessions').doc(sessionId).update({
        'analyzed': true,
      });
      print("✅ Firestore updated: clip=$clipId, label=$label");
    } catch (e) {
      print("🚨 Firestore update error: $e");
    }
  }
}
