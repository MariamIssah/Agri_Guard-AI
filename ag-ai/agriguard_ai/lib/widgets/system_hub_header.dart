import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class SystemHubHeader extends StatelessWidget {
  const SystemHubHeader({
    super.key,
    required this.title,
    required this.purpose,
    required this.icon,
    required this.gradientColors,
  });

  final String title;
  final String purpose;
  final IconData icon;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  purpose,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }
}

class DataFlowBanner extends StatelessWidget {
  const DataFlowBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      color: AgriColors.forestGreen.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync_alt_rounded,
                    color: AgriColors.forestGreen),
                const SizedBox(width: 8),
                Text(
                  'How the systems connect',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Farm Advisory collects real-time farmer data → '
              'Agri-Guard database → feeds Produce Prediction for '
              'current forecasts and model retraining.',
              style: TextStyle(
                fontSize: 13,
                color: onSurface.withValues(alpha: 0.75),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
