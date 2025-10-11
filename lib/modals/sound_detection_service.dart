import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:project_dreamer_app/firebase_sound_service.dart';
// import 'package:project_dreamer_app/screens/detectionresult_screen.dart'; // ไม่ได้ใช้แล้ว
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:uuid/uuid.dart';
import 'package:project_dreamer_app/screens/sleep_summary_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http; // ✅ เพิ่ม Import
import 'dart:convert'; // ✅ เพิ่ม Import
// import 'package:project_dreamer_app/services/yamnet_analyzer.dart'; 

class SoundRecord {
  final String filePath;
  final DateTime timestamp;
  final double maxDecibel;
  final Duration duration;

  SoundRecord({
    required this.filePath,
    required this.timestamp,
    required this.maxDecibel,
    required this.duration,
  });
}

/// Widget หลักสำหรับตรวจจับและบันทึกเสียง
class SoundDetectionService extends StatefulWidget {
  const SoundDetectionService({super.key});

  @override
  State<SoundDetectionService> createState() => _SoundDetectionServiceState();
}

class _SoundDetectionServiceState extends State<SoundDetectionService> {
  final _recorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  final _firebaseSoundService = FirebaseSoundService();
  final _uuid = Uuid();
  
  // ✅ กำหนด URL Cloud Run ที่ใช้จริง
  static const String _cloudRunUrl = "https://dreamer-yamnet-api-616465545953.asia-southeast1.run.app/analyze"; 

  String _sessionId = "";
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;

  bool _isMonitoring = false;
  bool _isRecording = false;
  bool _isPlaying = false;

  double _currentDb = 0.0;
  final double _thresholdDb = 50.0;
  final Duration _maxRecordDuration = const Duration(seconds: 15);

  DateTime? _recordingStart;
  final List<SoundRecord> _soundRecords = [];

  @override
  void initState() {
    super.initState();
    if (_sessionId.isEmpty) {
      _sessionId =
          "sess_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}";
    }
    _checkAndRequestPermission().then((hasPermission) {
      if (hasPermission) {
        _startMonitoring();
      } else {
        debugPrint('ไม่สามารถเริ่มการทำงานได้เนื่องจากไม่ได้รับสิทธิ์ไมโครโฟน');
      }
    });
  }

  Future<bool> _checkAndRequestPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      return true;
    }

    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  @override
  void dispose() {
    _cleanupAll();
    super.dispose();
  }

  void _cleanupAll() {
    _noiseSubscription?.cancel();
    _recorder.stop().catchError((_) {});
    _audioPlayer.stop().catchError((_) {});
  }

  Future<void> _startMonitoring() async {
    //เริ่มตรวจจับเสียงตั้งค่า Db ต่ำสุดที่ 50 หากเกิน เรียกใช้ startRecording();
    if (_isRecording || _isMonitoring) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        setState(() {
          _isPlaying = false;
        });
      }

      _noiseMeter ??= NoiseMeter();
      _noiseSubscription = _noiseMeter!.noise.listen(
        (NoiseReading reading) {
          if (!mounted || _isRecording) return;

          setState(() {
            _currentDb = reading.maxDecibel;
          });

          if (reading.maxDecibel >= _thresholdDb) {
            debugPrint(
              "เสียงดังเกินเกณฑ์: ${_currentDb.toStringAsFixed(1)} dB -> เริ่มบันทึก",
            );
            _triggerRecording();
          }
        },
        onError: (error) {
          debugPrint("NoiseMeter error: $error");
          _stopMonitoring();
        },
      );

      setState(() {
        _isMonitoring = true;
      });
      debugPrint("เริ่มตรวจจับเสียงแล้ว");
    } catch (e) {
      debugPrint("Error starting monitoring: $e");
    }
  }

  Future<void> _stopMonitoring() async {
    await _noiseSubscription?.cancel();
    _noiseSubscription = null;
    setState(() {
      _isMonitoring = false;
    });
    debugPrint("หยุดตรวจจับเสียงแล้ว");
  }

  Future<void> _triggerRecording() async {
    if (_isRecording) return;

    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
      });
    }
    await _stopMonitoring();
    await Future.delayed(const Duration(milliseconds: 300));
    await _startRecording();
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${appDir.path}/rec_$timestamp.wav';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: filePath,
      );

      setState(() {
        _isRecording = true;
        _recordingStart = DateTime.now();
      });

      // ครบ 15 วิ แล้วหยุดเลย
      Future.delayed(_maxRecordDuration, () async {
        if (_isRecording) {
          debugPrint(
            "บันทึกครบ ${_maxRecordDuration.inSeconds} วินาที → หยุดบันทึก",
          );
          await _stopRecording(filePath); 
        }
      });

      debugPrint('🎙 เริ่มบันทึก: $filePath');
    } catch (e) {
      debugPrint('❌ Error starting recording: $e');
      _cleanupRecording();
    }
  }
  
  Future<void> _stopRecording(String filePath) async {
    if (!_isRecording) return;

    try {
      await _recorder.stop();
      final recordingEnd = DateTime.now();

      setState(() {
        _isRecording = false;
      });

      final file = File(filePath);
      if (await file.exists() && await file.length() > 1024) {
        final fileName =
            'rec_${DateFormat('yyyyMMdd_HHmmss').format(recordingEnd)}.wav';
        final storagePath = 'audio/$_sessionId/$fileName';

        final audioUrl = await _firebaseSoundService.uploadSoundFile(
          filePath,
          fileName,
          overridePath: storagePath,
        );

        if (audioUrl != null) {
          final recordData = {
            'sessionId': _sessionId,
            'fileName': fileName,
            'filePath': audioUrl,
            'storagePath': storagePath,
            'timestamp': recordingEnd,
            'maxDecibel': _currentDb,
            'duration': recordingEnd.difference(_recordingStart!).inSeconds,
            'userId': 'temporary_user_${_uuid.v4()}',
            'type': 'pending', // ❗ สถานะรอการวิเคราะห์
          };

          // 1. บันทึกข้อมูลเริ่มต้นลง Firestore (สถานะ pending)
          await _firebaseSoundService.saveSoundRecord(recordData);

          setState(() {
            _soundRecords.add(
              SoundRecord(
                filePath: filePath,
                timestamp: recordingEnd,
                maxDecibel: _currentDb,
                duration: recordingEnd.difference(_recordingStart!),
              ),
            );
          });

          debugPrint('✅ อัปโหลดไฟล์เรียบร้อย, สถานะ: pending');

        } else {
          debugPrint('❌ อัปโหลดล้มเหลว');
        }
      } else {
        debugPrint('❌ ไฟล์ว่างหรือสั้นเกินไป');
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    } finally {
      _cleanupRecording();
      await Future.delayed(const Duration(milliseconds: 500));
      _resumeMonitoring(); // 🔁 กลับไปตรวจจับเสียงต่ออัตโนมัติ
    }
  }

  void _cleanupRecording() {
    setState(() {
      _isRecording = false;
      _recordingStart = null;
    });
  }

  Future<void> _resumeMonitoring() async {
    if (!_isRecording && mounted) {
      await _startMonitoring();
    }
  }

  Future<void> _deleteRecord(int index) async {
    final record = _soundRecords[index];
    final file = File(record.filePath);

    if (await file.exists()) {
      try {
        await file.delete();
        setState(() {
          _soundRecords.removeAt(index);
        });
        debugPrint('ลบไฟล์สำเร็จ: ${record.filePath}');
      } catch (e) {
        debugPrint('เกิดข้อผิดพลาดในการลบไฟล์: $e');
      }
    } else {
      setState(() {
        _soundRecords.removeAt(index);
      });
      debugPrint('ไฟล์ไม่พบแต่ลบออกจากรายการแล้ว');
    }
  }

  void _showRecordingsList() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecordingListScreen(
          soundRecords: _soundRecords,
          onDelete: _deleteRecord,
          onPlay: _togglePlay,
        ),
      ),
    );
  }

  Future<void> _togglePlay(String filePath) async {
    try {
      debugPrint('กำลังจะเล่นไฟล์: $filePath');
      if (_isPlaying) {
        await _audioPlayer.stop();
        _startMonitoring();
      } else {
        await _stopMonitoring();
        await _audioPlayer.setFilePath(filePath);
        await _audioPlayer.play();
      }
      setState(() {
        _isPlaying = !_isPlaying;
      });

      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          setState(() {
            _isPlaying = false;
          });
          _startMonitoring();
        }
      });
    } catch (e) {
      debugPrint('เกิดข้อผิดพลาดในการเล่นเสียง: $e');
      _startMonitoring();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ทดสอบระบบบันทึกเสียง')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'สถานะ: ${_isRecording
                  ? "กำลังบันทึก"
                  : _isMonitoring
                      ? "กำลังตรวจจับ"
                      : "หยุดทำงาน"}',
              style: TextStyle(
                fontSize: 24,
                color: _isRecording ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 20),
            if (_isMonitoring)
              Text(
                'ระดับเสียงปัจจุบัน: ${_currentDb.toStringAsFixed(1)} dB',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _showRecordingsList,
              child: const Text('ดูรายการเสียงที่บันทึก'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  // 🛑 1) หยุดการตรวจจับและบันทึกเสียงทั้งหมด
                  await _stopMonitoring();

                  // 🧩 2) ตรวจสอบ sessionId เดิม
                  if (_sessionId.isEmpty) return;

                  final sessionId = _sessionId;

                  // 🕒 3) บันทึก session ลง Firestore ด้วยสถานะเริ่มต้น
                  await FirebaseFirestore.instance
                      .collection('sessions')
                      .doc(sessionId)
                      .set({
                        'sessionId': sessionId,
                        'type': 'pending', 
                        'timestamp': Timestamp.now(),
                        'analyzed': false, // ตั้งเป็น False เพื่อรอ Cloud Run
                      }, SetOptions(merge: true)); 

                  debugPrint("✅ บันทึก session เรียบร้อย: $sessionId");

                  // 🟢 4) [NEW STEP] เรียก Cloud Run API เพื่อเริ่มการวิเคราะห์
                  try {
                    debugPrint("📡 Calling Cloud Run Analysis API...");
                    final response = await http.post(
                      Uri.parse(_cloudRunUrl),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({'sessionId': sessionId}),
                    );

                    if (response.statusCode >= 200 && response.statusCode < 300) {
                      debugPrint("✅ Cloud Run API Called Successfully.");
                    } else {
                      // ถ้า Cloud Run ล้มเหลว (เช่น 404, 500)
                      debugPrint("❌ Cloud Run API Failed (Status ${response.statusCode}): ${response.body}");
                      await FirebaseFirestore.instance.collection('sessions').doc(sessionId).update({
                        'analyzed': true,
                        'error_reason': 'Cloud Run Call Failed: ${response.statusCode}',
                        'type': 'done', // ตั้งเป็น done เพื่อให้ Summary Screen โหลดผลลัพธ์
                      });
                    }
                  } catch (e) {
                      // ถ้าเกิด Error ในการเชื่อมต่อ HTTP (เช่น ไม่ต่อเน็ต)
                      debugPrint("❌ HTTP Call Error to Cloud Run: $e");
                      await FirebaseFirestore.instance.collection('sessions').doc(sessionId).update({
                        'analyzed': true,
                        'error_reason': 'HTTP Call Error: $e',
                        'type': 'done', 
                      });
                  }
                  
                  // 🎯 5) เปิดหน้า Summary (จะรอจนกว่า Cloud Function จะสร้าง Summary เสร็จ)
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SummarySnoreLabStyle(sessionId: sessionId),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint("❌ เกิดข้อผิดพลาดใน Stop Session: $e");
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("เกิดข้อผิดพลาดในการหยุดเซสชัน: $e"),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'หยุดเซสชันและดูสรุป',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// หน้าสำหรับแสดงรายการไฟล์เสียงที่บันทึก
class RecordingListScreen extends StatelessWidget {
  final List<SoundRecord> soundRecords;
  final void Function(int index) onDelete;
  final void Function(String filePath) onPlay;

  const RecordingListScreen({
    super.key,
    required this.soundRecords,
    required this.onDelete,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รายการเสียงที่บันทึก')),
      body: soundRecords.isEmpty
          ? const Center(child: Text('ยังไม่มีไฟล์ที่บันทึก'))
          : ListView.builder(
              itemCount: soundRecords.length,
              itemBuilder: (context, index) {
                final record = soundRecords[index];
                return ListTile(
                  leading: const Icon(Icons.audiotrack, color: Colors.blue),
                  title: Text(
                    'บันทึกที่ ${index + 1} (${record.duration.inSeconds} วินาที)',
                  ),
                  subtitle: Text(
                    'เวลา: ${DateFormat('HH:mm:ss').format(record.timestamp)}\n'
                    'Max dB: ${record.maxDecibel.toStringAsFixed(1)} dB',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_arrow, color: Colors.green),
                        onPressed: () => onPlay(record.filePath),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => onDelete(index),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}