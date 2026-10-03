/// Search stays in memory and contains only records returned by patient APIs.
class AppSearchEntry {
  final String id, title, subtitle, category, keywords;
  final int destination;
  final Map<String, String> details;
  const AppSearchEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.destination,
    this.keywords = '',
    this.details = const {},
  });
}

String normalizeSearch(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[_\-/]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
// Tolerate one missing/extra/wrong letter or adjacent swap in longer words.
// Numeric references and dates remain exact; do not guess a different record ID.
bool _nearWord(String query, String candidate) {
  if ((query.length - candidate.length).abs() > 1) return false;
  if (query == candidate) return true;
  if (query.length == candidate.length) {
    final differences = <int>[];
    for (var i = 0; i < query.length; i++) {
      if (query[i] != candidate[i]) differences.add(i);
      if (differences.length > 2) return false;
    }
    if (differences.length == 1) return true;
    return differences.length == 2 &&
        differences[1] == differences[0] + 1 &&
        query[differences[0]] == candidate[differences[1]] &&
        query[differences[1]] == candidate[differences[0]];
  }
  final shorter = query.length < candidate.length ? query : candidate;
  final longer = query.length < candidate.length ? candidate : query;
  var i = 0, j = 0, skipped = false;
  while (i < shorter.length && j < longer.length) {
    if (shorter[i] == longer[j]) {
      i++;
      j++;
    } else {
      if (skipped) return false;
      skipped = true;
      j++;
    }
  }
  return true;
}

bool _matchesWord(String text, String word) {
  if (text.contains(word)) return true;
  if (word.length < 5 ||
      word.length > 40 ||
      !RegExp(r'^[a-z]+$').hasMatch(word)) {
    return false;
  }
  return RegExp(
    r'[a-z]+',
  ).allMatches(text).any((match) => _nearWord(word, match.group(0)!));
}

List<AppSearchEntry> searchEntries(
  List<AppSearchEntry> entries,
  String query, {
  String category = 'All',
}) {
  final q = normalizeSearch(query);
  final words = q.split(' ').where((w) => w.isNotEmpty).toList();
  int score(AppSearchEntry e) {
    final title = normalizeSearch(e.title);
    if (title == q) return 100;
    if (title.startsWith(q)) return 80;
    if (title.contains(q)) return 60;
    return words.where(title.contains).length * 10;
  }

  final result = entries.where((e) {
    if (category != 'All' && e.category != category) return false;
    final text = normalizeSearch(
      '${e.title} ${e.subtitle} ${e.category} ${e.keywords} ${e.details.values.join(' ')}',
    );
    return words.every((word) => _matchesWord(text, word));
  }).toList();
  if (q.isNotEmpty) {
    result.sort((a, b) {
      final ranked = score(b).compareTo(score(a));
      return ranked == 0 ? a.title.compareTo(b.title) : ranked;
    });
  }
  return result;
}
