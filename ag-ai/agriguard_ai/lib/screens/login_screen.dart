import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
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
                          onPressed: () {},
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
