// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'dream_input_screen.dart';
import 'dream_result_screen.dart';
import 'dream_stat_screen.dart';
//import 'dream_loading_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dream App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/input',
      routes: {
        '/input': (context) => const DreamInputScreen(),

        // DreamResultScreen ต้องส่ง args ผ่าน Navigator.push()
        '/result': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return DreamResultScreen(
            dreamId: args['dreamId'] as String,
            dreamTitle: args['dreamTitle'] as String,
            dreamStory: args['dreamStory'] as String,
            dreamImageUrl: args['dreamImageUrl'] as String,
            dreamInterpretation:
                args['dreamInterpretation'] as List<Map<String, dynamic>>,
            luckyNumber: args['luckyNumber'] as String,
            model: args['model'] as String,
          );
        },

        '/stats': (context) => const DreamStatScreen(), 

      },
    );
  }
}

