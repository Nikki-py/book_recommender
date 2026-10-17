import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'firebase_options.dart';
import 'models/user_profile.dart';
import 'screens/home_shell.dart';
import 'screens/personalise_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/auth_service.dart';
import 'services/book_api.dart';
import 'services/profile_service.dart';
import 'services/shelf_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TbrApp());
}

/// Picks what to show: the welcome screen when signed out, the personalise
/// slides for a new account, and the main app after that.
class TbrApp extends StatefulWidget {
  const TbrApp({super.key});

  @override
  State<TbrApp> createState() => _TbrAppState();
}

class _TbrAppState extends State<TbrApp> {
  final _auth = AuthService();
  final _api = BookApi();
  late final Stream<User?> _userStream = _auth.userChanges;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _userStream,
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return buildApp(home: const _Loading());
        }
        final user = authSnap.data;
        if (user == null) return buildApp(home: const WelcomeScreen());
        return _SignedIn(key: ValueKey(user.uid), uid: user.uid, auth: _auth, api: _api);
      },
    );
  }
}

MaterialApp buildApp({required Widget home, ThemeMode mode = ThemeMode.light}) => MaterialApp(
  title: 'TBR',
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),
  themeMode: mode,
  home: home,
);

class _SignedIn extends StatefulWidget {
  final String uid;
  final AuthService auth;
  final BookApi api;

  const _SignedIn({super.key, required this.uid, required this.auth, required this.api});

  @override
  State<_SignedIn> createState() => _SignedInState();
}

class _SignedInState extends State<_SignedIn> {
  late final _profiles = ProfileService(widget.uid);
  late final _shelf = ShelfService(widget.uid);
  late final Stream<UserProfile?> _profileStream = _profiles.watch();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _profileStream,
      builder: (context, snap) {
        final profile = snap.data;
        // Right after sign-up the profile document takes a moment to appear.
        if (profile == null) return buildApp(home: const _Loading());
        return AppScope(
          auth: widget.auth,
          api: widget.api,
          profiles: _profiles,
          shelf: _shelf,
          profile: profile,
          child: buildApp(mode: profile.themeMode, home: const _Home()),
        );
      },
    );
  }
}

/// Reads the profile itself so it switches over as soon as onboarding finishes.
class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) =>
      AppScope.of(context).profile.onboarded ? const HomeShell() : const PersonaliseScreen();
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
