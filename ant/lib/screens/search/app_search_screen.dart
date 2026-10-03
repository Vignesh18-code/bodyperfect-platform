import '../../core/constants/app_typography.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import 'search_index.dart';
import '../home/widgets/longevity_program.dart';

class HomeSearchResults extends StatefulWidget {
  final String query;
  final ValueChanged<int> onNavigate;
  const HomeSearchResults({
    super.key,
    required this.query,
    required this.onNavigate,
  });
  @override
  State<HomeSearchResults> createState() => _HomeSearchResultsState();
}

class _HomeSearchResultsState extends State<HomeSearchResults> {
  static const _ink = Color(0xFF1A1A2E),
      _blue = Color(0xFF4361EE),
      _muted = Color(0xFF687184);
  Timer? _debounce;
  String _query = '', _category = 'All';
  bool _loading = true;
  List<String> _errors = [];
  List<AppSearchEntry> _records = [];
  static final _pages = [
    for (var i = 0; i < LongevityProgram.catalog.length; i++)
      AppSearchEntry(
        id: 'service-$i',
        title: LongevityProgram.catalog[i].title,
        subtitle: LongevityProgram.catalog[i].subtitle,
        category: 'Services',
        destination: 100 + i,
        keywords:
            '${LongevityProgram.catalog[i].description} ${LongevityProgram.catalog[i].cardTitle ?? ""}',
      ),
    AppSearchEntry(
      id: 'appointments',
      title: 'Appointments',
      subtitle: 'Review your visits and booking requests',
      category: 'Pages',
      destination: 1,
      keywords:
          'appointment booking book schedule reschedule cancel visit calendar',
    ),
    AppSearchEntry(
      id: 'treatment',
      title: 'Treatment plan',
      subtitle: 'Your protocol, progress and care instructions',
      category: 'Pages',
      destination: 2,
      keywords:
          'treatments treatment protocol sessions therapy care instructions progress',
    ),
    AppSearchEntry(
      id: 'chat',
      title: 'Clinic chat',
      subtitle: 'Message your clinic or use the AI assistant',
      category: 'Pages',
      destination: 3,
      keywords:
          'support help contact staff customer service message ai assistant chat',
    ),
    AppSearchEntry(
      id: 'profile',
      title: 'Profile',
      subtitle: 'Your photo, account details and referral code',
      category: 'Pages',
      destination: 4,
      keywords:
          'photo image name email phone account personal referral points rewards',
    ),
    AppSearchEntry(
      id: 'notifications',
      title: 'Notifications',
      subtitle: 'Clinic updates and appointment reminders',
      category: 'Pages',
      destination: 5,
      keywords: 'notification alerts inbox reminders updates',
    ),
    AppSearchEntry(
      id: 'book',
      title: 'Book an appointment',
      subtitle: 'Request your next clinic visit',
      category: 'Pages',
      destination: 6,
      keywords: 'booking new appointment schedule reservation book visit',
    ),
    AppSearchEntry(
      id: 'home',
      title: 'Home',
      subtitle: 'Clinic overview and featured programs',
      category: 'Pages',
      destination: 0,
      keywords:
          'home services programs longevity stem cell peptide iv therapy anti aging hydra facial slimming',
    ),
  ];
  @override
  void initState() {
    super.initState();
    _query = widget.query;
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeSearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _changed(widget.query);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  String _text(dynamic value) => value?.toString() ?? '';
  String _status(dynamic value) =>
      _text(value).replaceAll('_', ' ').toLowerCase();
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errors = [];
    });
    final responses = await Future.wait([
      ApiService.secureGet(ApiConfig.appointments),
      ApiService.secureGet(ApiConfig.treatmentProtocols),
      ApiService.secureGet(ApiConfig.treatmentActive),
    ]);
    if (!mounted) return;
    if (responses.any(
      (r) => r['httpStatus'] == 401 || r['code'] == 'SESSION_EXPIRED',
    )) {
      setState(() {
        _records = [];
        _loading = false;
        _errors = [
          'Your session has expired. Sign in again to search your records.',
        ];
      });
      return;
    }
    final records = <AppSearchEntry>[], errors = <String>[];
    final active = responses[2];
    if (active['success'] != true) {
      errors.add('Active care instructions and sessions could not be loaded.');
    }
    if (responses[1]['data'] is List &&
        active['success'] == true &&
        active['data'] is Map) {
      final current = active['data'] as Map;
      responses[1]['data'] = [
        for (final plan in responses[1]['data'] as List)
          if (plan is Map && plan['id'] == current['id']) current else plan,
        if (!(responses[1]['data'] as List).any(
          (p) => p is Map && p['id'] == current['id'],
        ))
          current,
      ];
    }
    for (int source = 0; source < 2; source++) {
      final response = responses[source];
      if (response['success'] != true || response['data'] is! List) {
        errors.add(
          source == 0
              ? 'Appointments could not be loaded.'
              : 'Treatment records could not be loaded.',
        );
        continue;
      }
      for (final raw in response['data'] as List) {
        if (raw is! Map) continue;
        final r = Map<String, dynamic>.from(raw);
        if (source == 0) {
          final date = _text(r['appointmentDate']),
              time = _text(r['appointmentTime']),
              branch = _text(r['branch']);
          records.add(
            AppSearchEntry(
              id: 'appointment-${r['id']}',
              title: 'Appointment · $date',
              subtitle:
                  '$branch · ${time.length >= 5 ? time.substring(0, 5) : time} · ${_status(r['status'])}',
              category: 'Appointments',
              destination: 1,
              keywords: 'appointment booking visit AP-${r['id']}',
              details: {
                'Reference': 'AP-${r['id']}',
                'Date': date,
                'Time': time,
                'Clinic': branch,
                'Status': _status(r['status']),
                if (_text(r['note']).isNotEmpty) 'Your note': _text(r['note']),
              },
            ),
          );
        } else {
          final name = _text(r['protocolName']);
          records.add(
            AppSearchEntry(
              id: 'plan-${r['id']}',
              title: name.isEmpty ? 'Treatment plan' : name,
              subtitle:
                  '${_text(r['treatmentType'])} · ${_status(r['status'])}',
              category: 'Treatments',
              destination: 2,
              keywords: 'treatment protocol plan care instructions therapy',
              details: {
                'Treatment': _text(r['treatmentType']),
                'Status': _status(r['status']),
                'Progress':
                    '${r['completedSessions'] ?? 0} of ${r['totalSessions'] ?? 0} sessions',
                if (_text(r['instructions']).isNotEmpty)
                  'Approved instructions': _text(r['instructions']),
              },
            ),
          );
          for (final session in (r['sessions'] as List? ?? [])) {
            if (session is! Map) continue;
            records.add(
              AppSearchEntry(
                id: 'session-${session['id']}',
                title: _text(session['sessionName']).isEmpty
                    ? 'Treatment session'
                    : _text(session['sessionName']),
                subtitle: '$name · ${_text(session['sessionDate'])}',
                category: 'Treatments',
                destination: 2,
                keywords:
                    'treatment session appointment schedule ${_text(session['status'])}',
                details: {
                  'Plan': name,
                  'Date': _text(session['sessionDate']),
                  'Time': _text(session['sessionTime']),
                  'Status': _status(session['status']),
                },
              ),
            );
          }
        }
      }
    }
    setState(() {
      _records = records;
      _errors = errors;
      _loading = false;
    });
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _query = value);
    });
  }

  IconData _icon(AppSearchEntry e) => switch (e.category) {
    'Services' => Icons.spa_outlined,
    'Appointments' => Icons.calendar_month_outlined,
    'Treatments' => Icons.assignment_outlined,
    _ => switch (e.destination) {
      1 || 6 => Icons.calendar_month_outlined,
      2 => Icons.assignment_outlined,
      3 => Icons.chat_bubble_outline_rounded,
      4 => Icons.person_outline_rounded,
      5 => Icons.notifications_outlined,
      _ => Icons.home_outlined,
    },
  };
  Future<void> _open(AppSearchEntry e) async {
    FocusScope.of(context).unfocus();
    if (e.details.isEmpty) {
      widget.onNavigate(e.destination);
      return;
    }
    final navigate = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * .8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e.title,
                  style: const TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 16),
                ...e.details.entries.map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.key,
                          style: const TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 11,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          d.value,
                          style: const TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 14,
                            height: 1.5,
                            color: _ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    e.destination == 1
                        ? 'Open appointments'
                        : 'Open current treatment plan',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted && navigate == true) widget.onNavigate(e.destination);
  }

  @override
  Widget build(BuildContext context) {
    final results = searchEntries(
      [..._pages, ..._records],
      _query,
      category: _category,
    );
    final visible = _query.trim().isEmpty && _category == 'All'
        ? _pages
        : results;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 12, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Search results',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _load,
                tooltip: 'Refresh search data',
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 19,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: ['All', 'Services', 'Pages', 'Treatments', 'Appointments']
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        c,
                        style: const TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 12,
                        ),
                      ),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                      selectedColor: const Color(0xFFE7EBFF),
                      showCheckmark: false,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (_errors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Semantics(
              liveRegion: true,
              child: Text(
                '${_errors.join(' ')} Use refresh to retry. Page shortcuts remain available.',
                style: const TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 12,
                  height: 1.5,
                  color: Color(0xFF895321),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              liveRegion: true,
              child: Text(
                _query.trim().isEmpty && _category == 'All'
                    ? 'EXPLORE THE APP'
                    : '${visible.length} ${visible.length == 1 ? 'RESULT' : 'RESULTS'}',
                style: const TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: _muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          size: 32,
                          color: _muted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _loading
                              ? 'Searching your records…'
                              : 'No matching results',
                          style: const TextStyle(
                            fontFamily: AppTypography.family,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Try a treatment name, appointment date, clinic or section name.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 13,
                            height: 1.5,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  key: ValueKey('$_query-$_category'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: visible.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final e = visible[index];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: const BorderSide(color: Color(0xFFE9ECF3)),
                        ),
                        leading: Icon(_icon(e), color: _blue, size: 21),
                        title: Text(
                          e.title,
                          style: const TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        subtitle: Text(
                          '${e.category} · ${e.subtitle}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 11,
                            height: 1.5,
                            color: _muted,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: _muted,
                        ),
                        onTap: () => _open(e),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
