import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:project_dreamer_app/screens/dream_calender_screen.dart';
import 'package:project_dreamer_app/screens/dream_input_screen.dart';
import 'package:project_dreamer_app/screens/main_screen.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:project_dreamer_app/screens/recording_screen.dart';
import 'package:project_dreamer_app/screens/sound_detection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ต้องมีสำหรับ async
  await initializeDateFormatting('th_TH', null);

  Intl.defaultLocale = 'th_TH';
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dreamer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      debugShowCheckedModeBanner: false,
      home: const MainScreen(), // ✅ ใช้แค่ home
      routes: {
        '/dream_calender': (context) => const DreamCalendarScreen(),
        '/dream_input_screen': (context) => const DreamInputScreen(),
        '/sound_detection': (context) => const SoundDetectionHomeScreen(),
        '/start_detection': (context) => const RecordingScreen(),
      },
    );
  }
}
