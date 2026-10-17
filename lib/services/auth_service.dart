import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Email + password sign-in through Firebase.
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = db ?? FirebaseFirestore.instance;

  /// Emits the signed-in user, or null when signed out. Drive the
  /// "sign-in screen vs. app" switch from this.
  Stream<User?> get userChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signUp({required String name, required String email, required String password}) async {
    await _run(() async {
      final credential = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      final user = credential.user!;
      await user.updateDisplayName(name.trim());
      await _db.collection('users').doc(user.uid).set({
        'displayName': name.trim(),
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    await _run(() => _auth.signInWithEmailAndPassword(email: email.trim(), password: password));
  }

  Future<void> sendPasswordReset(String email) async {
    await _run(() => _auth.sendPasswordResetEmail(email: email.trim()));
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> updateDisplayName(String name) async {
    await _run(() async => _auth.currentUser?.updateDisplayName(name.trim()));
  }

  /// Firebase emails a link to the new address; the change happens once they tap it.
  Future<void> changeEmail(String newEmail) async {
    await _run(() async => _auth.currentUser?.verifyBeforeUpdateEmail(newEmail.trim()));
  }

  /// Checks the password again (Firebase requires a fresh sign-in for this),
  /// runs [deleteData] to remove their profile and shelf, then deletes the account.
  Future<void> deleteAccount({required String password, required Future<void> Function() deleteData}) async {
    await _run(() async {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return;
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: password));
      await deleteData();
      await user.delete();
    });
  }

  /// Turns Firebase error codes into messages a person can act on.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e.code));
    }
  }

  static String _message(String code) {
    switch (code) {
      case 'invalid-email':
        return 'That email address doesn\'t look right.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong email or password.';
      case 'email-already-in-use':
        return 'There\'s already an account with that email. Try signing in.';
      case 'weak-password':
        return 'Pick a password with at least 6 characters.';
      case 'too-many-requests':
        return 'Too many tries. Wait a minute and try again.';
      case 'requires-recent-login':
        return 'For safety, log out and back in, then try again.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Something went wrong ($code).';
    }
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
