import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class SoundAnalyzer {
  static Interpreter? _interpreter;
  static List<String>? _labels;
  static bool _isInitialized = false;

  final String _modelPath = 'assets/yamnet.tflite';
  final String _labelsPath = 'assets/yamnet_class_map.csv';

  SoundAnalyzer();

  Future<void> init() async {
    if (_isInitialized) {
      return;
    }
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      _labels = await rootBundle.loadString(_labelsPath).then((String contents) {
        return contents.split('\n').where((e) => e.trim().isNotEmpty).toList();
      });
      _isInitialized = true;
      print('✅ Model and labels loaded successfully! (${_labels!.length} labels)');
    } catch (e) {
      print('❌ Failed to load model or labels: $e');
    }
  }

  Future<String> analyzeSound(String audioPath) async {
    if (!_isInitialized) {
      print("❌ Model or labels not initialized.");
      return "unknown";
    }

    try {
      final audioBytes = File(audioPath).readAsBytesSync();
      final input = Float32List(15600);

      for (var i = 0; i < input.length; i++) {
        if (i < audioBytes.length) {
          input[i] = audioBytes[i] / 255.0;
        }
      }

      final output = List.filled(521, 0.0).reshape([1, 521]);
      _interpreter!.run(input.reshape([1, 15600]), output);

      var maxIndex = 0;
      var maxScore = output[0][0];
      for (var i = 1; i < output[0].length; i++) {
        if (output[0][i] > maxScore) {
          maxScore = output[0][i];
          maxIndex = i;
        }
      }

      return _labels![maxIndex];
    } catch (e) {
      print("❌ Error analyzing sound: $e");
      return "unknown";
    }
  }
}