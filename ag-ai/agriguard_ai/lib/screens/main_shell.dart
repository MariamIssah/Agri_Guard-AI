import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../models/user_role.dart';
import '../services/user_session.dart';
import '../utils/app_theme.dart';
import 'admin_screen.dart';
import 'disease_screen.dart';
import 'farm_advisory_hub_screen.dart';
import 'home_screen.dart';
import 'prediction_hub_screen.dart';
import 'produce_availability_screen.dart';
import 'profile_screen.dart';
import 'regional_forecast_screen.dart';
import 'search_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _farmerIndex = 0;
  int _buyerIndex = 0;
  UserRole? _lastRole;

  @override
  Widget build(BuildContext context) {
    final role = context.watch<UserSession>().role;

    // Reset index whenever the role changes (e.g. after role-switch)
    if (role != _lastRole) {
      _lastRole = role;
      _farmerIndex = 0;
      _buyerIndex = 0;
    }

    if (role == UserRole.admin) return const AdminScreen();
    return role == UserRole.buyer ? _buildBuyerShell() : _buildFarmerShell();
  }

  // ── Farmer shell ─────────────────────────────────────────────────────────────

  Widget _buildFarmerShell() {
    final pages = <Widget>[
      HomeScreen(onSearchTap: null),
      const DiseaseScreen(),
      const FarmAdvisoryHubScreen(showAppBar: false),
      const PredictionHubScreen(showAppBar: false),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _farmerIndex, children: pages),
      bottomNavigationBar: _NavBar(
        selectedIndex: _farmerIndex,
        onTap: (i) => setState(() => _farmerIndex = i),
        destinations: [
          _NavDest(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: context.t('app_navigation_home'),
          ),
          _NavDest(
            icon: Icons.camera_alt_outlined,
            selectedIcon: Icons.camera_alt_rounded,
            label: 'Diagnose',
          ),
          _NavDest(
            icon: Icons.eco_outlined,
            selectedIcon: Icons.eco_rounded,
            label: context.t('app_navigation_advisory'),
          ),
          _NavDest(
            icon: Icons.analytics_outlined,
            selectedIcon: Icons.analytics_rounded,
            label: context.t('app_navigation_predictions'),
          ),
          _NavDest(
            icon: Icons.person_outline,
            selectedIcon: Icons.person_rounded,
            label: context.t('app_navigation_profile'),
          ),
        ],
      ),
    );
  }

  // ── Buyer shell ──────────────────────────────────────────────────────────────

  Widget _buildBuyerShell() {
    final pages = <Widget>[
      HomeScreen(onSearchTap: () => setState(() => _buyerIndex = 1)),
      const SearchScreen(),
      const ProduceAvailabilityScreen(),
      const RegionalForecastScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _buyerIndex, children: pages),
      bottomNavigationBar: _NavBar(
        selectedIndex: _buyerIndex,
        onTap: (i) => setState(() => _buyerIndex = i),
        destinations: [
          _NavDest(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: context.t('app_navigation_home'),
          ),
          _NavDest(
            icon: Icons.search_outlined,
            selectedIcon: Icons.search_rounded,
            label: context.t('app_navigation_search'),
          ),
          _NavDest(
            icon: Icons.storefront_outlined,
            selectedIcon: Icons.storefront_rounded,
            label: 'Market',
          ),
          _NavDest(
            icon: Icons.map_outlined,
            selectedIcon: Icons.map_rounded,
            label: 'Forecast',
          ),
          _NavDest(
            icon: Icons.person_outline,
            selectedIcon: Icons.person_rounded,
            label: context.t('app_navigation_profile'),
          ),
        ],
      ),
    );
  }
}

// ── Shared nav bar ────────────────────────────────────────────────────────────

class _NavDest {
  const _NavDest({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.selectedIndex,
    required this.onTap,
    required this.destinations,
  });
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<_NavDest> destinations;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const navBg = AgriColors.forestGreen;
    const unselected = Colors.white70;
    const selected = Colors.white;
    const indicator = Color(0x33FFFFFF); // white 20%

    return Theme(
      data: Theme.of(context).copyWith(
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: navBg,
          indicatorColor: indicator,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return IconThemeData(color: isSelected ? selected : unselected);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return TextStyle(
              color: isSelected ? selected : unselected,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            );
          }),
        ),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onTap,
        backgroundColor: navBg,
        indicatorColor: indicator,
        destinations: destinations
            .map(
              (d) => NavigationDestination(
                icon: Icon(d.icon, color: unselected),
                selectedIcon: Icon(d.selectedIcon, color: selected),
                label: d.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
