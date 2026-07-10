import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/user_session.dart';
import '../utils/app_theme.dart';
import 'consent_screen.dart';
import 'login_screen.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2200), _navigate);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final consentGiven = prefs.getBool('consent_given') ?? false;
    if (!mounted) return;

    if (!consentGiven) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const ConsentScreen()));
      return;
    }

    final auth = context.read<AuthService>();
    if (auth.isLoggedIn) {
      context.read<UserSession>().setRole(auth.currentUser!.role);
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const MainShell()));
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = isDark ? darkHeaderGradient : lightHeaderGradient;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: gradient),
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                  ),
                  child: const Icon(Icons.eco_rounded, size: 56, color: Colors.white),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Agri-Guard AI',
                style: TextStyle(
                  fontSize: 36, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Agricultural Intelligence & Crop Advisory',
                style: TextStyle(
                  fontSize: 14, color: Colors.white.withValues(alpha: 0.85),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 60),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
