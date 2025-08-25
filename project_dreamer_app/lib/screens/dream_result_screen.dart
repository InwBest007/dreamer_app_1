import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class DreamResultScreen extends StatelessWidget {
  final String dreamTitle;
  final String dreamStory;
  final String dreamImageUrl;
  final String dreamInterpretation;
  final String luckyNumber;

  const DreamResultScreen({
    required this.dreamTitle,
    required this.dreamStory,
    required this.dreamImageUrl,
    required this.dreamInterpretation,
    required this.luckyNumber,
  });

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
                  child: Text(
                    dreamInterpretation,
                    style: const TextStyle(color: Colors.black87),
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
            ],
          ),
        ),
      ),
    );
  }
}
