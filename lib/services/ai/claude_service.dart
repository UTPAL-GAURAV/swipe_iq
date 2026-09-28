import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../models/evaluation_result.dart';
import '../../models/question.dart';
import 'ai_service.dart';

class ClaudeService implements AIService {
  static const _model = 'claude-haiku-4-5-20251001';
  static const _apiUrl = 'https://api.anthropic.com/v1/messages';

  String get _apiKey => dotenv.env['ANTHROPIC_API_KEY'] ?? '';

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

    final response = await http
        .post(
          Uri.parse(_apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': _apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode({
            'model': _model,
            'max_tokens': 1024,
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('Claude error: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final text = (decoded['content'] as List).first['text'] as String;

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
