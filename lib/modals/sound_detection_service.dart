import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:project_dreamer_app/firebase_sound_service.dart';
import 'package:project_dreamer_app/services/local_yamnet_service.dart'; //เพิ่มการ Local มาแทน cloud
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
  static const String _cloudRunUrl =
      "https://dreamer-yamnet-api-616465545953.asia-southeast1.run.app/analyze";

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
    await Future.delayed(
      const Duration(milliseconds: 300),
    ); //พัก 3 วินาทีและเริ่มจับเสียงใหม่
    await _startRecording();
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${appDir.path}/rec_$timestamp.wav';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000, // ✅ ใช้ sample rate 16kHz
          numChannels: 1, // ✅ ให้บันทึกเป็น mono
          //bitDepth: 16     // (optional) เพิ่มความชัด
        ),
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
            'type': 'pending', //รอส่งไปวิเคราะห์ประเภทของเสียงที่บันทึกได้
          };

          //บันทึกข้อมูลเริ่มต้นลง Firestore (สถานะ pending)
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
          debugPrint('อัปโหลดล้มเหลว');
        }
      } else {
        debugPrint('ไฟล์ว่างหรือสั้นเกินไป'); //ไว้เช็คกรณีไฟล์ที่บันทึกมีปัญหา
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    } finally {
      _cleanupRecording();
      await Future.delayed(const Duration(milliseconds: 500));
      _resumeMonitoring(); //กลับไปตรวจจับเสียงต่ออัตโนมัติ
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

  Future<void> _downloadFile(String url, String savePath) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final file = File(savePath);
      await file.writeAsBytes(response.bodyBytes);
      debugPrint('✅ ดาวน์โหลดสำเร็จ: $savePath');
    } else {
      throw Exception(
        'Failed to download file from $url. Status: ${response.statusCode}',
      );
    }
  }

  //แบบ Local มันไม่มีการสรุป เลยทำเพิ่ม ปกติ Cloud จะเป็นคนส่งสรุปมาให้แทน
  Future<Map<String, dynamic>> _aggregateSummary(String sessionId) async {
    final clipsSnapshot = await FirebaseFirestore.instance
        .collection('sound_data')
        .where('sessionId', isEqualTo: sessionId)
        .where('analyzed', isEqualTo: true) // เลือกเฉพาะคลิปที่วิเคราะห์แล้ว
        .get();

    int totalClips = clipsSnapshot.docs.length;
    double peakMaxDecibel = 0.0;
    double totalDecibelSum = 0.0;
    int totalDuration = 0;
    Map<String, dynamic> typeCounts = {};
    List<Map<String, dynamic>> timeline = [];

    for (var doc in clipsSnapshot.docs) {
      final data = doc.data();
      final type = (data['type'] as String? ?? 'unknown').toLowerCase();
      final duration = (data['duration'] as int? ?? 0);
      final maxDecibel = (data['maxDecibel'] as num? ?? 0.0).toDouble();
      final url = data['filePath'] as String? ?? '';

      //รวมสถิติ
      totalDuration += duration;
      totalDecibelSum += maxDecibel;
      if (maxDecibel > peakMaxDecibel) {
        peakMaxDecibel = maxDecibel;
      }

      //นับประเภทเสียง
      typeCounts.update(type, (value) {
        value['count'] += 1;
        value['duration'] += duration;
        return value;
      }, ifAbsent: () => {'count': 1, 'duration': duration});

      //สร้างเวลาไว้แสดงผลที่บันทึกได้
      timeline.add({
        'type': type,
        'duration': duration,
        'maxDecibel': maxDecibel,
        'timestamp': data['timestamp'] as Timestamp,
        'url': url, // อย่าลืมใส่ URL ที่ใช้เล่นเสียง
      });
    }

    return {
      'meta': {
        'totalClips': totalClips,
        'totalDuration': totalDuration,
        'peakMaxDecibel': peakMaxDecibel,
        'avgMaxDecibel': totalClips > 0 ? totalDecibelSum / totalClips : 0.0,
      },
      'types': typeCounts,
      'timeline': timeline,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B263B),
        title: const Text(
          'ระบบตรวจจับและบันทึกเสียง 🌙',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1B263B), Color(0xFF415A77)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🌙 พระจันทร์เรียบ ๆ ไม่มีเอฟเฟกต์
              Icon(
                Icons.nightlight_round,
                size: 100,
                color: _isRecording
                    ? Colors.redAccent
                    : _isMonitoring
                    ? Colors.cyanAccent
                    : Colors.white54,
              ),
              const SizedBox(height: 30),

              // 🌌 ข้อความทักทายกลางจอ
              const Text(
                'ราตรีสวัสดิ์ 🌙',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isRecording
                    ? 'กำลังบันทึกเสียงอยู่...'
                    : _isMonitoring
                    ? 'กำลังตรวจจับเสียงรอบข้าง...'
                    : 'หยุดทำงาน',
                style: TextStyle(
                  color: _isRecording
                      ? Colors.redAccent
                      : _isMonitoring
                      ? Colors.cyanAccent
                      : Colors.white60,
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 40),

              // 📈 แสดงระดับเสียงปัจจุบัน
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isRecording
                        ? Colors.redAccent
                        : Colors.cyanAccent.withOpacity(0.5),
                    width: 1.4,
                  ),
                ),
                child: Text(
                  'ระดับเสียงปัจจุบัน: ${_currentDb.toStringAsFixed(1)} dB',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 40),
              // 🔘 ปุ่ม "ดูรายการเสียงที่บันทึก"
              ElevatedButton.icon(
                onPressed: _showRecordingsList,
                icon: const Icon(Icons.library_music, color: Colors.white),
                label: const Text(
                  'ดูรายการเสียงที่บันทึก',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.withOpacity(0.8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 🔘 ปุ่ม "หยุดเซสชันและดูผลสรุป"
              ElevatedButton(
                // คอมเม้นส่วนที่ใช้ cloud เนื่องจากยังไม่สามารถวิเคราะห์ได้
                // onPressed: () async {
                //   try {
                //     await _stopMonitoring();

                //     if (_sessionId.isEmpty) return; // ถ้า sessionId ว่าง หรือไม่เจอ

                //     final sessionId = _sessionId; //เก็บค่า sessionID

                //     await FirebaseFirestore.instance  // session ลง Firestore ด้วยสถานะเริ่มต้น
                //         .collection('sessions')
                //         .doc(sessionId)
                //         .set({
                //           'sessionId': sessionId,
                //           'type': 'pending',
                //           'timestamp': Timestamp.now(),
                //           'analyzed': false, // ตั้งเป็น False เพื่อรอ Cloud Run
                //         }, SetOptions(merge: true));

                //     debugPrint("✅ บันทึก session เรียบร้อย: $sessionId");

                //     //เรียก Cloud Run API เพื่อเริ่มการวิเคราะห์
                //     try {
                //       debugPrint("Calling Cloud Run Analysis API..."); //เช็คว่ามีการเรียน API ในการเช็ค
                //       final response = await http.post(
                //         Uri.parse(_cloudRunUrl),
                //         headers: {'Content-Type': 'application/json'},
                //         body: jsonEncode({'sessionId': sessionId}),
                //       );

                //       if (response.statusCode >= 200 && response.statusCode < 300) {
                //         debugPrint("✅ Cloud Run API Called Successfully.");
                //       } else {
                //         // ถ้า Cloud Run ล้มเหลว (เช่น 404, 500)
                //         debugPrint("❌ Cloud Run API ใช้งานไม่ได้ (Status ${response.statusCode}): ${response.body}");
                //         await FirebaseFirestore.instance.collection('sessions').doc(sessionId).update({
                //           'analyzed': true,
                //           'error_reason': 'Cloud Run Call Failed: ${response.statusCode}',
                //           'type': 'done', // ตั้งเป็น done เพื่อให้ Summary โหลดผลลัพธ์
                //         });
                //       }
                //     } catch (e) {
                //         // เช็ค Error ในการเชื่อมต่อ HTTP
                //         debugPrint("❌ HTTP Call Error to Cloud Run: $e");
                //         await FirebaseFirestore.instance.collection('sessions').doc(sessionId).update({
                //           'analyzed': true,
                //           'error_reason': 'HTTP Call Error: $e',
                //           'type': 'done',
                //         });
                //     }

                //     // 🎯 5) เปิดหน้า Summary (จะรอจนกว่า Cloud Function จะสร้าง Summary เสร็จ)
                //     if (context.mounted) {
                //       Navigator.push(
                //         context,
                //         MaterialPageRoute(
                //           builder: (_) =>
                //               SummarySnoreLabStyle(sessionId: sessionId),
                //         ),
                //       );
                //     }
                //   } catch (e) {
                //     debugPrint("❌ เกิดข้อผิดพลาดใน Stop Session: $e");
                //     if (context.mounted) {
                //       ScaffoldMessenger.of(context).showSnackBar(
                //         SnackBar(
                //           content: Text("เกิดข้อผิดพลาดในการหยุดเซสชัน: $e"),
                //         ),
                //       );
                //     }
                //   }
                // },
                onPressed: () async {
                  //แก้ปัญหาด้วยการวิเคราะห์ Local
                  try {
                    await _stopMonitoring();
                    if (_sessionId.isEmpty) return;
                    final sessionId = _sessionId;

                    //ไว้อัปเดต Session ใน Firestore
                    await FirebaseFirestore.instance
                        .collection('sessions')
                        .doc(sessionId)
                        .set({
                          'sessionId': sessionId,
                          'type': 'pending', // สถานะเริ่มต้นก่อนวิเคราะห์
                          'timestamp': Timestamp.now(),
                          'analyzed': false, // ยังไม่ได้วิเคราะห์
                        }, SetOptions(merge: true));

                    debugPrint("✅ สร้าง session เรียบร้อย: $sessionId");

                    //วิเคราะห์เสียงในเครื่อง
                    try {
                      debugPrint(
                        "เริ่มวิเคราะห์เสียงในเครื่อง ใช้วิธี Local YAMNet",
                      );

                      final yamnet = LocalYamnetService();
                      await yamnet.init(); // โหลด TFLite Model และ Labels

                      final clipsToAnalyze = await FirebaseFirestore.instance
                          .collection('sound_data')
                          .where('sessionId', isEqualTo: sessionId)
                          .get();

                      for (var clipDoc in clipsToAnalyze.docs) {
                        final data = clipDoc.data();
                        final firebaseStorageUrl = data['filePath'] as String?;
                        final clipId = clipDoc.id;
                        String? localTempPath;

                        if (firebaseStorageUrl != null &&
                            firebaseStorageUrl.isNotEmpty) {
                          // 🛑 FIX: สร้าง Local Path ชั่วคราวและดาวน์โหลดไฟล์
                          final tempDir = await getTemporaryDirectory();
                          final fileName = firebaseStorageUrl
                              .split('/')
                              .last
                              .split('?')
                              .first;
                          localTempPath = '${tempDir.path}/$clipId-$fileName';

                          try {
                            await _downloadFile(
                              firebaseStorageUrl,
                              localTempPath,
                            );
                            await yamnet.analyzeAndSave(clipId, localTempPath);
                          } catch (e) {
                            debugPrint('❌ ดาวน์โหลดหรือวิเคราะห์ล้มเหลว: $e');
                            await FirebaseFirestore.instance
                                .collection('sound_data')
                                .doc(clipId)
                                .update({
                                  'type': 'download_or_analyze_error',
                                  'analyzed': true,
                                });
                          } finally {
                            if (localTempPath != null) {
                              final tempFile = File(localTempPath);
                              if (await tempFile.exists()) {
                                await tempFile.delete();
                              }
                            }
                          }
                        }
                      }

                      final finalSummary = await _aggregateSummary(sessionId);

                      await FirebaseFirestore.instance
                          .collection('sessions')
                          .doc(sessionId)
                          .update({
                            'analyzed': true,
                            'type': 'done',
                            'completedAt': Timestamp.now(),
                            'summary': finalSummary,
                          });

                      debugPrint(
                        "วิเคราะห์เสียงทั้งหมดเสร็จสมบูรณ์ (Local Mode)",
                      );
                    } catch (e) {
                      debugPrint("วิเคราะห์เสียงไม่ได้ (Runtime Error): $e");
                      await FirebaseFirestore.instance
                          .collection('sessions')
                          .doc(sessionId)
                          .update({
                            'analyzed': true,
                            'type': 'done_with_error',
                            'error_reason': e.toString(),
                          });
                    }
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
                  'กดหยุดเซสชันและดูผลสรุปการนอน',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// หน้าสำหรับแสดงรายการไฟล์เสียงที่บันทึก ไว้เช็คเสียงที่ตรวจจับและบันทึกได้ แต่ปกติ ผู้ใช้งานจะไม่สามารถเห็นได้ระวังบันทึก
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
