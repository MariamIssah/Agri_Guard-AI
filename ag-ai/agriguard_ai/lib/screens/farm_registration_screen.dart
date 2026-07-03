import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../models/location_data.dart';
import '../utils/app_theme.dart';
import '../widgets/location_picker.dart';

class FarmRegistrationScreen extends StatefulWidget {
  const FarmRegistrationScreen({super.key});

  @override
  State<FarmRegistrationScreen> createState() => _FarmRegistrationScreenState();
}

class _FarmRegistrationScreenState extends State<FarmRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _cropType;
  LocationData _location = const LocationData();

  static const _crops = ['Maize', 'Rice', 'Cassava', 'Yam', 'Tomato', 'Cocoa'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('farm_registration_title'))),
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
                    context.t('farm_registration_subtitle'),
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: InputDecoration(
                  labelText: context.t('farm_registration_name'),
                  prefixIcon: const Icon(Icons.home_work_outlined),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter farm name' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.t('farm_registration_size'),
                  prefixIcon: const Icon(Icons.square_foot_rounded),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter farm size' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _cropType,
                decoration: InputDecoration(
                  labelText: context.t('farm_registration_crop'),
                  prefixIcon: const Icon(Icons.grass_rounded),
                ),
                items: _crops
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _cropType = v),
                validator: (v) => v == null ? 'Select crop type' : null,
              ),
              const SizedBox(height: 24),
              LocationPicker(
                title: 'Farm Location (GPS)',
                onChanged: (loc) => setState(() => _location = loc),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () {
                  final locError = validateLocation(_location);
                  if (!_formKey.currentState!.validate() || locError != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(locError ?? context.t('farm_registration_button')),
                        backgroundColor: AgriColors.dangerRed,
                      ),
                    );
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Farm registered at ${_location.town}, '
                        '${_location.district}',
                      ),
                      backgroundColor: AgriColors.forestGreen,
                    ),
                  );
                  Navigator.pop(context);
                },
                child: Text(context.t('farm_registration_button')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
