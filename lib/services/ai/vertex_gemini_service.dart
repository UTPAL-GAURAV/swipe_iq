import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../models/evaluation_result.dart';
import '../../models/question.dart';
import 'ai_service.dart';

class VertexGeminiService implements AIService {
  static const _model = 'gemini-3.8-flash';

  String get _apiKey => dotenv.env['GOOGLE_GEMINI_API_KEY'] ?? '';

  @override
  Future<EvaluationResult> evaluate({
    required Question question,
    required Uint8List audioBytes,
  }) {
    throw UnimplementedError('Use evaluateTranscript instead.');
  }

  Future<EvaluationResult> evaluateTranscript({
    required Question question,
    required String transcript,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
    );

    final prompt = '''
You are a senior software engineer conducting a technical interview for a ${question.level} role.
The candidate answered via voice (transcribed — minor errors possible).

Question: ${question.question}
Candidate's answer: $transcript

SCOPE RULE: Only evaluate concepts the question explicitly asks about. Do NOT penalize for omitting related topics not asked about.

Respond ONLY with valid JSON in this exact format:
{
  "said_well": "bullet points of what was explained correctly, one per line starting with • (empty string if nothing notable). Plain text only, no markdown.",
  "expected_answer": "correct answer as concise bullet points, one per line starting with •, covering only what the question asks. Plain text only, no markdown.",
  "verdict": "PASS or FAIL"
}

PASS if the answer covers the key concepts at ${question.level} depth.
FAIL if core concepts the question directly asks for are missing.
''';

    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
          ],
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
      },
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini error: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final text = (decoded['candidates'] as List)
        .first['content']['parts'].first['text'] as String;

    final jsonStart = text.indexOf('{');
    final jsonEnd = text.lastIndexOf('}') + 1;
    final parsed = jsonDecode(text.substring(jsonStart, jsonEnd)) as Map<String, dynamic>;

    return EvaluationResult(
      transcript: transcript,
      saidWell: parsed['said_well'] as String,
      expectedAnswer: parsed['expected_answer'] as String,
      verdict: (parsed['verdict'] as String).toUpperCase() == 'PASS'
          ? Verdict.pass
          : Verdict.fail,
    );
  }
}

