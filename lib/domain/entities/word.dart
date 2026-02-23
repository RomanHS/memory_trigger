class Word {
  final int id;
  final String foreignWord;
  final String translation;
  final String createdAt;
  final int timestampMs;
  final int priority;

  Word({
    required this.id,
    required this.foreignWord,
    required this.translation,
    required this.createdAt,
    required this.timestampMs,
    required this.priority,
  });

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as int,
      foreignWord: map['foreign_word'] as String? ?? '',
      translation: map['translation'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? '',
      timestampMs: map['timestamp_ms'] as int? ?? 0,
      priority: map['priority'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'foreign_word': foreignWord,
      'translation': translation,
      'created_at': createdAt,
      'timestamp_ms': timestampMs,
      'priority': priority,
    };
  }

  Word copyWith({String? foreignWord, String? translation, int? priority}) {
    return Word(
      id: id,
      foreignWord: foreignWord ?? this.foreignWord,
      translation: translation ?? this.translation,
      createdAt: createdAt,
      timestampMs: timestampMs,
      priority: priority ?? this.priority,
    );
  }
}
