import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// The user's profile document at users/{uid}: name, what they picked on the
/// personalise slides, and their settings.
class UserProfile {
  final String displayName;
  final String email;
  final DateTime? createdAt;

  /// False until they finish (or skip) the personalise slides.
  final bool onboarded;
  final List<String> genres;
  final List<String> vibes;
  final List<String> kinds;

  /// Books picked on "Pick books you've loved"; recommendations start from these.
  final List<String> lovedBookIds;

  /// Books to read this year, or null when no goal is set.
  final int? yearlyGoal;
  final ThemeMode themeMode;
  final bool twinkle;

  const UserProfile({
    this.displayName = '',
    this.email = '',
    this.createdAt,
    this.onboarded = false,
    this.genres = const [],
    this.vibes = const [],
    this.kinds = const [],
    this.lovedBookIds = const [],
    this.yearlyGoal,
    this.themeMode = ThemeMode.light,
    this.twinkle = true,
  });

  factory UserProfile.fromFirestore(Map<String, dynamic> data) {
    List<String> strings(String key) => List<String>.from(data[key] as List? ?? const []);
    return UserProfile(
      displayName: data['displayName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      onboarded: data['onboarded'] as bool? ?? false,
      genres: strings('genres'),
      vibes: strings('vibes'),
      kinds: strings('kinds'),
      lovedBookIds: strings('lovedBookIds'),
      yearlyGoal: (data['yearlyGoal'] as num?)?.toInt(),
      themeMode: ThemeMode.values.firstWhere((m) => m.name == data['themeMode'], orElse: () => ThemeMode.light),
      twinkle: data['twinkle'] as bool? ?? true,
    );
  }
}
