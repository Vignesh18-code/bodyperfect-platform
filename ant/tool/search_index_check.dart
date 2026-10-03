// Standalone dependency-free verification script, also runnable outside Flutter native hooks.
// ignore_for_file: avoid_relative_lib_imports, avoid_print
import '../lib/screens/search/search_index.dart';

void check(bool condition, String name) {
  if (!condition) throw StateError(name);
}

void main() {
  const entries = [
    AppSearchEntry(
      id: 'a',
      title: 'Appointment · 2026-09-28',
      subtitle: 'BURJUMAN · confirmed',
      category: 'Appointments',
      destination: 1,
      keywords: 'booking visit',
    ),
    AppSearchEntry(
      id: 'p',
      title: 'Treatment plan',
      subtitle: 'Your current care',
      category: 'Pages',
      destination: 2,
      keywords: 'therapy protocol session',
    ),
    AppSearchEntry(
      id: 't',
      title: 'Skin treatment',
      subtitle: 'Active plan',
      category: 'Treatments',
      destination: 2,
      details: {'Instructions': 'Follow approved care instructions'},
    ),
  ];
  check(
    searchEntries(entries, '  TREATMENT   PLAN ').first.id == 'p',
    'Case/space normalization and exact ranking',
  );
  check(searchEntries(entries, 'appoint').single.id == 'a', 'Partial words');
  check(
    searchEntries(entries, 'burjuman 2026-09-28').single.id == 'a',
    'Multiword clinic/date search',
  );
  check(searchEntries(entries, 'booking').single.id == 'a', 'Aliases');
  check(
    searchEntries(entries, 'care', category: 'Treatments').single.id == 't',
    'Category scope and instruction search',
  );
  check(
    searchEntries(entries, 'burjuman missing').isEmpty,
    'Every query term must match',
  );
  check(
    searchEntries(entries, ' ', category: 'Appointments').single.id == 'a',
    'Empty filtered query',
  );
  check(searchEntries(entries, 'nothing').isEmpty, 'No fabricated results');
  check(
    searchEntries(entries, 'appoitment').single.id == 'a',
    'Missing letter from screenshot',
  );
  check(
    searchEntries(entries, 'treatmetn').length == 2,
    'Adjacent letter swap',
  );
  check(
    searchEntries(entries, '2026-09-29').isEmpty,
    'Do not fuzzy-match dates',
  );
  print('PASS: 11 search ranking/filter/normalization/typo checks');
}
