import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../utils/ghana_locations.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  String? _region;
  String? _district;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _nameCtrl  = TextEditingController(text: user?.name ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _region    = user?.region;
    _district  = user?.district;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await context.read<AuthService>().updateProfile(
        name:     _nameCtrl.text.trim(),
        phone:    _phoneCtrl.text.trim(),
        region:   _region,
        district: _district,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully'),
              backgroundColor: AgriColors.forestGreen),
        );
        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message),
              backgroundColor: AgriColors.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'),
              backgroundColor: AgriColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final regions = ghanaRegionNames;
    final districts = _region != null
        ? districtsForRegion(_region!)
        : <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text('Save',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Personal Information',
                style: TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AgriColors.forestGreen)),
            const SizedBox(height: 12),

            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '+233 XX XXX XXXX',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),

            const Text('Location',
                style: TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AgriColors.forestGreen)),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _region,
              decoration: const InputDecoration(
                labelText: 'Region',
                prefixIcon: Icon(Icons.map_outlined),
              ),
              items: regions
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() {
                _region = v;
                _district = null;
              }),
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              value: _district,
              decoration: const InputDecoration(
                labelText: 'District',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              items: districts
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: districts.isEmpty
                  ? null
                  : (v) => setState(() => _district = v),
              hint: districts.isEmpty
                  ? const Text('Select a region first')
                  : null,
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving…' : 'Save Changes'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
