import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import 'login_screen.dart';

const _kConsentKey = 'consent_given';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _agreed = false;
  bool _saving = false;

  Future<void> _accept() async {
    if (!_agreed) return;
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kConsentKey, true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _decline() async {
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cannot Continue'),
        content: const Text(
          'AgriGuard needs your agreement to store and process your '
          'farm data in order to provide yield predictions and crop '
          'advisory services. Without this consent, the app cannot function.\n\n'
          'You can close the app or go back and accept to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = isDark ? darkHeaderGradient : lightHeaderGradient;
    final botPad = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(gradient: gradient),
            padding: EdgeInsets.fromLTRB(
                24, MediaQuery.viewPaddingOf(context).top + 32, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: const Icon(Icons.shield_outlined,
                      size: 30, color: Colors.white),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Privacy & Data Consent',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Please read how Agri-Guard AI uses your information '
                  'before you create an account.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable body ─────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 24, 20, botPad + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Section(
                    icon: Icons.person_outline_rounded,
                    color: AgriColors.forestGreen,
                    title: 'Account Information',
                    body:
                        'When you register, we collect your name, email address, '
                        'phone number, role (farmer or buyer), and region. '
                        'This is used to identify you, secure your account, '
                        'and personalise your experience.',
                  ),
                  _Section(
                    icon: Icons.agriculture_rounded,
                    color: AgriColors.leafGreen,
                    title: 'Farm & Harvest Data',
                    body:
                        'Farmers can record crops, farm size, diary entries, and '
                        'actual harvest weights. This data is stored securely and '
                        'used to generate yield forecasts and crop advisory '
                        'specific to your farm.',
                  ),
                  _Section(
                    icon: Icons.model_training_rounded,
                    color: AgriColors.sky,
                    title: 'Model Training (Optional)',
                    body:
                        'With your explicit consent at the time of harvest '
                        'submission, your yield figures may be used — fully '
                        'anonymised — to improve AgriGuard\'s prediction model. '
                        'No personal details are ever shared. '
                        'You choose this separately for each submission.',
                  ),
                  _Section(
                    icon: Icons.storefront_outlined,
                    color: AgriColors.gold,
                    title: 'Marketplace Listing (Optional)',
                    body:
                        'Farmers can choose to list their produce so buyers can '
                        'contact them. Your phone number and location are only '
                        'shared with buyers when you explicitly tick "List my '
                        'produce in the marketplace" on a harvest submission. '
                        'You control this for every submission.',
                  ),
                  _Section(
                    icon: Icons.lock_outline_rounded,
                    color: Colors.blueGrey,
                    title: 'Data Security & Your Rights',
                    body:
                        'Your data is stored in a secured database. You can '
                        'delete your account at any time from your profile — '
                        'this removes your personal details while keeping '
                        'anonymised harvest figures for model integrity. '
                        'We do not sell your data to third parties.',
                  ),

                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 16),

                  // ── Consent checkbox ───────────────────────────────────────
                  InkWell(
                    onTap: () => setState(() => _agreed = !_agreed),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _agreed
                              ? AgriColors.forestGreen.withValues(alpha: 0.6)
                              : Theme.of(context).dividerColor,
                          width: 1.5,
                        ),
                        color: _agreed
                            ? AgriColors.forestGreen.withValues(alpha: 0.07)
                            : Colors.transparent,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _agreed,
                            onChanged: (v) =>
                                setState(() => _agreed = v ?? false),
                            activeColor: AgriColors.forestGreen,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: RichText(
                                text: TextSpan(
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(height: 1.45),
                                  children: const [
                                    TextSpan(
                                      text: 'I have read and understood '
                                          'the above. I agree that '
                                          'Agri-Guard AI may collect and '
                                          'process my personal and farm '
                                          'data as described to provide '
                                          'its services.',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Get Started button ─────────────────────────────────────
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_agreed && !_saving) ? _accept : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AgriColors.forestGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AgriColors.forestGreen.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : const Text(
                              'Get Started',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Decline ────────────────────────────────────────────────
                  Center(
                    child: TextButton(
                      onPressed: _decline,
                      child: Text(
                        'Decline',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section widget ─────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(body,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
