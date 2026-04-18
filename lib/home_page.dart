import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:torch_light/torch_light.dart';
import 'package:audioplayers/audioplayers.dart';
import 'sound_service.dart';
import 'dart:isolate';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double _threshold = 70.0;
  String? _audioFilePath;
  bool _isServiceRunning = false;
  double _currentDb = 0.0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initForegroundTask();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.microphone,
      Permission.camera,
      Permission.notification,
    ].request();
    
    // Some versions of android require extra checking for foreground service.
    // In production, robust checks are recommended here.
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'babysleeper_foreground',
        channelName: 'Babysleeper Service',
        channelDescription: 'Monitors audio levels in the background.',
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  void _startForegroundTask() async {
    await FlutterForegroundTask.saveData(key: 'threshold', value: _threshold);
    if (_audioFilePath != null) {
      await FlutterForegroundTask.saveData(key: 'audioFilePath', value: _audioFilePath!);
    }

    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.restartService();
    } else {
      FlutterForegroundTask.startService(
        notificationTitle: 'Babysleeper is watching your baby',
        notificationText: 'Monitoring sound levels...',
        callback: startCallback,
      );
    }
    setState(() => _isServiceRunning = true);
  }

  void _stopForegroundTask() async {
    await FlutterForegroundTask.stopService();
    setState(() => _isServiceRunning = false);
  }

  Future<void> _pickAudioFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _audioFilePath = result.files.single.path;
      });
      if (_isServiceRunning) {
        FlutterForegroundTask.saveData(key: 'audioFilePath', value: _audioFilePath!);
      }
    }
  }

  Future<void> _testFlashAndSound() async {
    try {
      if (await TorchLight.isTorchAvailable()) {
        await TorchLight.enableTorch();
      }
    } catch (_) {}

    if (_audioFilePath != null) {
      final player = AudioPlayer();
      await player.play(DeviceFileSource(_audioFilePath!));
      player.onPlayerComplete.listen((_) async {
        try { await TorchLight.disableTorch(); } catch (_) {}
      });
    } else {
      await Future.delayed(const Duration(seconds: 2));
      try { await TorchLight.disableTorch(); } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Babysleeper'),
          backgroundColor: Colors.blueAccent,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sensitivity: ${_threshold.toInt()} dB',
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              Slider(
                value: _threshold,
                min: 30,
                max: 100,
                onChanged: (value) {
                  setState(() => _threshold = value);
                  if (_isServiceRunning) {
                    FlutterForegroundTask.saveData(key: 'threshold', value: _threshold);
                  }
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.audio_file),
                label: Text(_audioFilePath != null ? 'Audio Selected' : 'Select Audio File'),
                onPressed: _pickAudioFile,
              ),
              if (_audioFilePath != null) 
                Text(_audioFilePath!.split('/').last, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.flash_on),
                label: const Text('Test Flash & Sound'),
                onPressed: _testFlashAndSound,
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Safe Mode', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Switch(
                    value: _isServiceRunning,
                    onChanged: (val) {
                      if (val) {
                        _startForegroundTask();
                      } else {
                        _stopForegroundTask();
                      }
                    },
                    activeColor: Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
