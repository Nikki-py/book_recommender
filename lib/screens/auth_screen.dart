import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shelf_line.dart';

/// Sign up and log in share one screen; the shelf-line link at the bottom
/// switches between them.
class AuthScreen extends StatefulWidget {
  final bool startWithSignUp;
  const AuthScreen({super.key, this.startWithSignUp = true});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = AuthService();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late bool _signUp = widget.startWithSignUp;
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_signUp && _username.text.trim().isEmpty) {
      setState(() => _error = 'Pick a username.');
      return;
    }
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Fill in your email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_signUp) {
        await _auth.signUp(name: _username.text, email: _email.text, password: _password.text);
      } else {
        await _auth.signIn(email: _email.text, password: _password.text);
      }
      // The app switches to the signed-in screens underneath; close this one.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Type your email above first, then tap "Forgot password?" again.');
      return;
    }
    try {
      await _auth.sendPasswordReset(_email.text);
      if (!mounted) return;
      setState(() => _error = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('We sent a reset link to ${_email.text.trim()}.')));
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    }
  }

  void _switchMode() => setState(() {
    _signUp = !_signUp;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  SizedBox(height: constraints.maxHeight * 0.12),
                  const _Title(),
                  SizedBox(height: constraints.maxHeight * 0.1),
                  if (_signUp) ...[
                    _Field(controller: _username, hint: 'Username', action: TextInputAction.next),
                    const SizedBox(height: 22),
                  ],
                  _Field(
                    controller: _email,
                    hint: 'Email id',
                    keyboard: TextInputType.emailAddress,
                    action: TextInputAction.next,
                  ),
                  const SizedBox(height: 22),
                  _Field(
                    controller: _password,
                    hint: 'Password',
                    obscure: _hidePassword,
                    action: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    suffix: IconButton(
                      icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      color: AppColors.cream.withValues(alpha: 0.7),
                      onPressed: () => setState(() => _hidePassword = !_hidePassword),
                    ),
                  ),
                  if (!_signUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(onPressed: _forgotPassword, child: const Text('Forgot password?')),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppText.sans(size: 14, color: scheme.error),
                    ),
                  ],
                  SizedBox(height: _signUp ? 30 : 14),
                  SizedBox(
                    width: 220,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary),
                            )
                          : Text(_signUp ? 'Sign Up' : 'Log in'),
                    ),
                  ),
                  const SizedBox(height: 40),
                  ShelfLine(label: _signUp ? 'Log in ?' : 'Sign up ?', onTap: _switchMode),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "TBR" on the top half, with a small green flourish.
class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('TBR', style: AppText.serif(size: 64, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 4),
        Text('your to-be-read, sorted', style: AppText.hand(size: 22)),
      ],
    );
  }
}

/// The brown rounded text fields from nikki's design.
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboard;
  final TextInputAction? action;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  const _Field({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboard,
    this.action,
    this.onSubmitted,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      textInputAction: action,
      onSubmitted: onSubmitted,
      autocorrect: false,
      cursorColor: AppColors.cream,
      style: AppText.sans(size: 17, color: AppColors.cream),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.sans(size: 17, color: AppColors.cream.withValues(alpha: 0.7)),
        filled: true,
        fillColor: AppColors.brown,
        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
