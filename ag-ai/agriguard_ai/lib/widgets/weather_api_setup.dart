import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_key_service.dart';
import '../utils/app_theme.dart';

class WeatherApiSetup extends StatefulWidget {
  const WeatherApiSetup({super.key, required this.onSaved});

  final VoidCallback onSaved;

  @override
  State<WeatherApiSetup> createState() => _WeatherApiSetupState();
}

class _WeatherApiSetupState extends State<WeatherApiSetup> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<ApiKeyService>().openWeatherKey ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.cloud_outlined, size: 64, color: AgriColors.sky),
        const SizedBox(height: 16),
        Text(
          'Connect OpenWeather API',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Enter your free API key from openweathermap.org to load live '
          'weather for your farm location.',
          textAlign: TextAlign.center,
          style: TextStyle(color: onSurfaceVariant, height: 1.5),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'OpenWeather API Key',
            prefixIcon: Icon(Icons.key_outlined),
            hintText: 'Paste your API key here',
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () async {
            final key = _controller.text.trim();
            if (key.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter an API key'),
                  backgroundColor: AgriColors.danger,
                ),
              );
              return;
            }
            await context.read<ApiKeyService>().saveOpenWeatherKey(key);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('API key saved'),
                backgroundColor: AgriColors.forestGreen,
              ),
            );
            widget.onSaved();
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save & Load Weather'),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AgriColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AgriColors.gold.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: AgriColors.gold),
                  SizedBox(width: 6),
                  Text(
                    'How to get a free key',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AgriColors.gold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '1. Go to openweathermap.org/api\n'
                '2. Create a free account\n'
                '3. Copy your API key from "My API keys"\n'
                '4. Paste it above and tap Save\n\n'
                'New keys can take up to 2 hours to activate.\n'
                'If you get "Invalid API key", wait and try again.',
                style: TextStyle(
                    fontSize: 12,
                    color: onSurfaceVariant,
                    height: 1.6),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
