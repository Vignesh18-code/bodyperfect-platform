import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../core/constants/app_colors.dart';
import '../../services/chat_service.dart';
import '../../core/constants/app_typography.dart';
import '../appointments/widgets/book_appointment_sheet.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatScreen extends StatefulWidget {
  final bool active;
  final ChatService service;
  final Future<void> Function()? onBookAppointment;
  final VoidCallback? onOpenTreatment;
  final int clinicContactRequest;
  const ChatScreen({
    super.key,
    this.active = true,
    this.service = const ChatService(),
    this.onBookAppointment,
    this.onOpenTreatment,
    this.clinicContactRequest = 0,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  static const _ink = AppColors.navy;
  static const _muted = Color(0xFF686D82);
  static const _blue = Color(0xFF4361EE);
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  Timer? _timer;
  bool _team = false, _loading = true, _sending = false, _polling = false;
  bool _available = false,
      _consent = false,
      _earlier = false,
      _foreground = true;
  String? _error, _branch, _pendingKey, _pendingBody;
  int? _thread;
  int _generation = 0, _loadRevision = 0;
  int _pollingGeneration = -1;
  bool _aiEarlier = false, _loadingOlder = false, _memoryEnabled = true;
  String _memoryNote = '', _displayName = '';
  bool _consentOpen = false;
  ChatService get _api => widget.service;
  List<String> _branches = [];
  List<Map<String, dynamic>> _messages = [], _history = [];
  String _aiDraft = '', _teamDraft = '';

  String get _base => '${ApiConfig.baseUrl}/api/support';
  String _uuid() {
    final r = Random.secure();
    final bytes = List.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final s = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  dynamic _data(Map<String, dynamic> response) {
    if (response['success'] != true) {
      throw Exception(
        response['message'] ?? 'Unable to connect. Please retry.',
      );
    }
    return response['data'];
  }

  List<Map<String, dynamic>> _rows(dynamic data) =>
      (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _team = widget.clinicContactRequest > 0;
    _load();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (widget.active &&
          _foreground &&
          !_sending &&
          !_loading &&
          !_polling &&
          ((_team && _thread != null) ||
              (!_team && _history.any((m) => m['state'] == 'PENDING')))) {
        if (_team) {
          _loadMessages();
        } else {
          _load();
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && !_sending) _load();
    if (widget.clinicContactRequest != oldWidget.clinicContactRequest) {
      _switch(true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && widget.active && !_sending) _load();
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final revision = ++_loadRevision;
    final followBottom =
        _history.isEmpty ||
        (_scroll.hasClients && _scroll.position.extentAfter < 100);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        _api.get('$_base/assistant'),
        _api.get('$_base/assistant/history'),
        _api.get('$_base/branches'),
        _api.get('$_base/assistant/preferences'),
      ]);
      if (!mounted || revision != _loadRevision) return;
      final failures = values.where((v) => v['success'] != true).toList();
      setState(() {
        if (values[0]['success'] == true) {
          _available = values[0]['data']['available'] == true;
          _displayName =
              values[0]['data']['displayName']?.toString().trim() ?? '';
        }
        if (values[1]['success'] == true) {
          _history = _rows(values[1]['data']).reversed.toList();
          _aiEarlier = _history.length == 30;
        }
        if (values[2]['success'] == true) {
          _branches = List<String>.from(values[2]['data']);
          if (!_branches.contains(_branch)) {
            _branch = _branches.isEmpty ? null : _branches.first;
          }
        }
        if (values[3]['success'] == true) {
          _memoryEnabled = values[3]['data']['memoryEnabled'] == true;
          _memoryNote = values[3]['data']['note'] ?? '';
        }
        if (failures.isNotEmpty) {
          _error =
              failures.first['message'] ?? 'Unable to refresh. Please retry.';
        }
      });
      if (_team && _branch != null) {
        if (_thread == null) {
          await _open();
        } else {
          await _loadMessages();
        }
      } else if (!_team && followBottom && _history.isNotEmpty) {
        _bottom();
      }
    } catch (_) {
      if (mounted && revision == _loadRevision) {
        setState(() => _error = 'Unable to connect. Please retry.');
      }
    } finally {
      if (mounted && revision == _loadRevision) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _olderAi() async {
    if (_loadingOlder || _history.isEmpty) return;
    setState(() => _loadingOlder = true);
    final oldExtent = _scroll.hasClients
        ? _scroll.position.maxScrollExtent
        : 0.0;
    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
    try {
      final rows = _rows(
        _data(
          await _api.get(
            '$_base/assistant/history?before=${_history.first['id']}',
          ),
        ),
      );
      if (!mounted) return;
      setState(() {
        final items = {
          for (final m in _history) m['id']: m,
          for (final m in rows) m['id']: m,
        };
        _history = items.values.toList()
          ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
        _aiEarlier = rows.length == 30;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(
            (offset + _scroll.position.maxScrollExtent - oldExtent).clamp(
              0,
              _scroll.position.maxScrollExtent,
            ),
          );
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not load earlier messages. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _open() async {
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _thread = null;
      _messages = [];
      _earlier = false;
      _error = null;
    });
    try {
      final t = _data(await _api.post('$_base/threads?branch=$_branch', {}));
      if (!mounted || gen != _generation) return;
      setState(() => _thread = t['id']);
      await _loadMessages();
    } catch (e) {
      if (mounted && gen == _generation) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  Future<void> _loadMessages({bool older = false}) async {
    if (_thread == null || (_polling && _pollingGeneration == _generation)) {
      return;
    }
    final gen = _generation;
    _pollingGeneration = gen;
    _polling = true;
    try {
      final before = older && _messages.isNotEmpty
          ? '?before=${_messages.first['id']}'
          : '';
      final data = _data(
        await _api.get('$_base/threads/$_thread/messages$before'),
      );
      final rows = _rows(data['items']);
      if (!mounted || gen != _generation) return;
      final wasEmpty = _messages.isEmpty;
      final nearBottom =
          !_scroll.hasClients || _scroll.position.extentAfter < 100;
      setState(() {
        if (older || wasEmpty) _earlier = data['hasEarlier'] == true;
        final combined = {
          for (final m in _messages) m['id']: m,
          for (final m in rows) m['id']: m,
        };
        _messages = combined.values.toList()
          ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
        _error = null;
      });
      if (!older && nearBottom) _bottom();
    } catch (e) {
      if (mounted && gen == _generation) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (_pollingGeneration == gen) _polling = false;
    }
  }

  void _bottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
        return;
      }
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  });
  Future<void> _switch(bool team) async {
    if (_sending || team == _team) return;
    if (_team) {
      _teamDraft = _draft.text;
    } else {
      _aiDraft = _draft.text;
    }
    setState(() {
      _team = team;
      _draft.text = team ? _teamDraft : _aiDraft;
      _pendingKey = null;
      _pendingBody = null;
      _error = null;
    });
    if (team && _thread == null && _branch != null) await _open();
    _bottom();
  }

  Future<void> _send() async {
    final body = _draft.text.trim();
    if (_sending || _consentOpen || body.isEmpty || _loading) return;
    if (!_team && !_consent) {
      final agreed = await _requestConsent();
      if (!agreed || !mounted) return;
      setState(() => _consent = true);
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    if (_pendingKey == null || body != _pendingBody) {
      _pendingKey = _uuid();
      _pendingBody = body;
    }
    _bottom();
    try {
      final response = await _api.post(
        _team ? '$_base/threads/$_thread/messages' : '$_base/assistant',
        _team
            ? {'clientId': _pendingKey, 'body': body}
            : {'clientId': _pendingKey, 'question': body, 'consent': _consent},
      );
      final result = Map<String, dynamic>.from(_data(response));
      if (!mounted) return;
      setState(() {
        if (_team) {
          _messages = [
            ..._messages.where((m) => m['id'] != result['id']),
            result,
          ];
          _teamDraft = '';
        } else {
          _history = [
            ..._history.where((m) => m['id'] != result['id']),
            result,
          ];
          _aiDraft = '';
        }
        _draft.clear();
        _pendingKey = null;
        _pendingBody = null;
      });
      _bottom();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
        if (!_team) {
          try {
            final history = _rows(
              _data(await _api.get('$_base/assistant/history')),
            ).reversed.toList();
            if (mounted) {
              setState(() {
                _history = history;
                if (history.any(
                  (m) => m['clientId'] == _pendingKey && m['state'] == 'FAILED',
                )) {
                  _pendingKey = null;
                }
              });
            }
          } catch (_) {
            /* Keep draft and idempotency key after a connection failure. */
          }
        }
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<bool> _requestConsent() async {
    if (_consentOpen) return false;
    _consentOpen = true;
    try {
      return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Meet your AI care assistant'),
              content: const SingleChildScrollView(
                child: Text(
                  'To answer, OpenAI receives your question, profile name, preferred treatment, approved care instructions, session and appointment summaries, reward points and linked clinic names. When memory is on, it also receives relevant past chats and your saved preferences.\n\nAI chats are saved in your clinic account for up to 90 days. You can turn memory off or clear your AI history at any time. This is AI assistance, not medical advice or emergency support.',
                  style: TextStyle(height: 1.5, fontSize: 14),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Not now'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Agree and continue'),
                ),
              ],
            ),
          ) ??
          false;
    } finally {
      _consentOpen = false;
    }
  }

  Future<void> _settings() async {
    var memory = _memoryEnabled;
    final note = TextEditingController(text: _memoryNote);
    var saving = false;
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            0,
            22,
            MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Your AI memory',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close memory settings',
                      onPressed: saving ? null : () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'You decide what helps your next conversation.',
                  style: TextStyle(color: _muted, height: 1.5),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Remember our conversations'),
                  subtitle: const Text(
                    'Continue where you left off, even after closing the app.',
                  ),
                  value: memory,
                  onChanged: saving ? null : (v) => update(() => memory = v),
                  activeTrackColor: _blue,
                ),
                TextField(
                  controller: note,
                  maxLength: 1000,
                  minLines: 2,
                  maxLines: 4,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Preferences to remember',
                    hintText:
                        'For example: reply in English and keep answers short.',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                  ),
                ),
                const Text(
                  'Avoid passwords or verification codes. These preferences are used only when memory is on. Chat history expires after 90 days.',
                  style: TextStyle(fontSize: 12, color: _muted, height: 1.5),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            update(() => saving = true);
                            try {
                              final prefs = _data(
                                await _api.put('$_base/assistant/preferences', {
                                  'memoryEnabled': memory,
                                  'note': note.text.trim(),
                                }),
                              );
                              if (!mounted) return;
                              setState(() {
                                _memoryEnabled = prefs['memoryEnabled'] == true;
                                _memoryNote = prefs['note'] ?? '';
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (_) {
                              if (ctx.mounted) {
                                update(() {
                                  saving = false;
                                  error =
                                      'Could not save your preferences. Please retry.';
                                });
                              }
                            }
                          },
                    child: Text(saving ? 'Saving…' : 'Save preferences'),
                  ),
                ),
                Center(
                  child: TextButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            final confirmed = await showDialog<bool>(
                              context: ctx,
                              builder: (d) => AlertDialog(
                                title: const Text(
                                  'Clear AI history and memory?',
                                ),
                                content: const Text(
                                  'This removes your saved AI questions, answers and preference note. Clinic team messages and treatment records stay in your account.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(d, false),
                                    child: const Text('Keep history'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(d, true),
                                    child: const Text('Clear AI history'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true || !ctx.mounted) return;
                            update(() => saving = true);
                            try {
                              _data(
                                await _api.delete('$_base/assistant/history'),
                              );
                              if (!mounted) return;
                              setState(() {
                                _history = [];
                                _memoryNote = '';
                                _aiEarlier = false;
                                _pendingKey = null;
                                _pendingBody = null;
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (_) {
                              if (ctx.mounted) {
                                update(() {
                                  saving = false;
                                  error =
                                      'Could not clear history. Wait for any pending reply, then retry.';
                                });
                              }
                            }
                          },
                    icon: const Icon(Icons.delete_outline_rounded, size: 17),
                    label: const Text('Clear AI history'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // The sheet's exit animation can still read its controller for one frame.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    note.dispose();
  }

  Future<void> _action(String action) async {
    if (_sending) return;
    if (action == 'CLINIC_TEAM') {
      await _switch(true);
      return;
    }
    if (action == 'VIEW_TREATMENT') {
      widget.onOpenTreatment?.call();
      return;
    }
    if (action == 'BOOK_APPOINTMENT') {
      if (widget.onBookAppointment != null) {
        await widget.onBookAppointment!();
      } else if (mounted) {
        await showBookAppointmentSheet(context);
      }
    }
  }

  Future<void> _source(Map<String, dynamic> source) async {
    final uri = Uri.tryParse(source['url']?.toString() ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'www.bodyperfect.ae') {
      return;
    }
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      /* Show a truthful fallback. */
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the source. Please try again.'),
        ),
      );
    }
  }

  Widget _channel(bool team, String title, IconData icon) {
    final selected = team == _team;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            onTap: _sending ? null : () => _switch(team),
            borderRadius: BorderRadius.circular(13),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 17, color: selected ? _blue : _muted),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected ? _ink : _muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 16, 10),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                _team ? Icons.forum_rounded : Icons.auto_awesome_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BODY PERFECT',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w600,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _team ? 'Your clinic team' : 'Your care assistant',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.6,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),
            if (!_team)
              IconButton(
                tooltip: 'Memory and privacy',
                onPressed: _sending ? null : _settings,
                icon: const Icon(Icons.tune_rounded, size: 21, color: _ink),
              ),
            IconButton(
              tooltip: 'Refresh conversations',
              onPressed: _sending || _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded, size: 21, color: _ink),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFE9ECF7),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            children: [
              _channel(false, 'AI assistant', Icons.auto_awesome_outlined),
              const SizedBox(width: 4),
              _channel(true, 'Clinic team', Icons.chat_bubble_outline_rounded),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _askSuggested(String question) async {
    if (_sending || _loading) return;
    setState(() => _draft.text = question);
    await _send();
  }

  Widget _starter(
    String title,
    String subtitle,
    IconData icon,
    String question,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: !_available || _loading || _sending
            ? null
            : () => _askSuggested(question),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF0FF),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: _blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_outward_rounded, size: 17, color: _blue),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _welcome() {
    final firstName = _displayName.split(RegExp(r'\s+')).first;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            firstName.isEmpty ? 'Hello there.' : 'Hello, $firstName.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -.7,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'What can I help you with today?',
            style: TextStyle(fontSize: 15, color: _muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          _starter(
            'My care & appointments',
            'Your plan, next visit and progress',
            Icons.favorite_border_rounded,
            'Summarize my approved care plan and next appointment.',
          ),
          _starter(
            'Start a diet plan',
            'Consultation and what comes next',
            Icons.restaurant_outlined,
            'I want a personalized diet plan. What should I do first?',
          ),
          _starter(
            'Explore treatments',
            'Find out about BodyPerfect services',
            Icons.spa_outlined,
            'What services does BodyPerfect offer?',
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ActionChip(
                label: const Text(
                  'Clinic locations',
                  style: TextStyle(fontSize: 11),
                ),
                onPressed: !_available || _sending
                    ? null
                    : () => _askSuggested('Where are the BodyPerfect clinics?'),
              ),
              ActionChip(
                label: const Text(
                  'My reward points',
                  style: TextStyle(fontSize: 11),
                ),
                onPressed: !_available || _sending
                    ? null
                    : () => _askSuggested('How many reward points do I have?'),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _memoryEnabled ? Icons.history_rounded : Icons.shield_outlined,
                size: 14,
                color: _muted,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _memoryEnabled
                      ? 'Come back anytime. We can continue this conversation.'
                      : 'Memory is off. You can turn it on in settings.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _muted,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _followUps(Map<String, dynamic> exchange) {
    final questions = List<String>.from(
      exchange['followUps'] ?? const <String>[],
    );
    if (questions.isEmpty || !_available) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'KEEP EXPLORING',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: _muted,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final question in questions.take(3))
                ActionChip(
                  label: Text(
                    question,
                    style: const TextStyle(fontSize: 11, color: _ink),
                  ),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.border),
                  onPressed: () => _askSuggested(question),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bubble(
    String text,
    bool mine,
    String label, {
    String? timestamp,
    Map<String, dynamic>? exchange,
  }) {
    final date = DateTime.tryParse(timestamp ?? '')?.toLocal();
    final sources = exchange?['sources'] as List? ?? [];
    final actions = List<String>.from(exchange?['actions'] ?? []);
    return Padding(
      padding: EdgeInsets.fromLTRB(mine ? 35 : 0, 10, mine ? 0 : 15, 10),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(3, 0, 3, 6),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: _muted,
              ),
            ),
          ),
          IntrinsicWidth(
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: mine ? AppColors.brandGradient : null,
                color: mine ? null : Colors.white,
                border: mine ? null : Border.all(color: AppColors.border),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(19),
                  topRight: const Radius.circular(19),
                  bottomLeft: Radius.circular(mine ? 19 : 5),
                  bottomRight: Radius.circular(mine ? 5 : 19),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    container: true,
                    label: text,
                    excludeSemantics: true,
                    child: SelectableText(
                      text,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: mine ? Colors.white : _ink,
                      ),
                    ),
                  ),
                  if (sources.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'FROM BODYPERFECT',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...sources.map(
                      (s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: InkWell(
                          onTap: () => _source(Map<String, dynamic>.from(s)),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.link_rounded,
                                  color: _blue,
                                  size: 15,
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    s['title'] ?? 'Clinic source',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.4,
                                      color: _blue,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.north_east_rounded,
                                  size: 13,
                                  color: _blue,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (date != null || !mine)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (date != null)
                  Flexible(
                    child: Text(
                      '${date.day}/${date.month} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 10, color: _muted),
                    ),
                  ),
                if (!mine)
                  IconButton(
                    tooltip: 'Copy reply',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.copy_outlined,
                      size: 14,
                      color: _muted,
                    ),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                    },
                  ),
              ],
            ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 7,
                runSpacing: 6,
                children: [
                  for (final action in actions)
                    if (action != 'VIEW_TREATMENT' ||
                        widget.onOpenTreatment != null)
                      ActionChip(
                        label: Text(switch (action) {
                          'BOOK_APPOINTMENT' => 'Book a visit',
                          'VIEW_TREATMENT' => 'View treatment',
                          _ => 'Talk to clinic',
                        }, style: const TextStyle(fontSize: 11, color: _blue)),
                        onPressed: _sending ? null : () => _action(action),
                        backgroundColor: const Color(0xFFEEF0FF),
                        side: BorderSide.none,
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _teamIntro() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_branches.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _branch,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.location_on_outlined, size: 19),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            items: _branches
                .map(
                  (b) => DropdownMenuItem(
                    value: b,
                    child: Text(
                      b == 'MARINA' ? 'Marina clinic' : 'BurJuman clinic',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                )
                .toList(),
            onChanged: _sending || _loading
                ? null
                : (v) {
                    setState(() {
                      _branch = v;
                      _pendingKey = null;
                      _pendingBody = null;
                      _teamDraft = '';
                      _draft.clear();
                    });
                    _open();
                  },
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          _branches.isEmpty && !_loading
              ? 'Contact reception to link your account to a clinic.'
              : 'A real person from your clinic will reply here. This is not live or emergency support.',
          style: const TextStyle(fontSize: 12, height: 1.6, color: _muted),
        ),
      ),
      if (_messages.isEmpty && !_loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.mark_chat_unread_outlined, size: 34, color: _blue),
              SizedBox(height: 14),
              Text(
                'Let’s talk about your care.',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.6,
                  color: _ink,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Ask a question, follow up on a visit, or request help from the team. Your AI conversation is not shared automatically.',
                style: TextStyle(fontSize: 13, height: 1.6, color: _muted),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _composer() {
    final ready =
        !_loading && !_sending && (_team ? _thread != null : _available);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: .6)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_team && !keyboardOpen)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(
                    _memoryEnabled
                        ? Icons.history_rounded
                        : Icons.history_toggle_off_rounded,
                    size: 13,
                    color: _muted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _memoryEnabled ? 'Private memory on' : 'Memory off',
                    style: const TextStyle(fontSize: 10, color: _muted),
                  ),
                  if (!_consent)
                    InkWell(
                      onTap: _available
                          ? () async {
                              if (await _requestConsent() && mounted) {
                                setState(() => _consent = true);
                              }
                            }
                          : null,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 5,
                          horizontal: 4,
                        ),
                        child: Text(
                          'How AI uses your data',
                          style: TextStyle(fontSize: 10, color: _blue),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(13, 3, 4, 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FC),
              borderRadius: BorderRadius.circular(23),
              border: Border.all(color: const Color(0xFFE5E8F3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _draft,
                    enabled: !_sending,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: _team ? 4000 : 2000,
                    onChanged: (_) => setState(() {}),
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: _ink,
                    ),
                    decoration: InputDecoration(
                      hintText: _team
                          ? 'Message your clinic…'
                          : 'Ask me anything about your care…',
                      hintMaxLines: 1,
                      hintStyle: const TextStyle(fontSize: 12, color: _muted),
                      counterText: '',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                IconButton.filled(
                  tooltip: 'Send message',
                  onPressed: ready && _draft.text.trim().isNotEmpty
                      ? _send
                      : null,
                  style: IconButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE1E5F0),
                  ),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 21),
                ),
              ],
            ),
          ),
          if (!keyboardOpen) const SizedBox(height: 7),
          if (!keyboardOpen)
            Text(
              _team
                  ? 'Replies appear here when your clinic responds.'
                  : 'AI can make mistakes. Confirm medical decisions with your clinician.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, height: 1.4, color: _muted),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      textTheme: Theme.of(
        context,
      ).textTheme.apply(fontFamily: AppTypography.family),
    ),
    child: DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: AppTypography.family),
      child: SafeArea(
        child: ColoredBox(
          color: AppColors.surface,
          child: Column(
            children: [
              _header(),
              if (_loading)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: _blue,
                  backgroundColor: Color(0xFFE9ECF4),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _error!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: Color(0xFF7E3D25),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _sending || _loading ? null : _load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    if (_team) _teamIntro(),
                    if (!_team && !_available && !_loading)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEBEDFB),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AI is temporarily unavailable.',
                              style: TextStyle(fontSize: 13, color: _ink),
                            ),
                            TextButton(
                              onPressed: () => _switch(true),
                              child: const Text('Message your clinic'),
                            ),
                          ],
                        ),
                      ),
                    if (!_team && _history.isEmpty) _welcome(),
                    if ((_team && _earlier) || (!_team && _aiEarlier))
                      TextButton(
                        onPressed: _loadingOlder
                            ? null
                            : (_team
                                  ? () => _loadMessages(older: true)
                                  : _olderAi),
                        child: Text(
                          _loadingOlder ? 'Loading…' : 'Load earlier messages',
                        ),
                      ),
                    if (_team)
                      ..._messages.map(
                        (m) => _bubble(
                          m['body'],
                          m['senderRole'] == 'PATIENT',
                          m['senderRole'] == 'PATIENT'
                              ? 'You'
                              : '${m['senderName']} · Clinic team',
                          timestamp: m['createdAt'],
                        ),
                      ),
                    if (!_team)
                      ..._history.expand(
                        (m) => [
                          _bubble(
                            m['question'],
                            true,
                            'You',
                            timestamp: m['createdAt'],
                          ),
                          _bubble(
                            m['answer'] ??
                                (m['state'] == 'PENDING'
                                    ? 'Your reply is still processing. It will appear here shortly.'
                                    : 'This reply could not be completed. Your clinic team can help.'),
                            false,
                            'BodyPerfect AI',
                            exchange: m,
                          ),
                          if (!_sending &&
                              m['state'] == 'COMPLETED' &&
                              m['id'] == _history.last['id'])
                            _followUps(m),
                          if (m['state'] == 'FAILED')
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _sending
                                    ? null
                                    : () => setState(() {
                                        _draft.text = m['question'];
                                        _pendingKey = null;
                                        _pendingBody = null;
                                      }),
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 15,
                                ),
                                label: const Text('Try this question again'),
                              ),
                            ),
                        ],
                      ),
                    if (_sending) ...[
                      _bubble(
                        _pendingBody ?? _draft.text,
                        true,
                        'You · Sending',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Semantics(
                          liveRegion: true,
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _blue,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _team
                                      ? 'Sending to your clinic…'
                                      : 'Thinking about your question…',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _composer(),
            ],
          ),
        ),
      ),
    ),
  );
}
