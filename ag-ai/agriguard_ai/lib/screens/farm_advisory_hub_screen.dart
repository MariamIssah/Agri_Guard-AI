import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../utils/app_theme.dart';
import '../widgets/agri_menu_card.dart';
import '../widgets/system_hub_header.dart';
import 'disease_screen.dart';
import 'farm_activity_screen.dart';
import 'farm_registration_screen.dart';
import 'farmer_registration_screen.dart';
import 'weather_screen.dart';

class FarmAdvisoryHubScreen extends StatelessWidget {
  const FarmAdvisoryHubScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(title: Text(context.t('farm_advisory_title')))
          : null,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.viewPaddingOf(context).bottom + 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!showAppBar) ...[
              Text(
                'Farm Advisory System',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 16),
            ],
            SystemHubHeader(
              title: context.t('farm_advisory_title'),
              purpose: context.t('farm_advisory_purpose'),
              icon: Icons.agriculture_rounded,
              gradientColors: [AgriColors.forestGreen, AgriColors.leafGreen],
            ),
            const SizedBox(height: 24),
            Text(
              'Features',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 14),
            AgriMenuCard(
              title: 'Farmer Registration',
              subtitle: 'Name, phone & location details',
              icon: Icons.person_add_alt_1_rounded,
              color: AgriColors.forestGreen,
              onTap: () => _open(context, const FarmerRegistrationScreen()),
            ),
            const SizedBox(height: 10),
            AgriMenuCard(
              title: 'Farm Registration',
              subtitle: 'Farm name, size, crop & GPS',
              icon: Icons.landscape_rounded,
              color: AgriColors.leafGreen,
              onTap: () => _open(context, const FarmRegistrationScreen()),
            ),
            const SizedBox(height: 10),
            AgriMenuCard(
              title: 'Farm Activity Tracking',
              subtitle: 'Planting, stages & fertilizer logs',
              icon: Icons.event_note_rounded,
              color: AgriColors.wheatGold,
              onTap: () => _open(context, const FarmActivityScreen()),
            ),
            const SizedBox(height: 10),
            AgriMenuCard(
              title: 'Weather Advisory',
              subtitle: 'Temperature, humidity, rainfall & wind',
              icon: Icons.wb_sunny_rounded,
              color: AgriColors.sky,
              onTap: () => _open(context, const WeatherScreen()),
            ),
            const SizedBox(height: 10),
            AgriMenuCard(
              title: context.t('farm_advisory_card_disease'),
              subtitle: context.t('farm_advisory_card_disease_desc'),
              icon: Icons.healing_rounded,
              color: AgriColors.danger,
              onTap: () => _open(context, const DiseaseScreen()),
            ),
            const SizedBox(height: 24),
            Text(
              context.t('home_section_data'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _dataItem(context, Icons.person_outline, 'Farmer Information'),
                    _dataItem(context, Icons.landscape_outlined, 'Farm Information'),
                    _dataItem(context, Icons.grass_rounded, 'Crop Information'),
                    _dataItem(context, Icons.cloud_outlined, 'Weather Information'),
                    _dataItem(context, Icons.event_note_outlined, 'Farm Activities'),
                    _dataItem(context, Icons.biotech_outlined, 'Disease Reports'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.t('home_data_flow'),
              style: TextStyle(
                fontSize: 13,
                color: onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dataItem(BuildContext context, IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AgriColors.leafGreen),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}
