// ตัวกลางเอาไว้ส่งข้อมูลระหว่าง แอป กับฐานข้อมูลไว้เก็บไฟล์เสียง
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class FirebaseSoundService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ฟังก์ชันสำหรับบันทึกข้อมูลการบันทึกเสียงลง Firestore ข้อมูลสำหรับไฟล์เสียง
  Future<void> saveSoundRecord(Map<String, dynamic> recordData) async {
    //รับข้อมูล recordData จาก Sound_detection_service.dart
    try {
      await _firestore
          .collection('sound_data')
          .add(recordData); //บันทึกลง collection ที่ชื่อว่า soundRecordes
    } catch (e) {
      if (kDebugMode) {
        print("Error saving record to Firestore: $e");
      }
    }
  }

  // ฟังก์ชันสำหรับอัปโหลดไฟล์เสียงไปยัง Firebase Storage
  Future<String?> uploadSoundFile(String filePath, String fileName,
    {String? overridePath}) async {
  try {
    final file = File(filePath);
    final ref = FirebaseStorage.instance.ref().child(
        overridePath ?? 'audio/$fileName'); // ถ้ามี override ใช้ path นี้
    await ref.putFile(file); // ✅ อัปโหลดจริง
    return await ref.getDownloadURL(); // ✅ ได้ลิงก์ไปใช้
  } catch (e) {
    debugPrint("❌ Upload error: $e");
    return null;
  }
}

  Future<void> markSessionForSummary({
    required String sessionId,
    required Map<String, dynamic> payload,
  }) async {
    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .set(payload, SetOptions(merge: true));
  }
}
