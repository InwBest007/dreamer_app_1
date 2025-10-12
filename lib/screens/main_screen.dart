// import 'package:flutter/material.dart';
// import 'package:project_dreamer_app/screens/dream_calender_screen.dart';

// class MainScreen extends StatelessWidget{
//   const MainScreen({super.key});

//   @override
//   Widget build(BuildContext context){
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('หน้าจอหลัก'),
//         centerTitle: true,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: GridView.count(
//           crossAxisCount: 2,
//           crossAxisSpacing: 16,
//           mainAxisSpacing: 16,
//           children: [
//             _buildMenuItem(context, Icons.calendar_month, 'บันทึกความฝัน', '/dream_calender'),
//             _buildMenuItem(context, Icons.mic, 'ตรวจจับเสียง', '/sound_detection'),
//             _buildMenuItem(context, Icons.bar_chart, 'สถิติความฝัน', '/stats'),
//             _buildMenuItem(context, Icons.book, 'บทความ', '/articles'),
//             _buildMenuItem(context, Icons.music_note, 'เพลง', '/music_screen'),
//           ],
//           ),
//           ),
//     );
//   }
// }

// Widget _buildMenuItem(BuildContext context, IconData icon, String label, String route){
//   return ElevatedButton(
//     style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(12)),
//     onPressed: (){
//       Navigator.pushNamed(context, route);
//     },
//     child: Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Icon(icon, size: 48),
//         const SizedBox(height: 12),
//         Text(label, textAlign: TextAlign.center)
//       ],
//     ),
//   );
// }
import 'package:flutter/material.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF1FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B5BE0),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Dreamer 🌙',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white),
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
          padding: const EdgeInsets.all(16),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _menuItem(context, Icons.calendar_month, 'บันทึกความฝัน', '/dream_calender'),
              _menuItem(context, Icons.mic, 'ตรวจจับเสียง', '/sound_detection'),
              _menuItem(context, Icons.bar_chart, 'สรุปผลการนอน', '/summary_screen'),
              _menuItem(context, Icons.music_note, 'เพลงช่วยนอน', '/music_screen'),
              _menuItem(context, Icons.book, 'บทความสุขภาพ', '/articles'),
              _menuItem(context, Icons.settings, 'ตั้งค่า', '/settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String label, String route) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF8C9EFF), Color(0xFF5B5BE0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(2, 3)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              label,
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
