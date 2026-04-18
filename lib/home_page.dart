import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:torch_light/torch_light.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:noise_meter/noise_meter.dart';
import 'sound_service.dart';
import 'painters.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  double _threshold = 70.0;
  String? _audioFilePath;
  bool _isServiceRunning = false;
  double _currentDb = 0.0;

  // Feature toggles
  bool _flashEnabled = true;
  bool _musicEnabled = true;

  // Lullaby config
  double _lullabyVolume = 1.0;
  AudioPlayer? _localAudioPlayer;

  DateTime? _firstExceedTime;
  DateTime? _lastExceedTime;
  bool _isAlarmPlaying = false;

  // In-app noise monitoring
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;

  late AnimationController _starController;
  late AnimationController _pulseController;
  late AnimationController _meterGlowController;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initForegroundTask();

    // Start in-app noise monitoring for the dB meter
    _startInAppListening();

    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _meterGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  void _startInAppListening() {
    try {
      _noiseMeter = NoiseMeter();
      _noiseSubscription = _noiseMeter!.noise.listen((NoiseReading reading) {
        setState(() {
          _currentDb = reading.meanDecibel;
        });

        // Alarm logic directly in main isolate while safe mode is ON
        if (_isServiceRunning) {
          if (reading.meanDecibel >= _threshold) {
             if (_firstExceedTime == null) {
                _firstExceedTime = DateTime.now();
             }
             _lastExceedTime = DateTime.now();

             if (DateTime.now().difference(_firstExceedTime!).inSeconds >= 2) {
               _fireAlarm();
               _firstExceedTime = null;
               _lastExceedTime = null;
             }
          } else {
             if (_lastExceedTime != null && DateTime.now().difference(_lastExceedTime!).inSeconds >= 1) {
                _firstExceedTime = null;
                _lastExceedTime = null;
             }
          }
        }
      });
    } catch (e) {
      debugPrint('Noise meter error: $e');
    }
  }

  void _stopInAppListening() {
    _noiseSubscription?.cancel();
    _noiseSubscription = null;
  }

  @override
  void dispose() {
    _stopInAppListening();
    _starController.dispose();
    _pulseController.dispose();
    _meterGlowController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.microphone,
      Permission.camera,
      Permission.notification,
    ].request();
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
    setState(() {
      _isServiceRunning = false;
    });
    _stopAlert();
    _firstExceedTime = null;
    _lastExceedTime = null;
  }

  Future<void> _pickAudioFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
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
    _fireAlarm();
  }

  Future<void> _fireAlarm() async {
    if (_isAlarmPlaying) return;
    _isAlarmPlaying = true;
    _stopAlert(); // Stop any currently playing alert first

    if (_flashEnabled) {
      try {
        if (await TorchLight.isTorchAvailable()) {
          await TorchLight.enableTorch();
        }
      } catch (_) {}
    }

    if (_musicEnabled && _audioFilePath != null) {
      _localAudioPlayer = AudioPlayer();
      await _localAudioPlayer!.setVolume(_lullabyVolume);
      await _localAudioPlayer!.setReleaseMode(ReleaseMode.loop);
      await _localAudioPlayer!.play(DeviceFileSource(_audioFilePath!));
      // It loops infinitely, so we don't clear the alarm until user clicks Stop
    } else {
      // Just keep playing indefinitely without music (flash only)
    }
  }

  Future<void> _stopAlert() async {
    try { await _localAudioPlayer?.stop(); } catch (_) {}
    try { await TorchLight.disableTorch(); } catch (_) {}
    _isAlarmPlaying = false;
  }

  void _syncToggles() {
    if (_isServiceRunning) {
      FlutterForegroundTask.saveData(key: 'flashEnabled', value: _flashEnabled);
      FlutterForegroundTask.saveData(key: 'musicEnabled', value: _musicEnabled);
      FlutterForegroundTask.saveData(key: 'lullabyVolume', value: _lullabyVolume);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFE8D5F5),
                Color(0xFFFFE0EC),
                Color(0xFFFFF0E6),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _starController,
                    builder: (context, _) => CustomPaint(
                      painter: StarFieldPainter(
                        animationValue: _starController.value,
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildSoundMeter(),
                      const SizedBox(height: 28),
                      _buildSensitivityCard(),
                      const SizedBox(height: 16),
                      _buildFeatureTogglesCard(),
                      const SizedBox(height: 16),
                      _buildLullabyCard(),
                      const SizedBox(height: 16),
                      _buildVolumeCard(),
                      const SizedBox(height: 16),
                      _buildAlertButtonsRow(),
                      const SizedBox(height: 32),
                      _buildSafeModeToggle(),
                      const SizedBox(height: 24),
                      Text(
                        'Created by Abdelwahed Abdellaoui',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF9E9E9E),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text('🌙', style: TextStyle(fontSize: 36)),
        const SizedBox(height: 4),
        Text(
          'Babysleeper',
          style: GoogleFonts.nunito(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF5C3D8F),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            _isServiceRunning ? 'Monitoring… 💤' : 'Standby ✨',
            key: ValueKey(_isServiceRunning),
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _isServiceRunning
                  ? const Color(0xFF66BB6A)
                  : const Color(0xFF9E9E9E),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSoundMeter() {
    final normalizedLevel = (_currentDb / 100.0).clamp(0.0, 1.0);

    return SizedBox(
      width: 200,
      height: 200,
      child: AnimatedBuilder(
        animation: _meterGlowController,
        builder: (context, child) => Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(200, 200),
              painter: SoundMeterPainter(
                level: normalizedLevel,
                maxDb: 100,
                currentDb: _currentDb,
                glowAnimation: _meterGlowController.value,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_currentDb.toInt()}',
                  style: GoogleFonts.nunito(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF5C3D8F),
                  ),
                ),
                Text(
                  'dB',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF9575CD),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC9B1FF).withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSensitivityCard() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🔊', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    'Noise Sensitivity',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF5C3D8F),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC9B1FF).withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_threshold.toInt()} dB',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF5C3D8F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 8,
              activeTrackColor: const Color(0xFFC9B1FF),
              inactiveTrackColor: const Color(0xFFC9B1FF).withOpacity(0.2),
              thumbColor: const Color(0xFFFFF8E7),
              thumbShape: const _StarThumbShape(),
              overlayColor: const Color(0xFFC9B1FF).withOpacity(0.2),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            ),
            child: Slider(
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
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('30 dB', style: GoogleFonts.nunito(fontSize: 12, color: const Color(0xFF9E9E9E))),
              Text('100 dB', style: GoogleFonts.nunito(fontSize: 12, color: const Color(0xFF9E9E9E))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTogglesCard() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alert Options',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF5C3D8F),
            ),
          ),
          const SizedBox(height: 8),
          // Flash toggle
          _buildToggleRow(
            emoji: '🔦',
            label: 'Flash Light',
            subtitle: _flashEnabled ? 'Flash will blink on alert' : 'Flash disabled',
            value: _flashEnabled,
            activeColor: const Color(0xFFFFB74D),
            onChanged: (val) {
              setState(() => _flashEnabled = val);
              _syncToggles();
            },
          ),
          Divider(color: const Color(0xFFC9B1FF).withOpacity(0.2), height: 16),
          // Music toggle
          _buildToggleRow(
            emoji: '🎶',
            label: 'Lullaby Music',
            subtitle: _musicEnabled ? 'Music will play on alert' : 'Music disabled',
            value: _musicEnabled,
            activeColor: const Color(0xFFFFB6C1),
            onChanged: (val) {
              setState(() => _musicEnabled = val);
              _syncToggles();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String emoji,
    required String label,
    required String subtitle,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: value ? activeColor.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF5C3D8F),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: const Color(0xFF9E9E9E),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: activeColor,
          activeTrackColor: activeColor.withOpacity(0.3),
          inactiveThumbColor: const Color(0xFFBDBDBD),
          inactiveTrackColor: const Color(0xFFE0E0E0),
        ),
      ],
    );
  }

  Widget _buildLullabyCard() {
    return GestureDetector(
      onTap: _pickAudioFile,
      child: _buildGlassCard(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB6C1), Color(0xFFC9B1FF)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('🎵', style: TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Lullaby',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF5C3D8F),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _audioFilePath != null
                        ? _audioFilePath!.split('/').last
                        : 'Tap to choose a soothing audio ✨',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: _audioFilePath != null
                          ? const Color(0xFF66BB6A)
                          : const Color(0xFF9E9E9E),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              _audioFilePath != null ? Icons.check_circle : Icons.chevron_right,
              color: _audioFilePath != null
                  ? const Color(0xFF66BB6A)
                  : const Color(0xFFC9B1FF),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeCard() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🔈', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    'Lullaby Volume',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF5C3D8F),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB6C1).withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(_lullabyVolume * 100).toInt()}%',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF5C3D8F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 8,
              activeTrackColor: const Color(0xFFFFB6C1),
              inactiveTrackColor: const Color(0xFFFFB6C1).withOpacity(0.2),
              thumbColor: const Color(0xFFFFF8E7),
              thumbShape: const _StarThumbShape(),
              overlayColor: const Color(0xFFFFB6C1).withOpacity(0.2),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            ),
            child: Slider(
              value: _lullabyVolume,
              min: 0.0,
              max: 1.0,
              onChanged: (value) {
                setState(() => _lullabyVolume = value);
                _syncToggles();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertButtonsRow() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _testFlashAndSound,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC9B1FF), Color(0xFFFFB6C1)],
                ),
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC9B1FF).withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('✨', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    'Test Alert',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: _stopAlert,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: const Color(0xFFFFB6C1), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB6C1).withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🛑', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    'Stop Alert',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFFB6C1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSafeModeToggle() {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            if (_isServiceRunning) {
              _stopForegroundTask();
            } else {
              _startForegroundTask();
            }
          },
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final pulseScale = _isServiceRunning
                  ? 1.0 + _pulseController.value * 0.08
                  : 1.0;
              return Transform.scale(
                scale: pulseScale,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _isServiceRunning
                          ? [const Color(0xFF81C784), const Color(0xFF66BB6A)]
                          : [const Color(0xFFE0D6F2), const Color(0xFFC9B1FF)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isServiceRunning
                            ? const Color(0xFF66BB6A).withOpacity(0.4 + _pulseController.value * 0.2)
                            : const Color(0xFFC9B1FF).withOpacity(0.3),
                        blurRadius: _isServiceRunning ? 24 + _pulseController.value * 12 : 16,
                        spreadRadius: _isServiceRunning ? _pulseController.value * 4 : 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _isServiceRunning ? '😴' : '🌙',
                        key: ValueKey(_isServiceRunning),
                        style: const TextStyle(fontSize: 38),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Safe Mode',
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF5C3D8F),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            _isServiceRunning
                ? 'Your baby is protected 💤'
                : 'Tap to start monitoring',
            key: ValueKey(_isServiceRunning),
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _isServiceRunning
                  ? const Color(0xFF66BB6A)
                  : const Color(0xFF9E9E9E),
            ),
          ),
        ),
      ],
    );
  }
}

/// A custom star-shaped slider thumb
class _StarThumbShape extends SliderComponentShape {
  const _StarThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(24, 24);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    final glowPaint = Paint()
      ..color = const Color(0xFFC9B1FF).withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, 14, glowPaint);

    final basePaint = Paint()
      ..color = const Color(0xFFFFF8E7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 11, basePaint);

    final starPaint = Paint()
      ..color = const Color(0xFFC9B1FF)
      ..style = PaintingStyle.fill;
    _drawStar(canvas, center, 7, starPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFFC9B1FF).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, 11, borderPaint);
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final angle = (i * pi / 2) - pi / 4;
      final outerX = center.dx + cos(angle) * size;
      final outerY = center.dy + sin(angle) * size;
      final innerAngle = angle + pi / 4;
      final innerX = center.dx + cos(innerAngle) * size * 0.35;
      final innerY = center.dy + sin(innerAngle) * size * 0.35;
      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(innerX, innerY);
    }
    path.close();
    canvas.drawPath(path, paint);
  }
}
