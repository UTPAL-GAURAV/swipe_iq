class Question {
  final String id;
  final String subject;
  final String level;
  final String question;

  const Question({
    required this.id,
    required this.subject,
    required this.level,
    required this.question,
  });

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        id: json['id'] as String,
        subject: json['subject'] as String,
        level: json['level'] as String,
        question: json['question'] as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Question && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
