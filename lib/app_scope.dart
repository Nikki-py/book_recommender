import 'package:flutter/widgets.dart';

import 'models/user_profile.dart';
import 'services/auth_service.dart';
import 'services/book_api.dart';
import 'services/profile_service.dart';
import 'services/shelf_service.dart';

/// Hands the signed-in user's services and profile to every screen below it.
class AppScope extends InheritedWidget {
  final AuthService auth;
  final BookApi api;
  final ProfileService profiles;
  final ShelfService shelf;
  final UserProfile profile;

  const AppScope({
    super.key,
    required this.auth,
    required this.api,
    required this.profiles,
    required this.shelf,
    required this.profile,
    required super.child,
  });

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope.of() called outside the signed-in app');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => profile != oldWidget.profile || shelf.uid != oldWidget.shelf.uid;
}
