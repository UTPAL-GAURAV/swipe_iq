import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'google_auth_client.dart';

class SttService {
  static const _pollInterval = Duration(seconds: 3);
  static const _maxWait = Duration(seconds: 180);

  String get _bucket => dotenv.env['GCS_BUCKET_NAME'] ?? '';

  Future<String> transcribe(Uint8List audioBytes) async {
    final client = await GoogleAuthClient.getClient();
    final objectName = 'audio_${DateTime.now().millisecondsSinceEpoch}.wav';
    final gcsUri = 'gs://$_bucket/$objectName';
    bool uploaded = false;

    try {
      // 1. Upload audio to GCS.
      final uploadUrl = Uri.parse(
        'https://storage.googleapis.com/upload/storage/v1/b/$_bucket/o'
        '?uploadType=media&name=$objectName',
      );
      final uploadResponse = await client
          .post(
            uploadUrl,
            headers: {'Content-Type': 'audio/wav'},
            body: audioBytes,
          )
          .timeout(const Duration(seconds: 30));

      if (uploadResponse.statusCode != 200) {
        throw Exception('GCS upload error: ${uploadResponse.statusCode} ${uploadResponse.body}');
      }
      uploaded = true;

      // 2. Start long-running transcription using the GCS URI.
      final sttResponse = await client
          .post(
            Uri.parse('https://speech.googleapis.com/v1/speech:longrunningrecognize'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'config': {
                'encoding': 'LINEAR16',
                'sampleRateHertz': 16000,
                'languageCode': 'en-US',
                'model': 'latest_long',
                'enableAutomaticPunctuation': true,
              },
              'audio': {'uri': gcsUri},
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (sttResponse.statusCode != 200) {
        throw Exception('STT error: ${sttResponse.statusCode} ${sttResponse.body}');
      }

      final opName =
          (jsonDecode(sttResponse.body) as Map<String, dynamic>)['name'] as String;

      // 3. Poll until done or timeout.
      final deadline = DateTime.now().add(_maxWait);
      while (DateTime.now().isBefore(deadline)) {
        await Future.delayed(_pollInterval);

        final pollResponse = await client
            .get(Uri.parse('https://speech.googleapis.com/v1/operations/$opName'))
            .timeout(const Duration(seconds: 60));

        if (pollResponse.statusCode != 200) {
          throw Exception('STT poll error: ${pollResponse.statusCode} ${pollResponse.body}');
        }

        final op = jsonDecode(pollResponse.body) as Map<String, dynamic>;
        if (op['done'] != true) continue;

        if (op['error'] != null) {
          throw Exception('STT failed: ${op['error']}');
        }

        final results = (op['response'] as Map<String, dynamic>)['results'] as List?;
        if (results == null || results.isEmpty) return '';

        return results
            .map((r) {
              final alternatives = r['alternatives'] as List?;
              if (alternatives == null || alternatives.isEmpty) return '';
              return (alternatives.first['transcript'] as String?) ?? '';
            })
            .where((t) => t.isNotEmpty)
            .join(' ')
            .trim();
      }

      throw Exception('STT timed out after ${_maxWait.inSeconds}s');
    } finally {
      // 4. Delete the file from GCS regardless of success or failure.
      if (uploaded) {
        try {
          await client
              .delete(Uri.parse(
                'https://storage.googleapis.com/storage/v1/b/$_bucket/o/${Uri.encodeComponent(objectName)}',
              ))
              .timeout(const Duration(seconds: 10));
        } catch (_) {
          // Non-fatal — lifecycle rule will clean it up within 1 day.
        }
      }
      client.close();
    }
  }
}
