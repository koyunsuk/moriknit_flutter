import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

import '../domain/user_model.dart';

class AuthRepository {
  AuthRepository();

  static const String _googleServerClientId =
      '683285854424-obadmfjoc5p3no1fijq7t2n9phk1s53j.apps.googleusercontent.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized || kIsWeb) return;
    await _googleSignIn.initialize(serverClientId: _googleServerClientId);
    _googleInitialized = true;
  }

  Future<UserModel?> signInWithEmail({required String email, required String password}) async {
    try {
      final credential = await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 15));
      return await _getOrCreateUser(credential.user!);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } on TimeoutException {
      throw 'Login timed out. Please try again.';
    }
  }

  Future<UserModel?> signUpWithEmail({required String email, required String password, required String displayName}) async {
    try {
      final credential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 15));
      await credential.user!.updateDisplayName(displayName);
      return await _getOrCreateUser(credential.user!);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } on TimeoutException {
      throw 'Sign up timed out. Please try again.';
    }
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final credential = await _auth
            .signInWithPopup(GoogleAuthProvider())
            .timeout(const Duration(seconds: 20));
        final user = credential.user;
        if (user == null) throw Exception('Google account was not returned.');
        // 신규/기존 모두 await로 처리 — 문서 생성 실패 시 에러 감지
        return await _getOrCreateUser(user);
      }

      await _ensureGoogleInitialized();
      final account = await _googleSignIn.authenticate().timeout(const Duration(seconds: 20));
      final auth = account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google ID token was not returned.');
      }

      final credential = await _auth
          .signInWithCredential(GoogleAuthProvider.credential(idToken: idToken))
          .timeout(const Duration(seconds: 20));
      final user = credential.user;
      if (user == null) throw Exception('Firebase user was not returned after Google sign-in.');

      // 신규/기존 모두 await로 처리 — 문서 생성 실패 시 에러 감지
      return await _getOrCreateUser(user);
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    } on GoogleSignInException catch (e) {
      throw Exception('Google login failed: ${e.code.name}');
    } on TimeoutException {
      throw Exception('Google login timed out. Please try again.');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      try {
        await _ensureGoogleInitialized();
        await _googleSignIn.signOut();
      } catch (_) {}
    }
  }

  Future<UserModel?> signInWithKakao() async {
    try {
      if (await kakao.isKakaoTalkInstalled()) {
        await kakao.UserApi.instance.loginWithKakaoTalk();
      } else {
        await kakao.UserApi.instance.loginWithKakaoAccount();
      }
      throw UnimplementedError('Kakao login requires Firebase custom token integration.');
    } catch (e) {
      throw Exception('Kakao login failed: $e');
    }
  }

  Future<UserModel> _getOrCreateUser(User firebaseUser) async {
    final docRef = _db.collection('users').doc(firebaseUser.uid);
    final doc = await docRef.get().timeout(const Duration(seconds: 12));
    final profileUpdates = <String, dynamic>{
      'email': firebaseUser.email ?? '',
      'displayName': firebaseUser.displayName ?? '',
      'photoURL': firebaseUser.photoURL ?? '',
      'lastActiveAt': FieldValue.serverTimestamp(),
    };

    if (doc.exists) {
      await docRef.set(profileUpdates, SetOptions(merge: true)).timeout(const Duration(seconds: 12));
      final refreshed = await docRef.get().timeout(const Duration(seconds: 12));
      return UserModel.fromFirestore(refreshed);
    }

    final newUser = UserModel.initial(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName ?? '',
      photoURL: firebaseUser.photoURL ?? '',
    );
    await docRef.set({
      ...newUser.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
      'moriBalance': 10000,
      'subscription': {
        'planId': 'pro', // 베타 기간: 신규 회원 전원 Pro
        'status': 'active',
      },
      'usage': {
        'swatchCount': 0,
        'projectCount': 0,
        'counterCount': 0,
        'editorSaveCount': 0,
        'postsThisMonth': 0,
      },
    }).timeout(const Duration(seconds: 12));
    final created = await docRef.get().timeout(const Duration(seconds: 12));
    return UserModel.fromFirestore(created);
  }

  Stream<UserModel?> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  Future<String> uploadProfilePhoto(String uid, File file) async {
    final ref = FirebaseStorage.instance.ref('users/$uid/profile.jpg');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();
    await _db.collection('users').doc(uid).update({'photoURL': url});
    await _auth.currentUser?.updatePhotoURL(url);
    return url;
  }

  Future<String> uploadProfilePhotoBytes(String uid, List<int> bytes) async {
    final ref = FirebaseStorage.instance.ref('users/$uid/profile.jpg');
    await ref.putData(Uint8List.fromList(bytes), SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    await _db.collection('users').doc(uid).update({'photoURL': url});
    await _auth.currentUser?.updatePhotoURL(url);
    return url;
  }

  Future<void> updateDisplayName(String uid, String displayName) async {
    await _db.collection('users').doc(uid).update({'displayName': displayName});
    await _auth.currentUser?.updateDisplayName(displayName);
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'The password is incorrect.';
      case 'email-already-in-use':
        return 'That email is already in use.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'account-exists-with-different-credential':
        return 'This email is already connected to another sign-in method.';
      case 'network-request-failed':
        return 'Network connection failed. Please try again.';
      default:
        return 'Login failed. Please try again.';
    }
  }
}
