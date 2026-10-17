import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/user_profile.dart';

/// Reads and saves the signed-in user's profile document at users/{uid}.
class ProfileService {
  final String uid;
  final FirebaseFirestore _db;

  ProfileService(this.uid, {FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc => _db.collection('users').doc(uid);

  /// Emits null while the document is still being created right after sign-up.
  Stream<UserProfile?> watch() =>
      _doc.snapshots().map((snap) => snap.exists ? UserProfile.fromFirestore(snap.data()!) : null);

  Future<void> _set(Map<String, dynamic> fields) => _doc.set(fields, SetOptions(merge: true));

  Future<void> saveTaste({required List<String> genres, required List<String> vibes, required List<String> kinds}) =>
      _set({'genres': genres, 'vibes': vibes, 'kinds': kinds});

  Future<void> finishOnboarding({List<String>? lovedBookIds}) =>
      _set({'onboarded': true, if (lovedBookIds != null) 'lovedBookIds': FieldValue.arrayUnion(lovedBookIds)});

  Future<void> setYearlyGoal(int? goal) => _set({'yearlyGoal': goal});

  Future<void> setThemeMode(ThemeMode mode) => _set({'themeMode': mode.name});

  Future<void> setTwinkle(bool on) => _set({'twinkle': on});

  Future<void> setDisplayName(String name) => _set({'displayName': name.trim()});

  Future<void> delete() => _doc.delete();
}
