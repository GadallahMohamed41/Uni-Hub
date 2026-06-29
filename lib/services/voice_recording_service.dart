import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class VoiceRecordingService {
  final AudioRecorder _record = AudioRecorder();
  Timer? _timer;
  int _recordDuration = 0;

  // Streams for the UI
  final _durationController = StreamController<int>.broadcast();
  final _isRecordingController = StreamController<bool>.broadcast();

  Stream<int> get durationStream => _durationController.stream;
  Stream<bool> get isRecordingStream => _isRecordingController.stream;

  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  Future<void> startRecording() async {
    final permission = await hasPermission();
    if (!permission) {
      throw Exception('Microphone permission not granted');
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${tempDir.path}/voice_$timestamp.m4a';

    await _record.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
      ),
      path: path,
    );

    _recordDuration = 0;
    _isRecordingController.add(true);

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      _recordDuration++;
      _durationController.add(_recordDuration);
    });
  }

  Future<String?> stopRecording() async {
    _timer?.cancel();
    _isRecordingController.add(false);
    final path = await _record.stop();
    return path;
  }

  Future<void> cancelRecording() async {
    _timer?.cancel();
    _isRecordingController.add(false);
    final path = await _record.stop();
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<bool> isRecording() async {
    return await _record.isRecording();
  }

  Stream<Amplitude> onAmplitudeChanged() {
    return _record.onAmplitudeChanged(const Duration(milliseconds: 100));
  }

  void dispose() {
    _timer?.cancel();
    _record.dispose();
    _durationController.close();
    _isRecordingController.close();
  }
}
