import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
//import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';

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
    //required String wavPath,
  });
}

class SoundDetectionScreen extends StatefulWidget {
  const SoundDetectionScreen({super.key});

  @override
  State<SoundDetectionScreen> createState() => _SoundDetectionScreenState();
}

class _SoundDetectionScreenState extends State<SoundDetectionScreen> {
  bool _isRecording = false; //ปุ่มบันทึก
  bool _isSavingAudio = false; //บันทึกไฟล์เสียง
  final double thresholdDb = 40.0; //ค่าเสียงที่ตั้งไว้ หากเกินจะเริ่มบันทึกเสียง
  final double silenceThreshold = 35.0;
  NoiseReading? _latestReading;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  NoiseMeter? _noiseMeter; //ใช้ในการตรวจเสียงรบกวน
  late DateTime _startTime = DateTime.now();
  final Duration recordDuration = Duration(
    seconds: 15,
  ); //ตั้งเวลาในการบันทึก เริ่ม 15 วินาที และ หยุด ภายใน 3 วินาทีหากไม่มีเสียงดัง
  final FlutterSoundRecorder _recorder =
      FlutterSoundRecorder(); //บันทึกเสียงที่ตรวจจับได้
  final FlutterSoundPlayer _player =
      FlutterSoundPlayer(); //่เล่นเสียงที่บันทึกมาได้

  // ตัวแปรสำหรับการจัดการบันทึกเสียง
  Timer? _recordingTimer; //ตัวจับเวลาเมื่อเริ่มบันทึก ตั้งไว้ 15 วินาที
  Timer? _silenceTimer; //ตัวจับเวลาเมื่อเสียงเงียบที่ 3 วินาที
  String? _currentRecordingPath;
  List<SoundRecord> _soundRecords = []; //เอาไว้เก็บไฟล์เสียงที่บันทึกได้และไปแสดงเป็นลิสต์ลองฟังเสียงที่บันทึกมา
  int _soundEventCount = 0; //ไว้นับจำนวนเหตุการณ์ของเสียง
  DateTime? _lastSoundTime;
  DateTime? _currentRecordingStart;
  double _currentRecordingMaxDb = 0.0;

  // ตัวแปรสำหรับสถิติ เอาไว้แสดงให้เห็นค่าเสียงเฉยๆ
  double _maxDecibel = 0.0;
  double _avgDecibel = 0.0;
  List<double> _decibelHistory = [];

  // ตัวแปรสำหรับการเล่นเสียง
  bool _isPlaying = false;
  String? _currentPlayingPath;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _requestPermission();
    _recorder.openRecorder();
    start(); // เริ่ม NoiseMeter
  }

  Future<void> _initializePlayer() async {
    await _player.openPlayer();
  }

  @override
  void dispose() {
    _stopAllRecording();
    _noiseSubscription?.cancel();
    _recordingTimer?.cancel();
    _silenceTimer?.cancel();
    _recorder.closeRecorder(); //ปิดตอน dispose เท่านั้น
    _player.closePlayer();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    await Permission.microphone.request();
  }

  Future<bool> checkPermission() async => await Permission.microphone.isGranted;

  Future<void> requestPermission() async =>
      await Permission.microphone.request();

  void onData(NoiseReading noiseReading) async {
    setState(() {
      _latestReading = noiseReading;
    });
    _updateStatistics(noiseReading.meanDecibel);

    if (_isSavingAudio && noiseReading.meanDecibel > _currentRecordingMaxDb) {
      _currentRecordingMaxDb = noiseReading.meanDecibel;
    }

    if (noiseReading.meanDecibel > thresholdDb) {
      //ถ้าระดับเสียงเกินกว่ากำหนด เรียกใช้งานเริ่มบันทึกเสียง
      if (!_isSavingAudio) {
        await _startSoundRecording(); //เริ่มการบันทึกเสียงหากไม่ได้ทำการบันทึกอยู่
      }
      _resetSilenceTimer();
    } else if (noiseReading.meanDecibel < silenceThreshold) {
      _startSilenceTimer();
    }
  }

  void _updateStatistics(double decibel) {
    _decibelHistory.add(decibel);
    if (_decibelHistory.length > 1000) {
      _decibelHistory.removeAt(0);
    }
    if (decibel > _maxDecibel) {
      _maxDecibel = decibel;
    }
    _avgDecibel =
        _decibelHistory.reduce((a, b) => a + b) / _decibelHistory.length;
  }

  Future<void> _startSoundRecording() async {
  if (_isSavingAudio) return;
  setState(() {
    _isSavingAudio = true;
    _soundEventCount++;
    _lastSoundTime = DateTime.now();
    _currentRecordingStart = DateTime.now();
    _currentRecordingMaxDb = 0.0;
  });

  print('เริ่มบันทึกเสียงเพราะเสียงเกิน $thresholdDb dB');

  try {
    Directory? appDir = await getExternalStorageDirectory();
    if (appDir == null) throw Exception("ไม่พบ external storage");
    String soundDir = '${appDir.path}/sound_records';
    Directory(soundDir).createSync(recursive: true);

    String timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(":", "_")
        .replaceAll(".", "_");
    String filePath = '$soundDir/sound_$timestamp.m4a';

    await _recorder.startRecorder(
      toFile: filePath,
      codec: Codec.aacMP4,   //ลองใช้ MP4 
      sampleRate: 44100,
      bitRate: 128000,
    );

    _currentRecordingPath = filePath;
    print("เริ่มบันทึกเสียงที่: $filePath");

    _recordingTimer = Timer(recordDuration, () {
      _stopCurrentRecording();
    });
  } catch (e) {
    print("startAudioRecording error: $e");
    setState(() => _isSavingAudio = false);
  }
}


  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
  }

  void _startSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(Duration(seconds: 3), () {
      if (_isSavingAudio) {
        _stopCurrentRecording();
      }
    });
  }
  Future<void> _stopCurrentRecording() async {
    if (!_isSavingAudio) return;

    try {
      await _recorder.stopRecorder();

      if (_currentRecordingPath != null && _currentRecordingStart != null) {
        Duration recordingDuration = DateTime.now().difference(
          _currentRecordingStart!,
        );
        SoundRecord newRecord = SoundRecord(
          filePath: _currentRecordingPath!,
          timestamp: _currentRecordingStart!,
          maxDecibel: _currentRecordingMaxDb,
          duration: recordingDuration,
        );

        setState(() {
          _soundRecords.add(newRecord);
        });
        print("บันทึกไฟล์สำเร็จ: $_currentRecordingPath");
      }

      setState(() {
        _isSavingAudio = false;
        _currentRecordingPath = null;
        _currentRecordingStart = null;
        _currentRecordingMaxDb = 0.0;
      });

      _recordingTimer?.cancel();
      print("หยุดบันทึกเสียงเพราะเสียงเงียบ");
    } catch (e) {
      print("stopCurrentRecording error: $e");
    }
  }

  Future<void> _stopAllRecording() async {
    if (_isSavingAudio) {
      await _stopCurrentRecording();
    }
    _recordingTimer?.cancel();
    _silenceTimer?.cancel();
  }

  Future<void> _playSound(String filePath) async {
    try {
      if (_isPlaying) {
        await _player.stopPlayer();
        setState(() {
          _isPlaying = false;
          _currentPlayingPath = null;
        });
      } else {
        await _player.startPlayer(
          fromURI: filePath,
          codec: Codec.aacMP4, //แก้ Codec ต่างๆ ในการเล่นไฟล์เสียง
        );
        setState(() {
          _isPlaying = true;
          _currentPlayingPath = filePath;
        });

        // หยุดเล่นอัตโนมัติเมื่อเสียงจบ
        _player.onProgress!.listen((event) {
          if (event.position >= event.duration) {
            setState(() {
              _isPlaying = false;
              _currentPlayingPath = null;
            });
          }
        });
      }
    } catch (e) {
      print("เกิดปัญหาในการเล่นเสียง: $e");
    }
  }

  Future<void> _deleteSound(int index) async {
    try {
      SoundRecord record = _soundRecords[index];
      File file = File(record.filePath);
      if (await file.exists()) {
        await file.delete();
      }

      setState(() {
        _soundRecords.removeAt(index);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ลบไฟล์เสียงแล้ว')));
    } catch (e) {
      print("Error deleting sound: $e");
    }
  }

  void onError(Object error) {
    debugPrint('NoiseMeter error: $error');
    stop();
  }

  Future<void> start() async {
    if (!(await checkPermission())) await requestPermission();
    _noiseMeter ??= NoiseMeter();
    _startTime = DateTime.now();
    _noiseSubscription = _noiseMeter?.noise.listen(onData, onError: onError);
    setState(() => _isRecording = true);
  }

  void stop() {
    _stopAllRecording();
    _noiseSubscription?.cancel();
    setState(() => _isRecording = false);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  void _showRecordingsList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'รายการเสียงที่บันทึกได้',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _soundRecords.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.music_note, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'ยังไม่มีเสียงที่บันทึกได้',
                            style: TextStyle(color: Colors.grey, fontSize: 18),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: _soundRecords.length,
                      itemBuilder: (context, index) {
                        SoundRecord record = _soundRecords[index];
                        bool isCurrentlyPlaying =
                            _currentPlayingPath == record.filePath;
                        return Card(
                          color: Colors.grey[800],
                          margin: EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: IconButton(
                              onPressed: () => _playSound(record.filePath),
                              icon: Icon(
                                isCurrentlyPlaying
                                    ? Icons.stop
                                    : Icons.play_arrow,
                                color: isCurrentlyPlaying
                                    ? Colors.red
                                    : Colors.green,
                                size: 32,
                              ),
                            ),
                            title: Text(
                              DateFormat('HH:mm:ss').format(record.timestamp),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ความดัง: ${record.maxDecibel.toStringAsFixed(1)} dB',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                Text(
                                  'ระยะเวลา: ${_formatDuration(record.duration)}',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              onPressed: () => _deleteSound(index),
                              icon: Icon(Icons.delete, color: Colors.red),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStarted = DateFormat('HH:mm').format(_startTime);
    final currentTime = DateTime.now();
    final duration = currentTime.difference(_startTime);
    return Scaffold(
      backgroundColor: Colors.indigo[900],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          "กำลังตรวจจับเสียง",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _showRecordingsList,
            icon: Badge(
              label: Text('${_soundRecords.length}'),
              child: Icon(Icons.list, color: Colors.white),
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "ราตรีสวัสดิ์",
                style: TextStyle(fontSize: 32, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                "เริ่มบันทึกเวลา: $timeStarted",
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                "ระยะเวลา: ${_formatDuration(duration)}",
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 40),

              // ไอคอนไมค์ที่เปลี่ยนสีตามสถานะ
              Icon(
                Icons.mic,
                color: _isSavingAudio ? Colors.red : Colors.white,
                size: 64,
              ),
              const SizedBox(height: 20),

              // แสดงระดับเสียง
              Text(
                'เสียงปัจจุบัน: ${_latestReading?.meanDecibel.toStringAsFixed(1) ?? "--"} dB',
                style: TextStyle(
                  color: (_latestReading?.meanDecibel ?? 0) > thresholdDb
                      ? Colors.red
                      : Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  //ignore: deprecated_member_use
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "เหตุการณ์เสียง:",
                          style: TextStyle(color: Colors.white70),
                        ),
                        Text(
                          "$_soundEventCount ครั้ง",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "เสียงสูงสุด:",
                          style: TextStyle(color: Colors.white70),
                        ),
                        Text(
                          "${_maxDecibel.toStringAsFixed(1)} dB",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "เสียงเฉลี่ย:",
                          style: TextStyle(color: Colors.white70),
                        ),
                        Text(
                          "${_avgDecibel.toStringAsFixed(1)} dB",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "ไฟล์บันทึก:",
                          style: TextStyle(color: Colors.white70),
                        ),
                        Text(
                          "${_soundRecords.length} ไฟล์",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // สถานะการบันทึก
              if (_isSavingAudio)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "กำลังบันทึกเสียง",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _showRecordingsList,
                icon: Badge(
                  label: Text('${_soundRecords.length}'),
                  child: Icon(Icons.list),
                ),
                label: const Text('ดูรายการเสียง'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  stop();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.stop),
                label: const Text('หยุดบันทึก'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
