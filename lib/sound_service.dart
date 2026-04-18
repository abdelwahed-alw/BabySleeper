import 'dart:async';
import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:torch_light/torch_light.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SoundTaskHandler());
}

class SoundTaskHandler extends TaskHandler {
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isPlaying = false;
  DateTime? _firstExceedTime;
  
  double threshold = 70.0;
  String? audioFilePath;

  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Read shared data
    final thresholdData = await FlutterForegroundTask.getData<double>(key: 'threshold');
    if (thresholdData != null) threshold = thresholdData;
    
    final audioData = await FlutterForegroundTask.getData<String>(key: 'audioFilePath');
    if (audioData != null) audioFilePath = audioData;

    try {
      _noiseMeter = NoiseMeter();
      _noiseSubscription = _noiseMeter?.noise.listen(onData);
    } catch (err) {
      debugPrint("Noise meter init error: $err");
    }
  }

  void onData(NoiseReading noiseReading) async {
    // Send data to main isolate so UI can show visual feedback
    FlutterForegroundTask.sendDataToMain(noiseReading.meanDecibel);

    if (noiseReading.meanDecibel >= threshold) {
      if (_firstExceedTime == null) {
        _firstExceedTime = DateTime.now();
      } else {
        if (DateTime.now().difference(_firstExceedTime!).inSeconds >= 2) {
          _triggerAlarm();
          _firstExceedTime = null; 
        }
      }
    } else {
      _firstExceedTime = null;
    }
  }
  
  Future<void> _triggerAlarm() async {
    if (_isPlaying) return;
    _isPlaying = true;
    
    try {
      if (await TorchLight.isTorchAvailable()) {
        await TorchLight.enableTorch();
      }
    } catch (_) {}

    try {
      if (audioFilePath != null && audioFilePath!.isNotEmpty) {
        await _audioPlayer.play(DeviceFileSource(audioFilePath!));
        _audioPlayer.onPlayerComplete.listen((_) async {
          _isPlaying = false;
          try { await TorchLight.disableTorch(); } catch (_) {}
        });
      } else {
        // Fallback if no audio file is selected 
        await Future.delayed(const Duration(seconds: 3));
        _isPlaying = false;
        try { await TorchLight.disableTorch(); } catch (_) {}
      }
    } catch (_) {
      _isPlaying = false;
      try { await TorchLight.disableTorch(); } catch (_) {}
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // We cannot easily do async here without starting a microtask, but since getData returns
    // a Future, we can handle it this way:
    FlutterForegroundTask.getData<double>(key: 'threshold').then((th) {
      if (th != null) threshold = th;
    });
  }

  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _noiseSubscription?.cancel();
    _audioPlayer.dispose();
    try { await TorchLight.disableTorch(); } catch (_) {}
  }
  
  void onReceiveData(Object data) {
  }
}
