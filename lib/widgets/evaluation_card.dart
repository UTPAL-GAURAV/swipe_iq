import 'package:flutter/material.dart';
import '../models/evaluation_result.dart';

class EvaluationCard extends StatelessWidget {
  final EvaluationResult result;
  final VoidCallback onAdvance;

  const EvaluationCard({
    super.key,
    required this.result,
    required this.onAdvance,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isPassed = result.isPassed;
    final actionColor = isPassed ? colors.primary : colors.error;
    final actionOnColor = isPassed ? colors.onPrimary : colors.onError;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: actionColor, width: 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _VerdictBadge(isPassed: isPassed),
          const SizedBox(height: 14),
          if (result.saidWell.isNotEmpty) ...[
            _Section(
              icon: Icons.check_circle_outline,
              label: 'Said well',
              text: result.saidWell,
              color: colors.primary,
            ),
            const SizedBox(height: 12),
          ],
          if (result.expectedAnswer.isNotEmpty)
            _Section(
              icon: Icons.lightbulb_outline,
              label: isPassed ? 'Full answer' : 'Expected answer',
              text: result.expectedAnswer,
              color: isPassed ? colors.secondary : colors.error,
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAdvance,
              icon: Icon(
                isPassed ? Icons.arrow_forward_rounded : Icons.refresh_rounded,
                size: 18,
              ),
              label: Text(isPassed ? 'Next Question' : 'Try Again'),
              style: FilledButton.styleFrom(
                backgroundColor: actionColor,
                foregroundColor: actionOnColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerdictBadge extends StatelessWidget {
  final bool isPassed;
  const _VerdictBadge({required this.isPassed});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          isPassed ? Icons.emoji_events_outlined : Icons.refresh,
          color: isPassed ? colors.primary : colors.error,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          isPassed ? 'PASSED' : 'TRY AGAIN',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: isPassed ? colors.primary : colors.error,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final Color color;

  const _Section({
    required this.icon,
    required this.label,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => l.startsWith('•') ? l.substring(1).trim() : l)
        .toList();

    Widget body;
    if (lines.length <= 1) {
      body = Text(text, style: Theme.of(context).textTheme.bodyMedium);
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines
            .map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      Expanded(
                          child: Text(line,
                              style: Theme.of(context).textTheme.bodyMedium)),
                    ],
                  ),
                ))
            .toList(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        body,
      ],
    );
  }
}
