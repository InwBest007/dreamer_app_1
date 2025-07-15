import 'package:flutter/material.dart';

class SoundDetectionHomeScreen extends StatelessWidget {
  const SoundDetectionHomeScreen({super.key});

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: const Text('ระบบตรวจจับเสียง'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _buildMenuItem(context, Icons.bedtime, "เริ่มตรวจจับ", "/start_detection"),
            _buildMenuItem(context, Icons.bar_chart, "ดูผลย้อนหลัง", "/results"),
            _buildMenuItem(context, Icons.info, "วิธีใช้งาน", "/instructions"),
            _buildMenuItem(context, Icons.settings, "ตั้งค่า", "/settings"),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, String route){
    return ElevatedButton(
      onPressed: () => Navigator.pushNamed(context, route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}