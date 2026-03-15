import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // Update this with your backend URL
  // static const String baseUrl = 'http://10.0.2.2:8000/api'; // For Android emulator
  // static const String baseUrl = 'http://localhost:8000/api'; // For iOS simulator
  static const String baseUrl = 'https://unimputed-unnaovely-reta.ngrok-free.dev/api'; // For physical device


  
  /// Enroll a new user with their voice
  static Future<Map<String, dynamic>> enrollUser({
    required String name,
    required File audioFile,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/enroll/'),
      );

      request.fields['name'] = name;
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          audioFile.path,
        ),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseData);

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonResponse};
      } else {
        return {
          'success': false,
          'error': jsonResponse['error'] ?? 'Enrollment failed'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  /// Process text to extract transaction details
  static Future<Map<String, dynamic>> processText(String text) async {
    try {
      var response = await http.post(
        Uri.parse('$baseUrl/process-text/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'text': text}),
      );

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        
        // Parse the google_analysis field
        var analysisText = jsonResponse['google_analysis'];
        
        // Clean the text and parse JSON
        // var cleanText = analysisText
        //     .replaceAll('```json', '')
        //     .replaceAll('```', '')
        //     .trim();
        
        try {
          var parsedData = json.decode(analysisText);
          return {
            'success': true,
            'amount': parsedData['amount'],
            'receiver': parsedData['receiver']
          };
        } catch (e) {
          // If JSON parsing fails, try to extract manually
          return {
            'success': false,
            'error': 'Could not parse transaction details'
          };
        }
      } else {
        return {'success': false, 'error': 'Failed to process text'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  /// Generate a liveness challenge for a user
  static Future<Map<String, dynamic>> generateChallenge(String name) async {
    try {
      var response = await http.post(
        Uri.parse('$baseUrl/generate-challenge/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name}),
      );

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        return {
          'success': true,
          'challenge': jsonResponse['challenge'],
          'name': jsonResponse['name']
        };
      } else {
        return {'success': false, 'error': 'Failed to generate challenge'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  /// Verify liveness by checking if user spoke the challenge
  static Future<Map<String, dynamic>> verifyLiveness({
    required String name,
    required File audioFile,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/verify-liveness/'),
      );

      request.fields['name'] = name;
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          audioFile.path,
        ),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseData);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'match': jsonResponse['match'],
          'expected': jsonResponse['expected'],
          'transcribed': jsonResponse['transcribed']
        };
      } else {
        return {
          'success': false,
          'error': jsonResponse['error'] ?? 'Liveness verification failed'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  /// Verify user's voice
  static Future<Map<String, dynamic>> verifyVoice({
    required String name,
    required File audioFile,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/verify/'),
      );

      request.fields['name'] = name;
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          audioFile.path,
        ),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseData);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'match': jsonResponse['match'],
          'confidence': jsonResponse['confidence'],
          'threshold': jsonResponse['threshold']
        };
      } else {
        return {
          'success': false,
          'error': jsonResponse['error'] ?? 'Voice verification failed'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }
}
