import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/audio_service.dart';
import '../services/api_service.dart';

class LivenessScreen extends StatefulWidget {
  final String userName;
  final String amount;
  final String receiver;

  const LivenessScreen({
    Key? key,
    required this.userName,
    required this.amount,
    required this.receiver,
  }) : super(key: key);

  @override
  State<LivenessScreen> createState() => _LivenessScreenState();
}

class _LivenessScreenState extends State<LivenessScreen> {
  final AudioService _audioService = AudioService();
  final FlutterTts _flutterTts = FlutterTts();
  
  String? _challengeText;
  bool _isLoadingChallenge = true;
  bool _isRecording = false;
  bool _isVerifying = false;
  File? _challengeRecording;
  
  String _recordingDuration = '0:00';
  int _recordingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _generateAndSpeakChallenge();
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _generateAndSpeakChallenge() async {
    setState(() => _isLoadingChallenge = true);
    
    final result = await ApiService.generateChallenge(widget.userName);
    
    if (result['success']) {
      setState(() {
        _challengeText = result['challenge'];
        _isLoadingChallenge = false;
      });
      
      // Speak the challenge
      await Future.delayed(const Duration(milliseconds: 500));
      await _speakChallenge();
    } else {
      setState(() => _isLoadingChallenge = false);
      _showSnackBar(result['error'] ?? 'Failed to generate challenge', isError: true);
    }
  }

  Future<void> _speakChallenge() async {
    if (_challengeText != null) {
      await _flutterTts.speak(_challengeText!);
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
        setState(() => _challengeRecording = file);
        _showSnackBar('Recording saved successfully');
      } else {
        _showSnackBar('Failed to save recording', isError: true);
      }
    } else {
      // Start recording
      setState(() {
        _challengeRecording = null;
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

  Future<void> _verifyAndProcessTransaction() async {
    if (_challengeRecording == null) {
      _showSnackBar('Please record the challenge phrase', isError: true);
      return;
    }

    setState(() => _isVerifying = true);

    // Step 1: Verify liveness
    final livenessResult = await ApiService.verifyLiveness(
      name: widget.userName,
      audioFile: _challengeRecording!,
    );

    if (!livenessResult['success'] || !livenessResult['match']) {
      setState(() => _isVerifying = false);
      _showFailureDialog('Liveness Check Failed', 
        'The spoken phrase does not match the challenge. Please try again.');
      return;
    }

    // Step 2: Verify voice
    final voiceResult = await ApiService.verifyVoice(
      name: widget.userName,
      audioFile: _challengeRecording!,
    );

    setState(() => _isVerifying = false);

    if (voiceResult['success'] && voiceResult['match']) {
      _showSuccessDialog();
    } else {
      _showFailureDialog('Voice Verification Failed', 
        'Your voice does not match the enrolled profile. Transaction declined.');
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
            Text('Transaction Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your transaction has been completed successfully.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Amount:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('₹${widget.amount}', style: const TextStyle(fontSize: 18)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('To:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(widget.receiver, style: const TextStyle(fontSize: 18)),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to transaction screen
              Navigator.of(context).pop(); // Go back to home screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showFailureDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 32),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Try Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to transaction screen
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Transaction'),
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
    _audioService.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liveness Verification'),
      ),
      body: _isLoadingChallenge
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon
                  Icon(
                    Icons.security,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 24),

                  // Info text
                  const Text(
                    'Security Verification',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please repeat the phrase below to verify your identity',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),

                  // Challenge card
                  Card(
                    color: Colors.amber.shade50,
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Challenge Phrase:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.volume_up),
                                color: Theme.of(context).primaryColor,
                                onPressed: _speakChallenge,
                                tooltip: 'Replay challenge',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _challengeText ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                            _isRecording ? 'Recording...' : 'Record Your Response',
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
                            onPressed: _isVerifying ? null : _toggleRecording,
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
                          if (_challengeRecording != null) ...[
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

                  // Verify button
                  ElevatedButton(
                    onPressed: _isVerifying || _isRecording ? null : _verifyAndProcessTransaction,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Verify & Complete Transaction',
                            style: TextStyle(fontSize: 18),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
