import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/firebase_auth_repository.dart';
import '../../domain/entities/owner.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_providers.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) =>
    FirebaseAuthRepository(FirebaseAuth.instance, FirebaseFirestore.instance);

@Riverpod(keepAlive: true)
Stream<Owner?> ownerSession(Ref ref) =>
    ref.watch(authRepositoryProvider).watchOwner();
