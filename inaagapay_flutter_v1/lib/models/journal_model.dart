class JournalEntry {
  final int entryId;
  final String title;
  final String content;
  final DateTime createdAt;

  JournalEntry({
    required this.entryId,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      entryId: int.parse(json['entry_id'].toString()),
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
