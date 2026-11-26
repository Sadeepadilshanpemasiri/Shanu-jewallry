import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/owner.dart';
import '../../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, this._database);

  final FirebaseAuth _auth;
  final FirebaseFirestore _database;

  Future<bool> _isOwner(User user) async {
    try {
      final access = await _database.doc('access/owner').get();
      return access.data()?['uid'] == user.uid;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') return false;
      rethrow;
    }
  }

  @override
  Stream<Owner?> watchOwner() =>
      _auth.authStateChanges().asyncMap((user) async {
        if (user == null || !await _isOwner(user)) return null;
        return Owner(uid: user.uid, email: user.email ?? '');
      });

  @override
  Future<void> signIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (result.user == null || !await _isOwner(result.user!)) {
        await _auth.signOut();
        throw SignInFailure.restricted;
      }
    } on FirebaseAuthException catch (error) {
      throw switch (error.code) {
        'invalid-email' ||
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => SignInFailure.credentials,
        'network-request-failed' => SignInFailure.network,
        'too-many-requests' => SignInFailure.throttled,
        'user-disabled' => SignInFailure.restricted,
        _ => SignInFailure.unavailable,
      };
    } on FirebaseException catch (error) {
      await _auth.signOut();
      throw error.code == 'unavailable'
          ? SignInFailure.network
          : SignInFailure.unavailable;
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
