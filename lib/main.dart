import 'package:flutter/material.dart';

import 'database/database_helper.dart';
import 'models/baby_profile.dart';
import 'screens/development_screen.dart';
import 'screens/home_screen.dart';
import 'screens/monthly_photos_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/stats_screen.dart';
import 'theme/app_theme.dart';

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

  Future<void> _handleProfileChanged() async {
    await _loadProfile();
    if (!mounted) {
      return;
    }
    setState(() {
      _refreshTick++;
    });
  }

  void _handleProfilePreview(BabyProfile profile) {
    setState(() {
      _profile = profile;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile ?? BabyProfile.empty();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Baby First Year',
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
                  bottom: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: [
                          ProfileScreen(
                            refreshTick: _refreshTick,
                            profile: profile,
                            onPreviewChanged: _handleProfilePreview,
                            onChanged: _handleProfileChanged,
                          ),
                          StatsScreen(
                            refreshTick: _refreshTick,
                            profile: profile,
                          ),
                          DevelopmentScreen(
                            refreshTick: _refreshTick,
                            profile: profile,
                          ),
                          MonthlyPhotosScreen(profile: profile),
                          HomeScreen(profile: profile),
                        ],
                      ),
                    ),
                  ),
                ),
                bottomNavigationBar: _PillNavigationBar(
                  selectedIndex: _selectedIndex,
                  onSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                ),
              ),
    );
  }
}

class _PillNavigationBar extends StatelessWidget {
  const _PillNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    _NavItem(icon: Icons.child_care_rounded, label: 'Baby'),
    _NavItem(icon: Icons.show_chart_rounded, label: 'Growth'),
    _NavItem(icon: Icons.checklist_rounded, label: 'Milestones'),
    _NavItem(icon: Icons.photo_library_rounded, label: 'Photos'),
    _NavItem(icon: Icons.menu_book_rounded, label: 'Guide'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: Container(
          width: 430,
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width - 32,
          ),
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1D2226),
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var index = 0; index < _items.length; index++)
                _PillNavButton(
                  item: _items[index],
                  selected: selectedIndex == index,
                  onTap: () => onSelected(index),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillNavButton extends StatelessWidget {
  const _PillNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.label,
      child: Semantics(
        label: item.label,
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              color: selected ? const Color(0xFF1D2226) : Colors.white,
              size: 25,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
