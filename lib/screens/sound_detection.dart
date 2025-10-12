import 'package:flutter/material.dart';
import 'detection_result_screen.dart'; // import หน้าประวัติการนอน

class SoundDetectionHomeScreen extends StatelessWidget {
  const SoundDetectionHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF1FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B5BE0),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'ระบบตรวจจับเสียง 🔊',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF5B5BE0), Color(0xFF9FA8DA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildMenuItem(
                context,
                Icons.mic,
                "เริ่มตรวจจับเสียง",
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
      ),
    );
  }

  Widget _buildMenuItem(
      BuildContext context, IconData icon, String title, VoidCallback onPressed) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF8C9EFF), Color(0xFF5B5BE0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(3, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
