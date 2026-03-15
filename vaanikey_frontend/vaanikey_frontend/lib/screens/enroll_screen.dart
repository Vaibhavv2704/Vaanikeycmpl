import 'dart:io';
import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/api_service.dart';

class EnrollScreen extends StatefulWidget {
  const EnrollScreen({Key? key}) : super(key: key);

  @override
  State<EnrollScreen> createState() => _EnrollScreenState();
}

class _EnrollScreenState extends State<EnrollScreen> {
  final TextEditingController _nameController = TextEditingController();
  final AudioService _audioService = AudioService();
  
  bool _isRecording = false;
  bool _isProcessing = false;
  File? _recordedFile;
  String _recordingDuration = '0:00';
  int _recordingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final hasPermission = await _audioService.requestPermission();
    if (!hasPermission) {
      _showSnackBar('Microphone permission is required', isError: true);
    }
  }

  void _startRecordingTimer() {
    _recordingSeconds = 0;
    Future.doWhile(() async {
      if (!_isRecording) return false;
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _isRecording) {
        setState(() {
          _recordingSeconds++;
          _recordingDuration = '${_recordingSeconds ~/ 60}:${(_recordingSeconds % 60).toString().padLeft(2, '0')}';
        });
      }
      return _isRecording;
    });
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Stop recording
      setState(() => _isRecording = false);
      final file = await _audioService.stopRecording();
      
      if (file != null) {
        setState(() => _recordedFile = file);
        _showSnackBar('Recording saved successfully');
      } else {
        _showSnackBar('Failed to save recording', isError: true);
      }
    } else {
      // Start recording
      setState(() {
        _recordedFile = null;
        _recordingDuration = '0:00';
      });
      
      final started = await _audioService.startRecording();
      if (started) {
        setState(() => _isRecording = true);
        _startRecordingTimer();
      } else {
        _showSnackBar('Failed to start recording', isError: true);
      }
    }
  }

  Future<void> _enrollUser() async {
    final name = _nameController.text.trim();
    
    if (name.isEmpty) {
      _showSnackBar('Please enter your name', isError: true);
      return;
    }
    
    if (_recordedFile == null) {
      _showSnackBar('Please record your voice first', isError: true);
      return;
    }

    setState(() => _isProcessing = true);

    final result = await ApiService.enrollUser(
      name: name,
      audioFile: _recordedFile!,
    );

    setState(() => _isProcessing = false);

    if (result['success']) {
      _showSuccessDialog();
    } else {
      _showSnackBar(result['error'] ?? 'Enrollment failed', isError: true);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Success!'),
          ],
        ),
        content: const Text('Your voice profile has been enrolled successfully.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to home
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enroll User'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon
            Icon(
              Icons.mic,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),

            // Info text
            const Text(
              'Register Your Voice',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your name and record your voice to create a voice profile',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // Name input
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              enabled: !_isProcessing,
            ),
            const SizedBox(height: 32),

            // Recording card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      _isRecording ? 'Recording...' : 'Voice Recording',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Recording animation
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording
                            ? Colors.red.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
                      ),
                      child: Center(
                        child: Icon(
                          _isRecording ? Icons.mic : Icons.mic_none,
                          size: 50,
                          color: _isRecording ? Colors.red : Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Duration
                    Text(
                      _recordingDuration,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _isRecording ? Colors.red : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Record button
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _toggleRecording,
                      icon: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record),
                      label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRecording ? Colors.red : Colors.blue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                    
                    // Recording status
                    if (_recordedFile != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'Recording saved',
                            style: TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Enroll button
            ElevatedButton(
              onPressed: _isProcessing || _isRecording ? null : _enrollUser,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Enroll',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
