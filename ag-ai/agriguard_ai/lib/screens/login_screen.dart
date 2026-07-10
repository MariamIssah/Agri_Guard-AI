import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../services/user_session.dart';
import '../utils/app_theme.dart';
import 'main_shell.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscure = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthService>();
      await auth.login(email: _emailCtrl.text.trim(), password: _pwCtrl.text);
      if (!mounted) return;
      final user = auth.currentUser!;
      context.read<UserSession>().setRole(user.role);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Login failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AgriColors.danger, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthService>();
      await auth.loginWithGoogle();
      if (!mounted) return;
      // Always show role picker so user can confirm farmer or buyer
      await _pickRoleForNewGoogleUser();
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRoleForNewGoogleUser() async {
    final auth = context.read<AuthService>();
    final role = await showModalBottomSheet<UserRole>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RolePickerSheet(),
    );
    if (!mounted) return;
    if (role != null) {
      try {
        await auth.updateRole(role);
      } catch (_) {}
    }
    if (!mounted) return;
    final user = auth.currentUser!;
    context.read<UserSession>().setRole(user.role);
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const MainShell()));
  }

  void _showForgotPassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ForgotPasswordSheet(
        backend: context.read<BackendService>(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = isDark ? darkHeaderGradient : lightHeaderGradient;

    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.viewPaddingOf(context).bottom;
    final screenH = MediaQuery.sizeOf(context).height;
    final heroBot = screenH < 680 ? 28.0 : 44.0;
    final heroTop = topPad + (screenH < 680 ? 16.0 : 32.0);

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: botPad),
          child: Column(
            children: [
              // ── Hero header ───────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(28, heroTop, 28, heroBot),
                decoration: BoxDecoration(gradient: gradient),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: (isDark ? AgriColors.white : AgriColors.white).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (isDark ? AgriColors.white : AgriColors.white).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(Icons.eco_rounded, size: 36,
                          color: isDark ? AgriColors.white : AgriColors.white),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Agri-Guard AI',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AgriColors.white : AgriColors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Agricultural Intelligence & Crop Advisory',
                      style: TextStyle(
                        fontSize: 14,
                        color: (isDark ? AgriColors.white : AgriColors.white).withValues(alpha: 0.8),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Form ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Welcome back',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in to your account',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Email
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email is required';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _pwCtrl,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password is required';
                          if (v.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Login button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(
                                  height: 22, width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                )
                              : const Text('Sign In'),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Divider
                      Row(children: [
                        Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or', style: Theme.of(context).textTheme.bodySmall),
                        ),
                        Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                      ]),
                      const SizedBox(height: 16),

                      // Google Sign-In
                      SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _loading ? null : _googleSignIn,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: Theme.of(context).dividerColor, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _GoogleLogo(),
                              const SizedBox(width: 12),
                              const Text('Continue with Google',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 15)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Sign up
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Don't have an account? ",
                              style: Theme.of(context).textTheme.bodyMedium),
                          GestureDetector(
                            onTap: () => Navigator.push(
                                context, MaterialPageRoute(builder: (_) => const SignupScreen())),
                            child: Text(
                              'Sign up',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Google logo (coloured G drawn with Text, no asset needed) ─────────────────

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final cx = r, cy = r;
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw coloured arc segments of the G
    final segments = [
      (0.0, 90.0, const Color(0xFF4285F4)),
      (90.0, 90.0, const Color(0xFF34A853)),
      (180.0, 90.0, const Color(0xFFFBBC05)),
      (270.0, 90.0, const Color(0xFFEA4335)),
    ];
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    for (final (start, sweep, color) in segments) {
      paint.color = color;
      final path = Path()
        ..moveTo(cx, cy)
        ..arcTo(rect, _rad(start), _rad(sweep), false)
        ..close();
      canvas.drawPath(path, paint);
    }

    // White inner circle
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.65, paint);

    // Blue right arm of the G
    paint.color = const Color(0xFF4285F4);
    final armRect = Rect.fromLTWH(cx, cy - r * 0.13, r * 1.02, r * 0.26);
    canvas.drawRect(armRect, paint);
  }

  double _rad(double deg) => deg * 3.14159265 / 180;

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── Role picker sheet (shown once for new Google users) ────────────────────────

class _RolePickerSheet extends StatelessWidget {
  const _RolePickerSheet();

  @override
  Widget build(BuildContext context) {
    final botPad = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, botPad + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Continue as...',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Choose how you want to use Agri-Guard AI.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          _RoleOption(
            role: UserRole.farmer,
            icon: Icons.agriculture_rounded,
            color: AgriColors.forestGreen,
            title: 'Farmer',
            subtitle: 'Get yield forecasts, crop advice, and list your produce',
          ),
          const SizedBox(height: 12),
          _RoleOption(
            role: UserRole.buyer,
            icon: Icons.storefront_rounded,
            color: AgriColors.sky,
            title: 'Buyer / Trader',
            subtitle: 'Browse market availability and contact farmers directly',
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
  final UserRole role;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pop(context, role),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          color: color.withValues(alpha: 0.06),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ]),
      ),
    );
  }
}

// ── Forgot password bottom sheet ───────────────────────────────────────────────

class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet({required this.backend});
  final BackendService backend;

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _emailCtrl   = TextEditingController();
  final _nameCtrl    = TextEditingController();
  final _pw1Ctrl     = TextEditingController();
  final _pw2Ctrl     = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  int  _step    = 0; // 0=email, 1=name+newpw, 2=success
  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose(); _nameCtrl.dispose();
    _pw1Ctrl.dispose();   _pw2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await widget.backend.resetPassword(
        email:       _emailCtrl.text.trim(),
        name:        _nameCtrl.text.trim(),
        newPassword: _pw1Ctrl.text,
      );
      if (mounted) setState(() { _step = 2; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('BackendException: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final botPad = MediaQuery.viewPaddingOf(context).bottom;
    final keyboardH = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.92;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(maxHeight: maxH),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 16, 24, botPad + 24 + keyboardH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (_step == 2) ...[
            // ── Success ──────────────────────────────────────────────────────
            const Icon(Icons.check_circle_rounded,
                color: AgriColors.forestGreen, size: 56),
            const SizedBox(height: 16),
            Text('Password Updated',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('You can now log in with your new password.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AgriColors.forestGreen,
                  foregroundColor: Colors.white),
              child: const Text('Back to Login'),
            ),
          ] else ...[
            // ── Title ─────────────────────────────────────────────────────────
            Text('Reset Password',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              _step == 0
                  ? 'Enter the email address on your account.'
                  : 'Enter your full name as registered, then choose a new password.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Step 0 — email
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    readOnly: _step == 1,
                    decoration: InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: const Icon(Icons.email_outlined),
                      suffixIcon: _step == 1
                          ? IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Change email',
                              onPressed: () => setState(() => _step = 0),
                            )
                          : null,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter your email';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),

                  // Step 1 — name + new password
                  if (_step == 1) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full name (as registered)',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                        helperText: 'Must match the name you signed up with exactly',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Enter your full name' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _pw1Ctrl,
                      obscureText: _obscure1,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure1
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure1 = !_obscure1),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter a new password';
                        if (v.length < 6) return 'At least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _pw2Ctrl,
                      obscureText: _obscure2,
                      decoration: InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure2
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure2 = !_obscure2),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Confirm your password';
                        if (v != _pw1Ctrl.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AgriColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AgriColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AgriColors.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!,
                      style: const TextStyle(color: AgriColors.danger, fontSize: 13))),
                ]),
              ),
            ],

            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _loading
                    ? null
                    : () {
                        if (_step == 0) {
                          if (_formKey.currentState!.validate()) {
                            setState(() { _step = 1; _error = null; });
                          }
                        } else {
                          _submit();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AgriColors.forestGreen,
                  foregroundColor: Colors.white,
                ),
                child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : Text(_step == 0 ? 'Continue' : 'Reset Password'),
              ),
            ),
          ],
        ],
        ),
      ),
    );
  }
}
