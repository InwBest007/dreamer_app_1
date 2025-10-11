import 'package:flutter/material.dart';
import 'detection_result_screen.dart'; //import หน้าประวัติการนอน

class SoundDetectionHomeScreen extends StatelessWidget {
  const SoundDetectionHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ระบบตรวจจับเสียง'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _buildMenuItem(
              context,
              Icons.bedtime,
              "เริ่มตรวจจับ",
              () => Navigator.pushNamed(context, "/start_detection"),
            ),
            _buildMenuItem(
              context,
              Icons.bar_chart,
              "ประวัติการนอน",
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DetectionResultScreen(),
                ),
              ),
            ),
            _buildMenuItem(
              context,
              Icons.info_outline,
              "วิธีใช้งาน",
              () => Navigator.pushNamed(context, "/instructions"),
            ),
            _buildMenuItem(
              context,
              Icons.settings,
              "ตั้งค่า",
              () => Navigator.pushNamed(context, "/settings"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
      BuildContext context, IconData icon, String title, VoidCallback onPressed) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(2, 3),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.deepPurple),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
