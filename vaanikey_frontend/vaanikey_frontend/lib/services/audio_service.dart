import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordingPath;

  /// Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Check if currently recording
  Future<bool> isRecording() async {
    return await _audioRecorder.isRecording();
  }

  /// Start recording audio
  Future<bool> startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        final String filePath =
            '${appDocDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: filePath,
        );

        _recordingPath = filePath;
        return true;
      }
      return false;
    } catch (e) {
      print('Error starting recording: $e');
      return false;
    }
  }

  /// Stop recording and return the file
  Future<File?> stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        return File(path);
      }
      return null;
    } catch (e) {
      print('Error stopping recording: $e');
      return null;
    }
  }

  /// Cancel recording without saving
  Future<void> cancelRecording() async {
    try {
      await _audioRecorder.cancel();
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
        _recordingPath = null;
      }
    } catch (e) {
      print('Error canceling recording: $e');
    }
  }

  /// Dispose the recorder
  void dispose() {
    _audioRecorder.dispose();
  }
}
