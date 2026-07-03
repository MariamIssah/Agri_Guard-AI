import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../models/location_data.dart';
import '../utils/app_theme.dart';
import '../widgets/location_picker.dart';

class FarmerRegistrationScreen extends StatefulWidget {
  const FarmerRegistrationScreen({super.key});

  @override
  State<FarmerRegistrationScreen> createState() =>
      _FarmerRegistrationScreenState();
}

class _FarmerRegistrationScreenState extends State<FarmerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  LocationData _location = const LocationData();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('farmer_registration_title'))),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewPaddingOf(context).bottom + 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: AgriColors.mintGreen.withValues(alpha: 0.2),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    context.t('farmer_registration_instructions'),
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: InputDecoration(
                  labelText: context.t('farmer_registration_full_name'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? context.t('farmer_registration_name_error') : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: context.t('farmer_registration_phone'),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? context.t('farmer_registration_phone_error') : null,
              ),
              const SizedBox(height: 24),
              LocationPicker(
                title: context.t('farmer_registration_location_title'),
                onChanged: (loc) => setState(() => _location = loc),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () {
                  final locError = validateLocation(_location);
                  if (!_formKey.currentState!.validate() || locError != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(locError ?? context.t('farmer_registration_complete_form')),
                        backgroundColor: AgriColors.dangerRed,
                      ),
                    );
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${context.t('farmer_registration_success_prefix')} ${_location.town}, ${_location.region}',
                      ),
                      backgroundColor: AgriColors.forestGreen,
                    ),
                  );
                  Navigator.pop(context);
                },
                child: Text(context.t('farmer_registration_button')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
