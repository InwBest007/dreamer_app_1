// DreamResultScreen
import 'package:cloud_firestore/cloud_firestore.dart'; // เพิ่ม import Firestore
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';

class DreamResultScreen extends StatelessWidget {
  final String dreamId; // id ของ document
  final String dreamTitle;
  final String dreamStory;
  final String dreamImageUrl;
  final List<Map<String, dynamic>> dreamInterpretation;
  final String luckyNumber;
  final String model; // เก็บว่าใช้โมเดลอะไร

  const DreamResultScreen({
    required this.dreamId,
    required this.dreamTitle,
    required this.dreamStory,
    required this.dreamImageUrl,
    required this.dreamInterpretation,
    required this.luckyNumber,
    required this.model,
  });

  Future<void> _saveInterpretation(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection("dreamEntries")
          .doc(dreamId)
          .update({
        "interpretations": dreamInterpretation,
        "luckyNumber": luckyNumber,
        "model": model,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("บันทึกคำทำนายเรียบร้อย ✨")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("บันทึกไม่สำเร็จ: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(
          "ผลการทำนายความฝัน",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 15),
              Text("ชื่อเรื่อง", style: TextStyle(fontSize: 14)),
              Container(
                height: 50,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  border: Border.all(color: Colors.deepPurple, width: 2),
                ),
                child: Text(
                  dreamTitle,
                  style: const TextStyle(color: Colors.black),
                ),
              ),
              const SizedBox(height: 15),
              Text("ภาพความฝัน", style: TextStyle(fontSize: 14)),
              Container(
                height: 200,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  border: Border.all(color: Colors.deepPurple, width: 2),
                ),
                child: dreamImageUrl.startsWith("http")
                    ? Image.network(dreamImageUrl, fit: BoxFit.cover)
                    : dreamImageUrl.startsWith("data:image") // เช็ค base64
                        ? Image.memory(
                            base64Decode(
                              dreamImageUrl
                                  .split(',')
                                  .last, // ตัด prefix "data:image/png;base64,"
                            ),
                            fit: BoxFit.cover,
                          )
                        : File(dreamImageUrl).existsSync()
                            ? Image.file(File(dreamImageUrl), fit: BoxFit.cover)
                            : const Text(
                                "ไม่พบไฟล์ภาพ",
                                style: TextStyle(color: Colors.red),
                              ),
              ),
              const SizedBox(height: 15),
              Text("เรื่องราวความฝัน", style: TextStyle(fontSize: 14)),
              Container(
                constraints: const BoxConstraints(
                  minHeight: 100,
                  maxHeight: 200,
                ),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  border: Border.all(color: Colors.deepPurple, width: 2),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    dreamStory,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Text("คำทำนายจากความฝันของคุณ", style: TextStyle(fontSize: 14)),
              Container(
                constraints: const BoxConstraints(
                  minHeight: 100,
                  maxHeight: 200,
                ),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  border: Border.all(color: Colors.deepPurple, width: 2),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: dreamInterpretation.map((item) {
                      final interp = item['interpretation'] ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(interp,
                            style: const TextStyle(color: Colors.black87)),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Text("ตัวเลขนำโชค", style: TextStyle(fontSize: 14)),
              Container(
                alignment: Alignment.center,
                constraints: const BoxConstraints(minHeight: 100),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  border: Border.all(color: Colors.deepPurple, width: 2),
                ),
                child: Text(
                  luckyNumber,
                  style: const TextStyle(color: Colors.black),
                ),
              ),
              
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _saveInterpretation(context),
                icon: const Icon(Icons.save),
                label: const Text("บันทึกคำทำนาย"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
