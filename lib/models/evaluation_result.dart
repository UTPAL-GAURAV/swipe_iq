enum Verdict { pass, fail }

class EvaluationResult {
  final String transcript;
  final String saidWell;
  final String expectedAnswer;
  final Verdict verdict;

  const EvaluationResult({
    required this.transcript,
    required this.saidWell,
    required this.expectedAnswer,
    required this.verdict,
  });

  bool get isPassed => verdict == Verdict.pass;
}
