import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:project_dreamer_app/screens/detectionresult_screen.dart';

class RecordingScreen extends StatelessWidget {
  const RecordingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[900],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "ราตรีสวัสดิ์",
              style: TextStyle(fontSize: 32, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              "เริ่มบันทึกเวลา: ${DateFormat('HH:mm').format(DateTime.now())}",
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 40),
            const Icon(Icons.mic, color: Colors.white, size: 64),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        DetectionResultScreen(sleepDate: DateTime.now()),
                  ),
                );
              },
              child: const Text('หยุดบันทึก'),
            ),
          ],
        ),
      ),
    );
  }
}
