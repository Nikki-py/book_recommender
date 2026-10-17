import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/shelf_book.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart' show askYearlyGoal;
import 'personalise_screen.dart';

/// Profile and settings.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final profile = scope.profile;
    final scheme = Theme.of(context).colorScheme;
    final name = profile.displayName.isEmpty ? 'Reader' : profile.displayName;

    return StreamBuilder<List<ShelfBook>>(
      stream: scope.shelf.watchShelf(),
      builder: (context, snap) {
        final shelf = snap.data ?? const <ShelfBook>[];
        final read = shelf.where((b) => b.shelf == Shelf.read).length;
        final tbr = shelf.where((b) => b.shelf == Shelf.tbr).length;
        final thisYear = shelf.where((b) => b.readAt?.year == DateTime.now().year).length;
        return ListView(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 28, 20, 120),
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.green,
                child: Text(name[0].toUpperCase(), style: AppText.serif(size: 36, color: AppColors.cream)),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(name, style: AppText.serif(size: 28, color: scheme.onSurface)),
            ),
            if (profile.createdAt != null)
              Center(
                child: Text(
                  'Reading since ${_monthYear(profile.createdAt!)}',
                  style: AppText.sans(size: 13, color: scheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 18),
            Row(
              children: [
                _Count(label: 'Read', value: read),
                _Count(label: 'TBR', value: tbr),
                _Count(label: 'This year', value: thisYear),
              ],
            ),
            const _Header('Reading'),
            _Group(
              children: [
                _Item(
                  icon: Icons.flag_outlined,
                  title: 'Yearly reading goal',
                  trailing: profile.yearlyGoal == null ? 'Not set' : '${profile.yearlyGoal} books',
                  onTap: () => askYearlyGoal(context),
                ),
                _Item(
                  icon: Icons.tune,
                  title: 'Edit my genres & vibes',
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const PersonaliseScreen(editing: true))),
                ),
                _Item(
                  icon: Icons.group_outlined,
                  title: 'Friends',
                  trailing: 'Soon',
                  onTap: () => _soon(context, 'Friends are coming in a later phase.'),
                ),
              ],
            ),
            const _Header('App'),
            _Group(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.palette_outlined, color: scheme.onSurface),
                          const SizedBox(width: 16),
                          Text('Appearance', style: AppText.sans(size: 15)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: AppColors.green,
                          selectedForegroundColor: AppColors.cream,
                        ),
                        segments: const [
                          ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                          ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                          ButtonSegment(value: ThemeMode.system, label: Text('Match phone')),
                        ],
                        selected: {profile.themeMode},
                        onSelectionChanged: (s) => scope.profiles.setThemeMode(s.first),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.auto_awesome_outlined),
                  title: Text('Twinkling fairy lights', style: AppText.sans(size: 15)),
                  value: profile.twinkle,
                  activeTrackColor: AppColors.green,
                  onChanged: scope.profiles.setTwinkle,
                ),
              ],
            ),
            const _Header('Account'),
            _Group(
              children: [
                _Item(icon: Icons.badge_outlined, title: 'Change username', onTap: () => _changeUsername(context)),
                _Item(icon: Icons.alternate_email, title: 'Change email', onTap: () => _changeEmail(context)),
                _Item(
                  icon: Icons.lock_outline,
                  title: 'Change password',
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await scope.auth.sendPasswordReset(profile.email);
                    messenger.showSnackBar(SnackBar(content: Text('We sent a reset link to ${profile.email}.')));
                  },
                ),
                _Item(icon: Icons.logout, title: 'Log out', onTap: scope.auth.signOut),
                _Item(
                  icon: Icons.delete_outline,
                  title: 'Delete account',
                  danger: true,
                  onTap: () => _deleteAccount(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Text('TBR · version 0.1.0', style: AppText.sans(size: 12, color: scheme.onSurfaceVariant)),
            ),
          ],
        );
      },
    );
  }

  static String _monthYear(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.year}';
  }

  void _soon(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<String?> _ask(BuildContext context, String title, {String initial = '', bool password = false, String? hint}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: password,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _changeUsername(BuildContext context) async {
    final scope = AppScope.of(context);
    final name = await _ask(context, 'Username', initial: scope.profile.displayName);
    if (name == null || name.trim().isEmpty) return;
    await scope.profiles.setDisplayName(name);
    await scope.auth.updateDisplayName(name);
  }

  Future<void> _changeEmail(BuildContext context) async {
    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final email = await _ask(context, 'New email', hint: 'you@example.com');
    if (email == null || email.trim().isEmpty) return;
    try {
      await scope.auth.changeEmail(email);
      messenger.showSnackBar(
        SnackBar(content: Text('Check ${email.trim()} and tap the link to finish changing your email.')),
      );
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final password = await _ask(context, 'Delete your account?', password: true, hint: 'Type your password to confirm');
    if (password == null || password.isEmpty) return;
    try {
      await scope.auth.deleteAccount(
        password: password,
        deleteData: () async {
          await scope.shelf.clear();
          await scope.profiles.delete();
        },
      );
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _Count extends StatelessWidget {
  final String label;
  final int value;
  const _Count({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: AppText.serif(size: 26, color: scheme.onSurface)),
          Text(label, style: AppText.sans(size: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 26, 8, 8),
    child: Text(
      text.toUpperCase(),
      style: AppText.sans(size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant).copyWith(letterSpacing: 2),
    ),
  );
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
      ),
      child: Column(children: children),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final bool danger;
  final VoidCallback onTap;

  const _Item({required this.icon, required this.title, required this.onTap, this.trailing, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? scheme.error : scheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: AppText.sans(size: 15, color: color)),
      trailing: trailing == null
          ? Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)
          : Text(trailing!, style: AppText.sans(size: 13, color: scheme.onSurfaceVariant)),
      onTap: onTap,
    );
  }
}
