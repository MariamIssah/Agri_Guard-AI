import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../utils/app_theme.dart';
import '../widgets/agri_menu_card.dart';
import '../widgets/system_hub_header.dart';
import 'map_screen.dart';
import 'prediction_screen.dart';
import 'produce_availability_screen.dart';
import 'regional_forecast_screen.dart';

class PredictionHubScreen extends StatelessWidget {
  const PredictionHubScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(title: Text(context.t('prediction_hub_title')))
          : null,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.viewPaddingOf(context).bottom + 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!showAppBar) ...[
              Text(
                context.t('prediction_hub_title'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 16),
            ],
            SystemHubHeader(
              title: context.t('prediction_hub_title'),
              purpose: context.t('prediction_hub_purpose'),
              icon: Icons.analytics_rounded,
              gradientColors: [AgriColors.wheatGold, const Color(0xFFE8B923)],
            ),
            const SizedBox(height: 24),
            Text(
              context.t('prediction_hub_features_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 14),
            AgriMenuCard(
              title: 'Prediction Dashboard',
              subtitle: 'Crop, region, quantity & confidence',
              icon: Icons.insights_rounded,
              color: AgriColors.wheatGold,
              onTap: () => _open(context, const PredictionScreen()),
            ),
            const SizedBox(height: 10),
            AgriMenuCard(
              title: 'Produce Availability',
              subtitle: 'Regional crop supply overview',
              icon: Icons.inventory_2_outlined,
              color: AgriColors.forestGreen,
              onTap: () => _open(context, const ProduceAvailabilityScreen()),
            ),
            const SizedBox(height: 10),
            AgriMenuCard(
              title: 'Produce Map',
              subtitle: 'Farmers, locations & expected quantity',
              icon: Icons.map_rounded,
              color: AgriColors.leafGreen,
              onTap: () => _open(context, const MapScreen()),
            ),
            const SizedBox(height: 10),
            AgriMenuCard(
              title: 'Regional Forecast',
              subtitle: 'Production trends by region',
              icon: Icons.trending_up_rounded,
              color: AgriColors.sky,
              onTap: () => _open(context, const RegionalForecastScreen()),
            ),
            const SizedBox(height: 24),
            Text(
              context.t('prediction_hub_model_inputs_title'),
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
                    _inputRow(context, Icons.history_rounded,
                        context.t('prediction_hub_input_historical')),
                    const Divider(height: 20),
                    _inputRow(context, Icons.people_outline,
                        context.t('prediction_hub_input_farmer')),
                    const Divider(height: 20),
                    _inputRow(context, Icons.cloud_outlined,
                        context.t('prediction_hub_input_weather')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: AgriColors.wheatGold.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.model_training_rounded,
                        color: AgriColors.wheatGold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Output: Trained model that predicts harvest quantity, '
                        'availability dates, and regional distribution.',
                        style: TextStyle(
                          fontSize: 13,
                          color: onSurface,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputRow(BuildContext context, IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: AgriColors.forestGreen, size: 22),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
        ),
      ],
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}
