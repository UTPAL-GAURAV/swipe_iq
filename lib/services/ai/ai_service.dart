import 'dart:typed_data';
import '../../models/evaluation_result.dart';
import '../../models/question.dart';

abstract class AIService {
  Future<EvaluationResult> evaluate({
    required Question question,
    required Uint8List audioBytes,
  });
}
