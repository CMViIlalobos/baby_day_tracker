import 'package:flutter/material.dart';

import 'database/database_helper.dart';
import 'models/baby_profile.dart';
import 'screens/development_screen.dart';
import 'screens/home_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/stats_screen.dart';
import 'theme/app_theme.dart';
import 'utils/notification_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BabyDayTrackerApp());
}

class BabyDayTrackerApp extends StatefulWidget {
  const BabyDayTrackerApp({super.key});

  @override
  State<BabyDayTrackerApp> createState() => _BabyDayTrackerAppState();
}

class _BabyDayTrackerAppState extends State<BabyDayTrackerApp> {
  BabyProfile? _profile;
  bool _isLoading = true;
  int _selectedIndex = 0;
  int _refreshTick = 0;
  String? _startupError;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _isLoading = true;
      _startupError = null;
    });

    try {
      await DatabaseHelper.instance.initialize();
      await _loadProfile();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _startupError = 'Failed to start the app: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });
    final profile = await DatabaseHelper.instance.getBabyProfile();
    if (!mounted) {
      return;
    }
    setState(() {
      _profile = profile;
      _isLoading = false;
    });
  }

  Future<void> _handleDataChanged() async {
    await _loadProfile();
    await NotificationHelper.instance.syncProfileReminders(_profile);
    if (!mounted) {
      return;
    }
    setState(() {
      _refreshTick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile ?? BabyProfile.empty();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Baby Day Tracker',
      theme: AppTheme.light(profile.themeColorValue),
      darkTheme: AppTheme.dark(profile.themeColorValue),
      themeMode: ThemeMode.system,
      home:
          _startupError != null
              ? Scaffold(
                body: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            _startupError!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _initializeApp,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              : _isLoading
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : Scaffold(
                body: SafeArea(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      HomeScreen(
                        refreshTick: _refreshTick,
                        babyName: profile.name,
                        profile: profile,
                        onChanged: _handleDataChanged,
                      ),
                      StatsScreen(refreshTick: _refreshTick, profile: profile),
                      DevelopmentScreen(
                        refreshTick: _refreshTick,
                        profile: profile,
                        onChanged: _handleDataChanged,
                      ),
                      InventoryScreen(
                        refreshTick: _refreshTick,
                        onChanged: _handleDataChanged,
                      ),
                      ProfileScreen(
                        refreshTick: _refreshTick,
                        profile: profile,
                        onChanged: _handleDataChanged,
                      ),
                    ],
                  ),
                ),
                bottomNavigationBar: NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.bar_chart_rounded),
                      label: 'Stats',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.insights_rounded),
                      label: 'Growth',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_rounded),
                      label: 'Inventory',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.child_care_rounded),
                      label: 'Baby',
                    ),
                  ],
                ),
              ),
    );
  }

}
