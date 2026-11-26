import '../entities/owner.dart';

abstract interface class AuthRepository {
  Stream<Owner?> watchOwner();
  Future<void> signIn(String email, String password);
  Future<void> signOut();
}

enum SignInFailure implements Exception {
  credentials,
  restricted,
  network,
  throttled,
  unavailable,
}
