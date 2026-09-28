import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/question.dart';
import '../providers/card_provider.dart';
import 'answer_input.dart';
import 'evaluation_card.dart';

class QuestionCard extends ConsumerWidget {
  final int slotIndex;
  final Question question;
  final VoidCallback onAdvance;

  const QuestionCard({
    super.key,
    required this.slotIndex,
    required this.question,
    required this.onAdvance,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cardProvider((slotIndex, question)));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SubjectChip(subject: question.subject, level: question.level),
            const SizedBox(height: 24),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.question,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                    ),
                    if (state.result != null) ...[
                      const SizedBox(height: 24),
                      _YourAnswer(text: state.answer ?? ''),
                      const SizedBox(height: 16),
                      EvaluationCard(
                        result: state.result!,
                        onAdvance: onAdvance,
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
            if (state.isEvaluating)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        color: state.phase == EvaluationPhase.transcribing
                            ? Colors.orange
                            : Colors.teal,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        state.phase == EvaluationPhase.transcribing
                            ? 'Transcribing...'
                            : 'Evaluating...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              )
            else if (state.error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Text(
                        state.error!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => ref
                            .read(cardProvider((slotIndex, question)).notifier)
                            .clearError(),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            else if (state.result == null)
              Center(
                child: AnswerInput(
                  onSubmit: (Uint8List bytes) =>
                      ref.read(cardProvider((slotIndex, question)).notifier).submitAnswer(bytes),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _YourAnswer extends StatelessWidget {
  final String text;
  const _YourAnswer({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your answer',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
          ),
          const SizedBox(height: 4),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  final String subject;
  final String level;

  const _SubjectChip({required this.subject, required this.level});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            subject,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            level,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSecondaryContainer,
                ),
          ),
        ),
      ],
    );
  }
}
