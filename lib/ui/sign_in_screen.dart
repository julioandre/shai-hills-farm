import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shai_hills_farm/domain/phone.dart';
import 'package:shai_hills_farm/state/auth_controller.dart';
import 'package:shai_hills_farm/ui/farm_logo.dart';
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
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  bool _creating = false;
  String? _formError;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_creating && _name.text.trim().isEmpty) {
      setState(() => _formError = 'Enter your name.');
      return;
    }
    setState(() => _formError = null);
    await widget.auth.sendCode(
      _phone.text,
      creating: _creating,
      name: _name.text,
    );
  }

  Future<void> _verify() async {
    await widget.auth.verifyCode(_phone.text, _code.text);
  }

  void _switchMode() {
    setState(() => _creating = !_creating);
    _code.clear();
    widget.auth.useDifferentNumber();
  }

  void _differentNumber() {
    _code.clear();
    widget.auth.useDifferentNumber();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.auth,
          builder: (context, _) {
            final auth = widget.auth;
            final waiting = auth.awaitingCode;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Align(
                          alignment: Alignment.center,
                          child: FarmLogo(width: 220),
                        ),
                        const SizedBox(height: 24),
                        if (widget.startupNotice != null) ...[
                          NoticeBanner(message: widget.startupNotice!),
                          const SizedBox(height: 12),
                        ],
                        if (widget.localOnly)
                          const NoticeBanner(
                            message:
                                'On-device records. Up to 8 people can have an account. '
                                'Add this page to your home screen to open it like an app. '
                                'To try it, use phone $phoneHint and code $demoOtp.',
                          ),
                        if (!widget.localOnly)
                          const NoticeBanner(
                            message:
                                'A text message brings your code. '
                                'Up to 8 people can have an account.',
                          ),
                        const SizedBox(height: 20),
                        TextField(
                          key: const Key('phone-field'),
                          controller: _phone,
                          enabled: !waiting && !auth.busy,
                          keyboardType: TextInputType.phone,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          autocorrect: false,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Phone number',
                            hintText: phoneHint,
                          ),
                        ),
                        if (_creating) ...[
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('name-field'),
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Your name',
                            ),
                          ),
                        ],
                        if (waiting) ...[
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('code-field'),
                            controller: _code,
                            keyboardType: TextInputType.number,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _verify(),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 6,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Code from the text',
                              hintText: '6 digits',
                            ),
                          ),
                        ],
                        if (_formError != null || auth.error != null) ...[
                          const SizedBox(height: 12),
                          NoticeBanner(
                            message: _formError ?? auth.error!,
                            isError: true,
                          ),
                        ],
                        if (auth.notice != null) ...[
                          const SizedBox(height: 12),
                          NoticeBanner(message: auth.notice!),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            key: Key(waiting ? 'submit-auth' : 'send-code'),
                            onPressed: auth.busy
                                ? null
                                : (waiting ? _verify : _sendCode),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: Text(
                              auth.busy
                                  ? (waiting
                                        ? 'Checking the code…'
                                        : 'Sending code…')
                                  : (waiting
                                        ? (_creating
                                              ? 'Create account'
                                              : 'Sign in')
                                        : 'Send code'),
                            ),
                          ),
                        ),
                        if (waiting) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            key: const Key('resend-code'),
                            onPressed: auth.busy ? null : _sendCode,
                            child: const Text('Send a new code'),
                          ),
                          TextButton(
                            key: const Key('different-number'),
                            onPressed: auth.busy ? null : _differentNumber,
                            child: const Text('Use a different number'),
                          ),
                        ],
                        const SizedBox(height: 4),
                        TextButton(
                          key: const Key('switch-auth-mode'),
                          onPressed: auth.busy ? null : _switchMode,
                          child: Text(
                            _creating ? 'I already use this' : 'I am new here',
                          ),
                        ),
                        if (widget.localOnly) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Practice admin: ${displayPhone(demoPhone)}',
                            key: const Key('practice-admin'),
                          ),
                          Text(
                            'Practice worker: ${displayPhone(workerPhone)}',
                            key: const Key('practice-worker'),
                          ),
                          const Text('Code for both: $demoOtp'),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
