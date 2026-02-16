import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/app_repository.dart';
import 'services/tracking_service.dart';

enum _AuthStep {
  signIn,
  signUp,
  otp,
  fillProfile,
}

enum _OtpUiState {
  idle,
  verifying,
  success,
  error,
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final AppRepository _repository = AppRepository.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();

  final List<TextEditingController> _otpControllers =
      List<TextEditingController>.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpNodes =
      List<FocusNode>.generate(6, (_) => FocusNode());

  _AuthStep _step = _AuthStep.signIn;
  _OtpUiState _otpUiState = _OtpUiState.idle;

  bool _loading = false;
  String? _error;
  String? _otpEmail;

  Timer? _usernameDebounce;
  bool _checkingUsername = false;
  bool? _usernameAvailable;

  String _gender = 'female';
  DateTime _birthDate = DateTime(2000, 1, 1);

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    _usernameDebounce?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final n in _otpNodes) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (_repository.currentUser == null) return;
    final profile = await _repository.ensureCurrentProfile();
    if (!mounted || profile == null) return;
    if (profile.onboardingCompleted) {
      Navigator.pushReplacementNamed(context, '/feed');
      return;
    }
    setState(() => _step = _AuthStep.fillProfile);
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email and password are required.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _repository.signIn(email: email, password: password);
      final profile = await _repository.ensureCurrentProfile();
      if (!mounted) return;
      if (profile?.onboardingCompleted == true) {
        Navigator.pushReplacementNamed(context, '/feed');
      } else {
        setState(() => _step = _AuthStep.fillProfile);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email and password are required.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _repository.signUp(email: email, password: password);
      if (!mounted) return;
      setState(() {
        _step = _AuthStep.otp;
        _otpEmail = email;
        _otpUiState = _OtpUiState.idle;
      });
      _clearOtp();
      _otpNodes.first.requestFocus();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _clearOtp() {
    for (final c in _otpControllers) {
      c.text = '';
    }
  }

  String _otpValue() {
    return _otpControllers.map((e) => e.text).join();
  }

  Future<void> _verifyOtp() async {
    final email = _otpEmail;
    if (email == null || email.isEmpty) {
      setState(() {
        _otpUiState = _OtpUiState.error;
        _error = 'Missing signup email for OTP verification.';
      });
      return;
    }

    final code = _otpValue();
    if (code.length != 6 || _otpUiState == _OtpUiState.verifying) return;

    setState(() {
      _otpUiState = _OtpUiState.verifying;
      _error = null;
    });

    try {
      await _repository.verifySignUpOtp(email: email, token: code);
      if (!mounted) return;
      setState(() => _otpUiState = _OtpUiState.success);
      await Future<void>.delayed(const Duration(milliseconds: 320));
      if (!mounted) return;
      setState(() => _step = _AuthStep.fillProfile);
      TrackingService.instance.setTrackerUiVisible(false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _otpUiState = _OtpUiState.error;
        _error = 'OTP is not correct.';
      });
      _clearOtp();
      _otpNodes.first.requestFocus();
    }
  }

  void _onOtpChanged(int index, String value) {
    if (value.length > 1) {
      _otpControllers[index].text = value.substring(value.length - 1);
      _otpControllers[index].selection = const TextSelection.collapsed(offset: 1);
    }

    if (value.isNotEmpty && index < _otpNodes.length - 1) {
      _otpNodes[index + 1].requestFocus();
    }

    if (_otpUiState == _OtpUiState.error) {
      setState(() {
        _otpUiState = _OtpUiState.idle;
        _error = null;
      });
    }

    final code = _otpValue();
    if (code.length == 6) {
      _verifyOtp();
    }
  }

  void _onOtpBackspace(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey != LogicalKeyboardKey.backspace) return;
    if (_otpControllers[index].text.isNotEmpty) return;
    if (index == 0) return;
    _otpNodes[index - 1].requestFocus();
  }

  void _onUsernameChanged() {
    _usernameDebounce?.cancel();
    final value = _usernameController.text.trim();
    if (value.length < 3) {
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = null;
      });
      return;
    }

    _usernameDebounce = Timer(const Duration(milliseconds: 320), () async {
      setState(() => _checkingUsername = true);
      final available = await _repository.isUsernameAvailable(value);
      if (!mounted) return;
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = available;
      });
    });
  }

  Future<void> _finishProfile() async {
    final username = _usernameController.text.trim().toLowerCase();
    if (username.length < 3) {
      setState(() => _error = 'Username must be at least 3 characters.');
      return;
    }
    if (_usernameAvailable == false) {
      setState(() => _error = 'Username is already taken.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _repository.completeOnboarding(
        username: username,
        fullName: _fullNameController.text.trim(),
        gender: _gender,
        birthDate: _birthDate,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/feed');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.brightness == Brightness.dark
                ? const <Color>[Color(0xFF050B14), Color(0xFF0A1628)]
                : const <Color>[Color(0xFFF4F8FF), Color(0xFFE9F1FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: _buildStepContent(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(ThemeData theme) {
    switch (_step) {
      case _AuthStep.signIn:
      case _AuthStep.signUp:
        return _buildAuthForm(theme);
      case _AuthStep.otp:
        return _buildOtpForm(theme);
      case _AuthStep.fillProfile:
        return _buildFillProfile(theme);
    }
  }

  Widget _buildAuthForm(ThemeData theme) {
    final cs = theme.colorScheme;
    final bool signIn = _step == _AuthStep.signIn;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          signIn ? 'Welcome Back' : 'Create Your Account',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          signIn
              ? 'Sign in to DeepX and continue building immersive presets.'
              : 'Sign up and verify your email with a 6-digit OTP.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : (signIn ? _signIn : _signUp),
            child: Text(_loading
                ? 'Please wait...'
                : (signIn ? 'Sign In' : 'Sign Up & Send OTP')),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _loading
              ? null
              : () {
                  setState(() {
                    _error = null;
                    _step = signIn ? _AuthStep.signUp : _AuthStep.signIn;
                  });
                },
          child: Text(signIn
              ? 'Need an account? Create one'
              : 'Already have an account? Sign in'),
        ),
      ],
    );
  }

  Widget _buildOtpForm(ThemeData theme) {
    final cs = theme.colorScheme;

    Color borderColorFor(String value) {
      if (_otpUiState == _OtpUiState.error) return Colors.redAccent;
      if (_otpUiState == _OtpUiState.success) return Colors.green;
      if (value.isNotEmpty) return cs.primary;
      return cs.outline.withValues(alpha: 0.5);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Verify Email',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Enter the 6-digit OTP sent to ${_otpEmail ?? _emailController.text.trim()}.',
          style:
              theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(6, (index) {
            final controller = _otpControllers[index];
            return Container(
              width: 52,
              height: 64,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: borderColorFor(controller.text),
                  width: 2,
                ),
                color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
              ),
              child: Focus(
                onKeyEvent: (_, event) {
                  _onOtpBackspace(index, event);
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: controller,
                  focusNode: _otpNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                  ),
                  onChanged: (value) => _onOtpChanged(index, value),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
        if (_otpUiState == _OtpUiState.verifying)
          Text(
            'Verifying OTP...',
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.primary),
          ),
        if (_error != null)
          Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent),
          ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            TextButton(
              onPressed: _loading
                  ? null
                  : () {
                      setState(() {
                        _error = null;
                        _otpUiState = _OtpUiState.idle;
                        _step = _AuthStep.signUp;
                      });
                    },
              child: const Text('Back'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFillProfile(ThemeData theme) {
    final cs = theme.colorScheme;

    final usernameHelper = _checkingUsername
        ? 'Checking username...'
        : (_usernameAvailable == null
            ? '3+ chars, lowercase recommended'
            : (_usernameAvailable!
                ? 'Username is available'
                : 'Username is already taken'));

    final usernameColor = _checkingUsername
        ? cs.primary
        : (_usernameAvailable == null
            ? cs.onSurfaceVariant
            : (_usernameAvailable! ? Colors.green : Colors.redAccent));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Fill Your Profile',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Complete setup before entering DeepX.',
          style:
              theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: 'Username',
            prefixText: '@',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          usernameHelper,
          style: TextStyle(color: usernameColor, fontSize: 12),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _fullNameController,
          decoration: const InputDecoration(labelText: 'Full Name (optional)'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _gender,
          decoration: const InputDecoration(labelText: 'Gender'),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem(value: 'female', child: Text('Female')),
            DropdownMenuItem(value: 'male', child: Text('Male')),
            DropdownMenuItem(value: 'non_binary', child: Text('Non-binary')),
            DropdownMenuItem(value: 'prefer_not_to_say', child: Text('Prefer not to say')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _gender = value);
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Birth Date',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 150,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness:
                  theme.brightness == Brightness.dark ? Brightness.dark : Brightness.light,
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _birthDate,
              minimumDate: DateTime(1950, 1, 1),
              maximumDate: DateTime.now().subtract(const Duration(days: 3650)),
              onDateTimeChanged: (value) => _birthDate = value,
            ),
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _finishProfile,
            child: Text(_loading ? 'Saving...' : 'Continue to DeepX'),
          ),
        ),
      ],
    );
  }
}
