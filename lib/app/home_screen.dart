import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:okoskert_internal/app/session_provider.dart';
import 'package:okoskert_internal/features/admin/admin_screen.dart';
import 'package:okoskert_internal/features/projects/projects_collector_screen.dart';
import 'package:okoskert_internal/features/calendar/calendar_screen.dart';
import 'package:okoskert_internal/app/profile_screen.dart';
import 'package:okoskert_internal/features/worklog/view/worklog_screen.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final isAdmin = session.role == 1;

    final pages = <Widget>[
      const Projectscollectorscreen(),
      const WorklogScreen(),
      const CalendarScreen(),
      isAdmin ? const AdminPage() : const ProfilePage(),
    ];

    return Scaffold(
      body: pages[currentPageIndex],
      bottomNavigationBar: _HomeBottomNavBar(
        currentIndex: currentPageIndex,
        isAdmin: isAdmin,
        onIndexSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
      ),
    );
  }
}

class _HomeBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final bool isAdmin;
  final ValueChanged<int> onIndexSelected;

  const _HomeBottomNavBar({
    required this.currentIndex,
    required this.isAdmin,
    required this.onIndexSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedColor = cs.primary;
    final unselectedColor = cs.onSurfaceVariant;

    final destinations = <({IconData icon, String label})>[
      (icon: LucideIcons.clipboardList, label: 'Projektek'),
      (icon: LucideIcons.clipboardClock, label: 'Munkanapló'),
      (icon: LucideIcons.calendarDays, label: 'Naptár'),
      (
        icon: isAdmin ? LucideIcons.cog : LucideIcons.user,
        label: isAdmin ? 'Admin' : 'Profil',
      ),
    ];

    return SafeArea(
      bottom: false,
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(26),
          ),
          child: SizedBox(
            height: 78,
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: _HomeBottomNavItem(
                      icon: destinations[i].icon,
                      label: destinations[i].label,
                      isSelected: i == currentIndex,
                      selectedColor: selectedColor,
                      unselectedColor: unselectedColor,
                      onTap: () => onIndexSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeBottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  const _HomeBottomNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? selectedColor : unselectedColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: SizedBox(
        height: 78,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              // A Stack közepéhez képest a marker az ikon (nem a felirat) szintjére kerüljön.
              alignment: const Alignment(0, -1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 56,
                height: 5,
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
