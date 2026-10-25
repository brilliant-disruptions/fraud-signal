import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import '../../data/demo_data.dart' show demoUsers, demoOrgs;
import '../../domain/models.dart';
import '../../widgets/common.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() => _signIn(_email.text, _password.text, validate: true);

  Future<void> _signIn(String email, String password, {bool validate = false}) async {
    if (validate && !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).signIn(email: email, password: password);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _orgLabel(AppUser u) {
    final org = demoOrgs.where((o) => o.id == u.orgId).firstOrNull;
    return org == null ? u.orgId : '${org.name} (${org.offer.label})';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final openDemo = !AppConfig.useSupabase && AppConfig.openDemoSignIn;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          if (!AppConfig.useSupabase) const DemoBanner(),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _form,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.shield_outlined, color: theme.colorScheme.onPrimary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(AppConfig.appName,
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      Text('Sign in', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                        openDemo
                            ? 'Demo build. Enter any email to sign in as an internal reviewer, or pick a demo role below. Every lead view is logged with a timestamp.'
                            : 'Invite-only. Accounts are issued to verified organizations. Every lead view is logged with a timestamp.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(labelText: 'Work email', prefixIcon: Icon(Icons.mail_outline)),
                        validator: (v) => (v == null || !v.contains('@')) ? 'Enter your work email' : null,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                        validator: (v) => (!openDemo && (v == null || v.isEmpty)) ? 'Enter your password' : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: _busy
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Sign in'),
                      ),
                      if (openDemo) ...[
                        const SizedBox(height: 24),
                        Text('Demo roles', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        for (final u in demoUsers)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: OutlinedButton(
                              onPressed: _busy ? null : () => _signIn(u.email, 'demo'),
                              style: OutlinedButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${u.role.label} · ${_orgLabel(u)}',
                                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                Text(u.role.description,
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                              ]),
                            ),
                          ),
                      ],
                      const SizedBox(height: 20),
                      const RiskIndicatorNotice(dense: true),
                      if (!openDemo) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Need access? Organization accounts are opened by invitation after identity verification. Ask your Fraud Signal contact.',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
