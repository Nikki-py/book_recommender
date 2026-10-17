import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/fairy_lights.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'shelves_screen.dart';

/// The signed-in app: four pages and the menu bar at the bottom.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  static const _tabs = [
    (icon: Icons.home_outlined, active: Icons.home_rounded, label: 'Home'),
    (icon: Icons.explore_outlined, active: Icons.explore, label: 'Explore'),
    (icon: Icons.auto_stories_outlined, active: Icons.auto_stories, label: 'Shelves'),
    (icon: Icons.person_outline_rounded, active: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final onShelves = _tab == 2;
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(onExplore: () => setState(() => _tab = 1)),
          const ExploreScreen(),
          const ShelvesScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _MenuBar(dark: onShelves, current: _tab, onTap: (i) => setState(() => _tab = i)),
    );
  }
}

class _MenuBar extends StatelessWidget {
  final bool dark;
  final int current;
  final ValueChanged<int> onTap;
  const _MenuBar({required this.dark, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = dark || scheme.brightness == Brightness.dark ? const Color(0xFF9BC7A4) : AppColors.green;
    final row = SizedBox(
      height: 64,
      child: Row(
        children: [
          for (var i = 0; i < _HomeShellState._tabs.length; i++)
            Expanded(
              child: Tooltip(
                message: _HomeShellState._tabs[i].label,
                child: InkResponse(
                  onTap: () => onTap(i),
                  radius: 28,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        i == current ? _HomeShellState._tabs[i].active : _HomeShellState._tabs[i].icon,
                        size: 26,
                        color: i == current
                            ? active
                            : (dark
                                  ? AppColors.cream.withValues(alpha: 0.75)
                                  : scheme.onSurface.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 5),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: i == current ? 1 : 0,
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(color: active, shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: dark
            ? Glass(radius: 24, child: row)
            : Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4))],
                ),
                child: row,
              ),
      ),
    );
  }
}
