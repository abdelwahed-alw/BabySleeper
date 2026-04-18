import 'dart:async';
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
  bool flashEnabled = true;
  bool musicEnabled = true;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Read shared data
    final thresholdData = await FlutterForegroundTask.getData<double>(key: 'threshold');
    if (thresholdData != null) threshold = thresholdData;
    
    final audioData = await FlutterForegroundTask.getData<String>(key: 'audioFilePath');
    if (audioData != null) audioFilePath = audioData;

    final flashData = await FlutterForegroundTask.getData<bool>(key: 'flashEnabled');
    if (flashData != null) flashEnabled = flashData;

    final musicData = await FlutterForegroundTask.getData<bool>(key: 'musicEnabled');
    if (musicData != null) musicEnabled = musicData;

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
    
    // Flash only if enabled
    if (flashEnabled) {
      try {
        if (await TorchLight.isTorchAvailable()) {
          await TorchLight.enableTorch();
        }
      } catch (_) {}
    }

    // Music only if enabled
    try {
      if (musicEnabled && audioFilePath != null && audioFilePath!.isNotEmpty) {
        await _audioPlayer.play(DeviceFileSource(audioFilePath!));
        _audioPlayer.onPlayerComplete.listen((_) async {
          _isPlaying = false;
          if (flashEnabled) {
            try { await TorchLight.disableTorch(); } catch (_) {}
          }
        });
      } else {
        // Fallback if no audio file is selected or music disabled
        await Future.delayed(const Duration(seconds: 3));
        _isPlaying = false;
        if (flashEnabled) {
          try { await TorchLight.disableTorch(); } catch (_) {}
        }
      }
    } catch (_) {
      _isPlaying = false;
      if (flashEnabled) {
        try { await TorchLight.disableTorch(); } catch (_) {}
      }
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    FlutterForegroundTask.getData<double>(key: 'threshold').then((th) {
      if (th != null) threshold = th;
    });
    FlutterForegroundTask.getData<bool>(key: 'flashEnabled').then((v) {
      if (v != null) flashEnabled = v;
    });
    FlutterForegroundTask.getData<bool>(key: 'musicEnabled').then((v) {
      if (v != null) musicEnabled = v;
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _noiseSubscription?.cancel();
    _audioPlayer.dispose();
    try { await TorchLight.disableTorch(); } catch (_) {}
  }
  
  @override
  void onReceiveData(Object data) {
  }
}
