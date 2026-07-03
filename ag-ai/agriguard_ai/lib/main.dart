import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'localization/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'services/api_key_service.dart';
import 'services/auth_service.dart';
import 'services/backend_service.dart';
import 'services/location_session.dart';
import 'services/theme_notifier.dart';
import 'services/user_session.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiKeyService = ApiKeyService();
  await apiKeyService.load();

  final themeNotifier = await ThemeNotifier.load();

  // BackendService must be created before AuthService (auth calls the backend)
  final backendService = BackendService(apiKeyService: apiKeyService);
  final authService = AuthService(backendService);
  await authService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserSession()),
        ChangeNotifierProvider(create: (_) => LocationSession()),
        ChangeNotifierProvider.value(value: apiKeyService),
        // Keep the ProxyProvider so context.read<BackendService>() still works
        ProxyProvider<ApiKeyService, BackendService>(
          update: (_, keys, prev) => backendService,
        ),
        ChangeNotifierProvider.value(value: themeNotifier),
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider(create: (_) => AppLocalizations()),
      ],
      child: const AgriGuardApp(),
    ),
  );
}

class AgriGuardApp extends StatelessWidget {
  const AgriGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = context.watch<AppLocalizations>();
    final themeNotifier = context.watch<ThemeNotifier>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Agri-Guard AI',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeNotifier.themeMode,
      locale: localizations.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
    );
  }
}
