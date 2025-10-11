import 'package:flutter/material.dart';
import 'package:project_dreamer_app/screens/dream_calender_screen.dart';

class MainScreen extends StatelessWidget{
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: const Text('หน้าจอหลัก'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildMenuItem(context, Icons.calendar_month, 'บันทึกความฝัน', '/dream_calender'),
            _buildMenuItem(context, Icons.mic, 'ตรวจจับเสียง', '/sound_detection'),
            _buildMenuItem(context, Icons.bar_chart, 'สถิติความฝัน', '/stats'),
            _buildMenuItem(context, Icons.book, 'บทความ', '/articles'),
            _buildMenuItem(context, Icons.music_note, 'เพลง', '/music_screen'),
          ],
          ),
          ),
    );
  }
}

Widget _buildMenuItem(BuildContext context, IconData icon, String label, String route){
  return ElevatedButton(
    style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(12)),
    onPressed: (){
      Navigator.pushNamed(context, route);
    },
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 48),
        const SizedBox(height: 12),
        Text(label, textAlign: TextAlign.center)
      ],
    ),
  );
}