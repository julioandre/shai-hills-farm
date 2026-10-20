import 'package:flutter/material.dart';
import 'package:shai_hills_farm/state/auth_controller.dart';
import 'package:shai_hills_farm/theme/farm_theme.dart';
import 'package:shai_hills_farm/ui/status_views.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.auth,
    required this.localOnly,
    this.startupNotice,
  });

  final AuthController auth;
  final bool localOnly;
  final String? startupNotice;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final action = _creating ? widget.auth.signUp : widget.auth.signIn;
    await action(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.auth,
          builder: (context, _) {
            final auth = widget.auth;
            final submitLabel = auth.busy
                ? (_creating ? 'Creating account…' : 'Signing in…')
                : (_creating ? 'Create account' : 'Sign in');
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FarmMark(),
                    const SizedBox(height: 20),
                    Text(
                      'Shai Hills Farm',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Livestock register for the 20 acres at Shai Hills, Ghana.',
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.35),
                    ),
                    const SizedBox(height: 28),
                    if (widget.startupNotice != null) ...[
                      NoticeBanner(message: widget.startupNotice!),
                      const SizedBox(height: 12),
                    ],
                    if (widget.localOnly)
                      const NoticeBanner(
                        message:
                            'On-device records. Create an account on this screen. '
                            'It stays on this device until a Supabase project is connected.',
                      ),
                    if (!widget.localOnly)
                      const NoticeBanner(
                        message: 'Signing in with Supabase. The herd is stored in the farm project.',
                      ),
                    const SizedBox(height: 20),
                    TextField(
                      key: const Key('email-field'),
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Work email',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('password-field'),
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: [
                        _creating
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    if (auth.error != null) ...[
                      const SizedBox(height: 12),
                      NoticeBanner(message: auth.error!, isError: true),
                    ],
                    if (auth.notice != null) ...[
                      const SizedBox(height: 12),
                      NoticeBanner(message: auth.notice!),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('submit-auth'),
                        onPressed: auth.busy ? null : _submit,
                        child: Text(submitLabel),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('switch-auth-mode'),
                      onPressed: auth.busy
                          ? null
                          : () => setState(() => _creating = !_creating),
                      child: Text(
                        _creating
                            ? 'Already have an account? Sign in'
                            : 'Need an account? Create one',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FarmMark extends StatelessWidget {
  const _FarmMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: farmLeaf,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'SH',
        style: TextStyle(
          color: farmPaper,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
