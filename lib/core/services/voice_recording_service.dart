import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class VoiceRecordingService {
  final AudioRecorder _record = AudioRecorder();
  Timer? _timer;
  
  // State variables
  final List<String> _segments = [];
  int _accumulatedDuration = 0;
  int _currentSegmentDuration = 0;
  bool _isPaused = false;

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

    // Reset everything for a fresh recording session
    _segments.clear();
    _accumulatedDuration = 0;
    _currentSegmentDuration = 0;
    _isPaused = false;

    await _startNewSegment();
    _isRecordingController.add(true);
  }

  Future<void> _startNewSegment() async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final segmentPath = '${tempDir.path}/voice_seg_$timestamp.wav';

    // Record in raw PCM 16-bit Mono at 16000Hz for high quality, compact size, and simple concatenation
    await _record.start(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: segmentPath,
    );

    _currentSegmentDuration = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      _currentSegmentDuration++;
      _durationController.add(_accumulatedDuration + _currentSegmentDuration);
    });
  }

  Future<void> pauseRecording() async {
    if (_isPaused) return;
    _timer?.cancel();
    
    final path = await _record.stop();
    if (path != null) {
      _segments.add(path);
    }
    
    _accumulatedDuration += _currentSegmentDuration;
    _currentSegmentDuration = 0;
    _isPaused = true;
    _isRecordingController.add(false);
  }

  Future<void> resumeRecording() async {
    if (!_isPaused) return;
    _isPaused = false;
    await _startNewSegment();
    _isRecordingController.add(true);
  }

  Future<String?> stopRecording() async {
    _timer?.cancel();
    
    // Stop active recorder if running
    if (!_isPaused) {
      final path = await _record.stop();
      if (path != null) {
        _segments.add(path);
      }
      _accumulatedDuration += _currentSegmentDuration;
    }

    _isRecordingController.add(false);

    if (_segments.isEmpty) return null;

    // Merge all segments into a single WAV file
    try {
      final mergedPath = await _mergeSegments();
      await _cleanSegments();
      return mergedPath;
    } catch (e) {
      debugPrint('Failed to merge WAV segments: $e');
      // Fallback: return the first segment if merging fails
      return _segments.first;
    }
  }

  Future<void> cancelRecording() async {
    _timer?.cancel();
    
    // Stop active recorder if running
    try {
      await _record.stop();
    } catch (_) {}

    _isRecordingController.add(false);
    await _cleanSegments();
    
    _accumulatedDuration = 0;
    _currentSegmentDuration = 0;
    _isPaused = false;
  }

  Future<bool> isRecording() async {
    return await _record.isRecording();
  }

  bool isRecordingPaused() => _isPaused;

  Stream<Amplitude> onAmplitudeChanged() {
    return _record.onAmplitudeChanged(const Duration(milliseconds: 100));
  }

  /// Clean up segment files
  Future<void> _cleanSegments() async {
    for (final path in _segments) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Failed to delete segment file: $e');
      }
    }
    _segments.clear();
  }

  /// Merges all PCM/WAV segments into a single correct WAV file
  Future<String> _mergeSegments() async {
    if (_segments.length == 1) {
      // If only one segment, we still copy it to a final voice file
      final tempDir = await getTemporaryDirectory();
      final finalPath = '${tempDir.path}/voice_merged_${DateTime.now().millisecondsSinceEpoch}.wav';
      await File(_segments.first).copy(finalPath);
      return finalPath;
    }

    final List<int> totalPcmBytes = [];
    
    for (final path in _segments) {
      final file = File(path);
      final bytes = await file.readAsBytes();
      // Skip the 44-byte WAV header of each segment to extract raw PCM data
      if (bytes.length > 44) {
        totalPcmBytes.addAll(bytes.sublist(44));
      }
    }

    // Generate a single 44-byte WAV header for the entire PCM data size
    // RecordConfig: 16000Hz, 16 bits per sample, 1 channel (mono)
    final header = _createWavHeader(totalPcmBytes.length, 16000, 16, 1);

    final tempDir = await getTemporaryDirectory();
    final mergedPath = '${tempDir.path}/voice_merged_${DateTime.now().millisecondsSinceEpoch}.wav';
    final mergedFile = File(mergedPath);
    
    // Write header followed by raw PCM bytes
    await mergedFile.writeAsBytes([...header, ...totalPcmBytes]);
    return mergedPath;
  }

  /// Creates a standard 44-byte RIFF WAV header
  List<int> _createWavHeader(int pcmLength, int sampleRate, int bitsPerSample, int numChannels) {
    final header = List<int>.filled(44, 0);
    
    // "RIFF"
    header[0] = 0x52; header[1] = 0x49; header[2] = 0x46; header[3] = 0x46;
    
    // ChunkSize (pcmLength + 36)
    final chunkSize = pcmLength + 36;
    header[4] = chunkSize & 0xff;
    header[5] = (chunkSize >> 8) & 0xff;
    header[6] = (chunkSize >> 16) & 0xff;
    header[7] = (chunkSize >> 24) & 0xff;
    
    // "WAVE"
    header[8] = 0x57; header[9] = 0x41; header[10] = 0x56; header[11] = 0x45;
    
    // "fmt "
    header[12] = 0x66; header[13] = 0x6d; header[14] = 0x74; header[15] = 0x20;
    
    // Subchunk1Size (16)
    header[16] = 16; header[17] = 0; header[18] = 0; header[19] = 0;
    
    // AudioFormat (1 for PCM)
    header[20] = 1; header[21] = 0;
    
    // NumChannels
    header[22] = numChannels; header[23] = 0;
    
    // SampleRate
    header[24] = sampleRate & 0xff;
    header[25] = (sampleRate >> 8) & 0xff;
    header[26] = (sampleRate >> 16) & 0xff;
    header[27] = (sampleRate >> 24) & 0xff;
    
    // ByteRate (SampleRate * NumChannels * BitsPerSample/8)
    final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    header[28] = byteRate & 0xff;
    header[29] = (byteRate >> 8) & 0xff;
    header[30] = (byteRate >> 16) & 0xff;
    header[31] = (byteRate >> 24) & 0xff;
    
    // BlockAlign (NumChannels * BitsPerSample/8)
    final blockAlign = numChannels * (bitsPerSample ~/ 8);
    header[32] = blockAlign; header[33] = 0;
    
    // BitsPerSample
    header[34] = bitsPerSample; header[35] = 0;
    
    // "data"
    header[36] = 0x64; header[37] = 0x61; header[38] = 0x74; header[39] = 0x61;
    
    // Subchunk2Size (pcmLength)
    header[40] = pcmLength & 0xff;
    header[41] = (pcmLength >> 8) & 0xff;
    header[42] = (pcmLength >> 16) & 0xff;
    header[43] = (pcmLength >> 24) & 0xff;
    
    return header;
  }

  void dispose() {
    _timer?.cancel();
    _record.dispose();
    _durationController.close();
    _isRecordingController.close();
  }
}
