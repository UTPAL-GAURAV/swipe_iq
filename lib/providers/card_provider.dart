import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../models/evaluation_result.dart';
import '../models/question.dart';
import '../repositories/question_repository.dart';
import '../services/stt_service.dart';
import '../services/ai/claude_service.dart';

final questionRepositoryProvider = Provider<QuestionRepository>(
  (_) => QuestionRepository(),
);

final sttServiceProvider = Provider<SttService>((_) => SttService());
final claudeServiceProvider = Provider<ClaudeService>((_) => ClaudeService());

enum EvaluationPhase { idle, transcribing, evaluating }

class CardState {
  final Question question;
  final String? answer;
  final EvaluationResult? result;
  final EvaluationPhase phase;
  final String? error;

  const CardState({
    required this.question,
    this.answer,
    this.result,
    this.phase = EvaluationPhase.idle,
    this.error,
  });

  bool get isEvaluating => phase != EvaluationPhase.idle;

  CardState copyWith({
    String? answer,
    EvaluationResult? result,
    bool clearResult = false,
    EvaluationPhase? phase,
    String? error,
    bool clearError = false,
  }) =>
      CardState(
        question: question,
        answer: answer ?? this.answer,
        result: clearResult ? null : result ?? this.result,
        phase: phase ?? this.phase,
        error: clearError ? null : error ?? this.error,
      );
}

// Non-AutoDispose family provider — keyed by (slotIndex, question) so each
// page slot has independent state. Non-AutoDispose survives PageView.builder
// removing off-screen pages from the widget tree, preserving answer history.
class CardNotifier extends FamilyNotifier<CardState, (int, Question)> {
  @override
  CardState build((int, Question) arg) => CardState(question: arg.$2);

  Future<void> submitAnswer(Uint8List audioBytes) async {
    try {
      final stt = ref.read(sttServiceProvider);
      final claude = ref.read(claudeServiceProvider);

      state = state.copyWith(phase: EvaluationPhase.transcribing, clearError: true);
      debugPrint('[card] phase → transcribing');
      final transcript = await stt.transcribe(audioBytes);
      debugPrint('[card] transcript received (${transcript.length} chars)');
      if (transcript.isEmpty) {
        state = state.copyWith(
          phase: EvaluationPhase.idle,
          error: 'Could not hear your answer — tap to try again',
        );
        return;
      }

      state = state.copyWith(phase: EvaluationPhase.evaluating);
      debugPrint('[card] phase → evaluating');
      final result = await claude.evaluateTranscript(
        question: state.question,
        transcript: transcript,
      );
      state = state.copyWith(
        answer: result.transcript,
        result: result,
        phase: EvaluationPhase.idle,
      );
    } catch (e, stack) {
      debugPrint('=== EVALUATION ERROR ===');
      debugPrint(e.toString());
      debugPrint(stack.toString());
      debugPrint('========================');
      final ist = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
      final istLabel =
          '${ist.year}-${ist.month.toString().padLeft(2, '0')}-${ist.day.toString().padLeft(2, '0')} '
          '${ist.hour.toString().padLeft(2, '0')}:${ist.minute.toString().padLeft(2, '0')}:${ist.second.toString().padLeft(2, '0')} IST';
      await Sentry.captureException(
        e,
        stackTrace: stack,
        withScope: (scope) {
          scope.setTag('question_id', state.question.id);
          scope.setTag('question_subject', state.question.subject);
          scope.setExtra('error_time_ist', istLabel);
        },
      );
      state = state.copyWith(
        phase: EvaluationPhase.idle,
        error: e.toString().contains('429') || e.toString().contains('RESOURCE_EXHAUSTED')
            ? 'API quota exceeded — try again later'
            : e.toString().contains('503') || e.toString().contains('UNAVAILABLE')
                ? 'Server busy — tap to try again'
                : e.toString().contains('TimeoutException')
                    ? 'Request timed out — tap to try again'
                    : 'Evaluation failed — tap to try again',
      );
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final cardProvider =
    NotifierProviderFamily<CardNotifier, CardState, (int, Question)>(
  CardNotifier.new,
);
