import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/user_session.dart';
import '../utils/app_theme.dart';
import '../utils/ghana_locations.dart';
import 'main_shell.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  final _farmSizeCtrl = TextEditingController();

  UserRole _role = UserRole.farmer;
  String? _selectedRegion;
  String? _selectedDistrict;
  bool _obscurePw = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  int _step = 0; // 0=basic info, 1=role & farm details

  final List<String> _regions = GhanaLocations.regions;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _pwCtrl.dispose();
    _confirmPwCtrl.dispose();
    _farmSizeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final auth = context.read<AuthService>();
      await auth.register(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        password: _pwCtrl.text,
        role: _role,
        region: _selectedRegion,
        district: _selectedDistrict,
        farmSizeHa: double.tryParse(_farmSizeCtrl.text.trim()),
      );
      if (!mounted) return;
      context.read<UserSession>().setRole(_role);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Registration failed. Please try again.');
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
    final headerBot = screenH < 680 ? 16.0 : 24.0;
    final headerTop = topPad + (screenH < 680 ? 12.0 : 20.0);

    return Scaffold(
      body: Column(
        children: [
          // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, headerTop, 24, headerBot),
            decoration: BoxDecoration(gradient: gradient),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded,
                      color: isDark ? AgriColors.white : AgriColors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800,
                        color: isDark ? AgriColors.white : AgriColors.white,
                      ),
                    ),
                    Text(
                      _step == 0 ? 'Step 1 of 2 — Personal info' : 'Step 2 of 2 — Role & farm details',
                      style: TextStyle(
                        fontSize: 13,
                        color: (isDark ? AgriColors.white : AgriColors.white).withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // â”€â”€ Progress bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          LinearProgressIndicator(
            value: _step == 0 ? 0.5 : 1.0,
            backgroundColor: Theme.of(context).colorScheme.outline,
            color: Theme.of(context).colorScheme.primary,
            minHeight: 3,
          ),

          // â”€â”€ Form â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, botPad + 24),
              child: Form(
                key: _formKey,
                child: _step == 0 ? _buildStep1() : _buildStep2(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _field(_nameCtrl, 'Full name', Icons.person_outline_rounded,
            action: TextInputAction.next,
            validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your full name' : null),
        const SizedBox(height: 16),
        _field(_emailCtrl, 'Email address', Icons.mail_outline_rounded,
            type: TextInputType.emailAddress,
            action: TextInputAction.next,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            }),
        const SizedBox(height: 16),
        _field(_phoneCtrl, 'Phone number', Icons.phone_outlined,
            type: TextInputType.phone,
            action: TextInputAction.next,
            validator: (v) => (v == null || v.trim().length < 7) ? 'Enter a valid phone number' : null),
        const SizedBox(height: 16),
        _passwordField(_pwCtrl, 'Password', _obscurePw,
            () => setState(() => _obscurePw = !_obscurePw),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'At least 6 characters';
              return null;
            }),
        const SizedBox(height: 16),
        _passwordField(_confirmPwCtrl, 'Confirm password', _obscureConfirm,
            () => setState(() => _obscureConfirm = !_obscureConfirm),
            validator: (v) => v != _pwCtrl.text ? 'Passwords do not match' : null),
        const SizedBox(height: 32),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) setState(() => _step = 1);
            },
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final districts = _selectedRegion != null
        ? GhanaLocations.districtsFor(_selectedRegion!)
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        // Role selector
        Text('I am a', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _roleCard(UserRole.farmer, 'Farmer', Icons.agriculture_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _roleCard(UserRole.buyer, 'Buyer / Stakeholder', Icons.store_rounded)),
          ],
        ),
        const SizedBox(height: 24),

        // Region
        DropdownButtonFormField<String>(
          isExpanded: true,
          // ignore: deprecated_member_use
          value: _selectedRegion,
          decoration: InputDecoration(
            labelText: 'Region',
            prefixIcon: const Icon(Icons.map_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          items: _regions.map((r) => DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() {
            _selectedRegion = v;
            _selectedDistrict = null;
          }),
          validator: (v) => _role == UserRole.farmer && v == null ? 'Select your region' : null,
        ),
        const SizedBox(height: 16),

        // District
        if (districts.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            isExpanded: true,
            // ignore: deprecated_member_use
            value: _selectedDistrict,
            decoration: InputDecoration(
              labelText: 'District',
              prefixIcon: const Icon(Icons.location_city_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            items: districts.map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _selectedDistrict = v),
          ),
          const SizedBox(height: 16),
        ],

        // Farm size (farmers only)
        if (_role == UserRole.farmer) ...[
          TextFormField(
            controller: _farmSizeCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Farm size (hectares)',
              prefixIcon: const Icon(Icons.square_foot_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              suffixText: 'ha',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null; // optional
              if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
              return null;
            },
          ),
          const SizedBox(height: 16),
        ],

        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 22, width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Create Account'),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() => _step = 0),
          child: const Text('â† Back'),
        ),
      ],
    );
  }

  Widget _roleCard(UserRole role, String label, IconData icon) {
    final selected = _role == role;
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () => setState(() => _role = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : Theme.of(context).iconTheme.color, size: 28),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? color : null,
                )),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    TextInputAction action = TextInputAction.next,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      textInputAction: action,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }

  Widget _passwordField(
    TextEditingController ctrl,
    String label,
    bool obscure,
    VoidCallback toggle, {
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: toggle,
        ),
      ),
      validator: validator,
    );
  }
}

