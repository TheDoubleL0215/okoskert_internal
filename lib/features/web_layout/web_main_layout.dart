import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:okoskert_internal/features/dashboard/dashboard_screen.dart';

class WebMainLayout extends StatefulWidget {
  const WebMainLayout({super.key});

  @override
  State<WebMainLayout> createState() => _WebMainLayoutState();
}

class _WebMainLayoutState extends State<WebMainLayout> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar
          Container(
            width: 250,
            color: const Color(0xFF1E1E2C), // Dark theme
            child: Column(
              children: [
                // Company Logo Area
                Container(
                  padding: const EdgeInsets.all(24.0),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.business, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Onix',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Navigation Items
                _buildNavItem(0, Icons.dashboard, 'Vezérlőpult'),
                _buildNavItem(1, Icons.people, 'Ügyfelek & Projektek'),
                _buildNavItem(2, Icons.attach_money, 'Pénzügy / Számlázás'),
                _buildNavItem(3, Icons.chat, 'Kommunikáció'),
                _buildNavItem(4, Icons.group, 'Csapat'),

                const Spacer(),

                // User Avatar & Logout
                const Divider(color: Colors.white24, height: 1),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: const Text(
                    'Felhasználó',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white54),
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Header
                Container(
                  height: 64,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      // Global Search Input
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Keresés...',
                            prefixIcon: const Icon(Icons.search, color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Notification Bell
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined, color: Colors.grey),
                            onPressed: () {},
                          ),
                          Positioned(
                            right: 12,
                            top: 12,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Content Area
                Expanded(
                  child: Container(
                    color: Colors.grey[100],
                    child: _buildMainContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.auto_awesome),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return const DashboardScreen();
      default:
        return const Center(
          child: Text(
            'Hamarosan érkezik',
            style: TextStyle(fontSize: 24, color: Colors.black54),
          ),
        );
    }
  }

  Widget _buildNavItem(int index, IconData icon, String title) {
    final isActive = _selectedIndex == index;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? Colors.white : Colors.white54,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white54,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        tileColor: isActive ? Colors.white.withValues(alpha: 0.1) : null,
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
