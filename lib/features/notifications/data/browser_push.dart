import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/firebase_config.dart';

class BrowserPush {
  BrowserPush(this._database, this._auth);
  final FirebaseFirestore _database;
  final FirebaseAuth _auth;
  final _preferences = SharedPreferencesAsync();

  static const _vapid = String.fromEnvironment('FIREBASE_VAPID_KEY');

  bool get configured => kIsWeb && !FirebaseConfig.local && _vapid.isNotEmpty;

  String get _preferenceKey => 'shop_push_${_database.app.options.projectId}';

  DocumentReference<Map<String, dynamic>> _device(String id) =>
      _database.collection('push_devices').doc(id);

  Future<bool> supported() async =>
      configured && await FirebaseMessaging.instance.isSupported();

  Future<bool> enrolled() async {
    if (!await supported()) return false;
    final id = await _preferences.getString(_preferenceKey);
    if (id == null) return false;
    return (await _device(id).get()).exists;
  }

  Future<void> enable() async {
    if (!configured) {
      throw const PushFailure(
        'Web push is unavailable in this browser or build.',
      );
    }
    final owner = _auth.currentUser;
    if (owner == null) {
      throw const PushFailure('Sign in again before enabling web push.');
    }
    final messaging = FirebaseMessaging.instance;
    final permission = await messaging.requestPermission();
    if (permission.authorizationStatus != AuthorizationStatus.authorized) {
      throw const PushFailure(
        'Allow notifications for this site in your browser settings.',
      );
    }
    final token = await _registrationToken(messaging);
    if (token == null || token.isEmpty) {
      throw const PushFailure('The browser could not register for push.');
    }
    final saved = await _preferences.getString(_preferenceKey);
    final id = saved ?? _browserId();
    if (saved == null) await _preferences.setString(_preferenceKey, id);
    await _device(id).set({
      'uid': owner.uid,
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> disable() async {
    final id = await _preferences.getString(_preferenceKey);
    if (id != null) {
      await _device(id).delete();
      await _preferences.remove(_preferenceKey);
    }
    try {
      // The server stores FCM registration tokens for multicast delivery.
      // ignore: deprecated_member_use
      await FirebaseMessaging.instance.deleteToken();
    } on FirebaseException {
      // Removing the server registration stops sends even if the browser cannot delete its token.
    }
  }

  Future<void> refreshRegistered() async {
    final owner = _auth.currentUser;
    if (!configured || owner == null) return;
    final id = await _preferences.getString(_preferenceKey);
    if (id == null || !await supported()) return;
    final device = _device(id);
    final saved = await device.get();
    if (!saved.exists) return;
    final messaging = FirebaseMessaging.instance;
    final permission = await messaging.getNotificationSettings();
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      await device.delete();
      return;
    }
    if (permission.authorizationStatus != AuthorizationStatus.authorized) {
      return;
    }
    final token = await _registrationToken(messaging);
    if (token == null || token.isEmpty || token == saved.get('token')) return;
    await _database.runTransaction((transaction) async {
      final current = await transaction.get(device);
      if (current.exists && current.get('uid') == owner.uid) {
        transaction.update(device, {
          'token': token,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<String?> _registrationToken(FirebaseMessaging messaging) {
    // Keep token enrollment compatible with Admin SDK multicast delivery.
    // ignore: deprecated_member_use
    return messaging.getToken(vapidKey: _vapid);
  }

  String _browserId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

class PushFailure implements Exception {
  const PushFailure(this.message);
  final String message;
}
