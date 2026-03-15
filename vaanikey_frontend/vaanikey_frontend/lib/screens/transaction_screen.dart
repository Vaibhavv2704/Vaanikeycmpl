import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'liveness_screen.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({Key? key}) : super(key: key);

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final TextEditingController _nameController = TextEditingController(); // ADDED BACK
  final stt.SpeechToText _speech = stt.SpeechToText();
  
  bool _isListening = false;
  String _spokenText = "Tap the mic and say something like: 'Send 500 to John'";
  bool _isProcessing = false;
  
  String? _extractedAmount;
  String? _extractedReceiver;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    await _speech.initialize();
    setState(() {});
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _spokenText = "Listening...";
        });
        _speech.listen(onResult: (val) => setState(() => _spokenText = val.recognizedWords));
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _processTransaction() async {
    final senderName = _nameController.text.trim();
    if (senderName.isEmpty) {
      _showSnackBar('Please enter your name first', isError: true);
      return;
    }
    if (_spokenText.isEmpty || _spokenText.contains("Tap the mic")) {
      _showSnackBar('Please speak your transaction request', isError: true);
      return;
    }

    setState(() => _isProcessing = true);
    final result = await ApiService.processText(_spokenText);
    setState(() => _isProcessing = false);

    if (result['success']) {
      setState(() {
        _extractedAmount = result['amount'].toString();
        _extractedReceiver = result['receiver'];
      });
      
      // Auto-navigate to verification
      _proceedToLivenessCheck();
    } else {
      _showSnackBar(result['error'] ?? 'Failed to parse request', isError: true);
    }
  }

  void _proceedToLivenessCheck() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LivenessScreen(
          userName: _nameController.text.trim(), // Who is sending (for voice match)
          amount: _extractedAmount ?? '0',
          receiver: _extractedReceiver ?? 'Unknown',
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Transaction')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Step 1: Identity", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Your Name (Account Holder)',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 30),
            const Text("Step 2: Voice Command", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(_spokenText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 20),
                    IconButton(
                      icon: Icon(_isListening ? Icons.stop : Icons.mic, size: 40, color: _isListening ? Colors.red : Colors.blue),
                      onPressed: _listen,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            if (_extractedAmount != null) ...[
              Text("Summary: ₹$_extractedAmount to $_extractedReceiver", 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 20),
            ],
            ElevatedButton(
              onPressed: _isProcessing ? null : _processTransaction,
              child: _isProcessing ? const CircularProgressIndicator(color: Colors.white) : const Text("Verify & Pay"),
            ),
          ],
        ),
      ),
    );
  }
}