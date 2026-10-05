import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';

class AccountPrivacyScreen extends StatefulWidget {
  const AccountPrivacyScreen({super.key});
  @override
  State<AccountPrivacyScreen> createState() => _AccountPrivacyScreenState();
}

class _AccountPrivacyScreenState extends State<AccountPrivacyScreen> {
  Map<String, dynamic> policies = {};
  List<dynamic> requests = [];
  String? error;
  bool busy = false;
  final password = TextEditingController();
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final p = await ApiService.secureGet(
      '${ApiConfig.baseUrl}/api/public/policies',
    );
    final r = await ApiService.secureGet(
      '${ApiConfig.baseUrl}/api/user/deletion-requests',
    );
    if (!mounted) return;
    setState(() {
      policies = Map<String, dynamic>.from(p['data'] ?? {});
      requests = r['data'] is List ? r['data'] : [];
      if (r['success'] != true) {
        error = r['message'] ?? 'Unable to load account requests';
      }
    });
  }

  Future<void> open(String key) async {
    final uri = Uri.tryParse(policies[key] ?? '');
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      setState(() => error = 'The clinic has not published this policy yet.');
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      setState(() => error = 'Unable to open policy');
    }
  }

  Future<void> request() async {
    if (password.text.isEmpty) {
      setState(
        () => error = 'Enter your password to confirm account ownership.',
      );
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Request account deletion?'),
        content: const Text(
          'This sends a request to the clinic. Your account is not deleted immediately. The clinic will review any required record retention and confirm the outcome.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Send request'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    final result = await ApiService.securePost(
      '${ApiConfig.baseUrl}/api/user/deletion-requests',
      {'password': password.text},
    );
    password.clear();
    if (!mounted) return;
    setState(() {
      busy = false;
      error = result['message'];
    });
    if (result['success'] == true) await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy & account')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ListTile(
          title: const Text('Privacy policy'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => open('privacyUrl'),
        ),
        ListTile(
          title: const Text('Terms of service'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => open('termsUrl'),
        ),
        const Divider(height: 32),
        const Text(
          'Request account deletion',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text(
          (policies['retentionNotice'] as String?)?.isNotEmpty == true
              ? policies['retentionNotice']
              : 'The clinic will review your deletion request and explain any records it must retain.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: password,
          obscureText: true,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: 'Current password',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: busy ? null : request,
          child: Text(busy ? 'Sending…' : 'Request deletion'),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(error!, semanticsLabel: error),
          ),
        for (final r in requests)
          ListTile(
            title: Text('Request #${r['id']}'),
            subtitle: Text('Status: ${r['state']}'),
          ),
      ],
    ),
  );
}
