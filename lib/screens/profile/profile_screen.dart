import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state_provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/main_bottom_navigation.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await context.read<AuthService>().signOut();
    } on AuthServiceException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to logout. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature will be available soon.')));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppStateProvider>().user;

    final name = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'MachAlert User';

    final email = user?.email.trim().isNotEmpty == true
        ? user!.email.trim()
        : 'No email available';

    final role = user?.role.trim().isNotEmpty == true
        ? _capitalize(user!.role)
        : 'User';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      bottomNavigationBar: const MainBottomNavigation(currentIndex: 4),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFFE7F7F0),
                  child: Text(
                    _initials(name),
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: AppTheme.navy,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        email,
                        style: const TextStyle(
                          color: Color(0xFF718292),
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        role,
                        style: const TextStyle(
                          color: AppTheme.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            _ProfileActionTile(
              icon: Icons.person_outline,
              title: 'Edit Profile',
              onTap: () => _comingSoon('Edit profile'),
            ),

            _ProfileActionTile(
              icon: Icons.lock_outline,
              title: 'Change Password',
              onTap: () => _comingSoon('Change password'),
            ),

            _ProfileActionTile(
              icon: Icons.notifications_none,
              title: 'Notifications',
              onTap: () => _comingSoon('Notifications'),
            ),

            _ProfileActionTile(
              icon: Icons.info_outline,
              title: 'About MachAlert',
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'MachAlert',
                applicationVersion: '1.0.0',
                applicationLegalese: 'Machine monitoring and maintenance.',
              ),
            ),

            const SizedBox(height: 14),

            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(Icons.logout, color: AppTheme.danger),
              title: Text(
                _isLoggingOut ? 'Logging out...' : 'Logout',
                style: const TextStyle(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: _isLoggingOut ? null : _logout,
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return value;
    }

    return '${trimmed[0].toUpperCase()}${trimmed.substring(1).toLowerCase()}';
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'M';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Icon(icon, color: AppTheme.navy),
          title: Text(
            title,
            style: const TextStyle(
              color: AppTheme.navy,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: onTap,
        ),
        const Divider(height: 1),
      ],
    );
  }
}
