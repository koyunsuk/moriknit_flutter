import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

import '../domain/user_model.dart';

class LoginException implements Exception {
  final String message;
  final String? code;
  const LoginException(this.message, {this.code});
  @override
  String toString() => message;
}

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

  /// 익명 여부 확인 — 게스트 모드(Pro 차단, 가입 권유 대상)
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  /// 익명 자동 로그인 — Splash에서 미로그인 시 호출.
  /// Firebase Console → Authentication → Sign-in method → Anonymous 활성화 필요.
  Future<User?> signInAnonymously() async {
    try {
      final credential = await _auth
          .signInAnonymously()
          .timeout(const Duration(seconds: 15));
      final user = credential.user;
      if (user != null) {
        // 익명 사용자도 users/{uid} 문서를 만들어 둠 (Free 플랜으로 시작)
        try {
          await _ensureAnonymousUserDoc(user);
        } catch (_) {}
      }
      return user;
    } on FirebaseAuthException {
      // 콘솔에서 익명 로그인이 비활성화되어 있거나 네트워크 실패 — 호출자가 처리
      rethrow;
    } on TimeoutException {
      rethrow;
    }
  }

  /// 익명 → 진짜 계정 업그레이드 (uid 보존, 모든 데이터 그대로 유지).
  /// 이메일/Google/Kakao 자격 증명을 전달받아 현재 익명 사용자에 연결한다.
  Future<UserModel?> linkWithCredential(AuthCredential credential) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('로그인 상태가 아닙니다.');
    try {
      final result = await user
          .linkWithCredential(credential)
          .timeout(const Duration(seconds: 20));
      final linkedUser = result.user;
      if (linkedUser == null) {
        throw Exception('Failed to link credential.');
      }
      return await _getOrCreateUser(linkedUser);
    } on FirebaseAuthException catch (e) {
      throw LoginException(_handleAuthException(e), code: e.code);
    }
  }

  /// 익명 사용자용 users/{uid} 최소 문서 생성 — Free 플랜으로 시작.
  Future<void> _ensureAnonymousUserDoc(User firebaseUser) async {
    final docRef = _db.collection('users').doc(firebaseUser.uid);
    final doc = await docRef.get().timeout(const Duration(seconds: 12));
    if (doc.exists) {
      // 마지막 활동 시간만 갱신
      await docRef.set({
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 12));
      return;
    }
    final newUser = UserModel.initial(
      uid: firebaseUser.uid,
      email: '',
      displayName: '게스트',
      photoURL: '',
    );
    await docRef.set({
      ...newUser.toJson(),
      'isAnonymous': true,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
      'moriBalance': 0,
      // 익명 사용자는 무조건 Free 플랜
      'subscription': {
        'planId': 'free',
        'status': 'active',
        'cancelAtPeriodEnd': false,
      },
      'usage': {
        'swatchCount': 0,
        'projectCount': 0,
        'counterCount': 0,
        'editorSaveCount': 0,
        'postsThisMonth': 0,
      },
    }).timeout(const Duration(seconds: 12));
  }

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
      throw LoginException(_handleAuthException(e), code: e.code);
    } on TimeoutException {
      throw 'Login timed out. Please try again.';
    }
  }

  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    String? signupSource,
  }) async {
    try {
      final credential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 15));
      await credential.user!.updateDisplayName(displayName);
      return await _getOrCreateUser(credential.user!, signupSource: signupSource);
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

  static const _kakaoFunctionUrl =
      'https://us-central1-moriknit-ceea9.cloudfunctions.net/kakaoCustomToken';

  /// #728 — 카카오 회원가입 (signInWithKakao 호출 후 referrer/provider 등 가입 메타데이터를 users 문서에 머지).
  /// 기존 사용자도 호출 가능 — referrerInput/referrerId 가 비어 있는 경우에만 새로 기록한다.
  Future<UserModel?> signUpWithKakao({
    String? referrerInput,
    String? referrerId,
  }) async {
    final model = await signInWithKakao();
    final user = _auth.currentUser;
    if (user == null || model == null) return model;
    try {
      final docRef = _db.collection('users').doc(user.uid);
      final updates = <String, dynamic>{
        'provider': 'kakao',
        if (user.email != null && user.email!.isNotEmpty) 'kakaoEmail': user.email,
      };
      if (referrerInput != null && referrerInput.isNotEmpty) {
        updates['referrerInput'] = referrerInput;
      }
      if (referrerId != null && referrerId.isNotEmpty) {
        updates['referrerId'] = referrerId;
      }
      await docRef.set(updates, SetOptions(merge: true))
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      // 메타데이터 머지 실패는 가입 자체를 막지 않음
    }
    return model;
  }

  /// #753 — 구글 회원가입 (signInWithGoogle 후 referrer/provider 메타데이터 머지).
  Future<UserModel?> signUpWithGoogle({
    String? referrerInput,
    String? referrerId,
  }) async {
    final model = await signInWithGoogle();
    final user = _auth.currentUser;
    if (user == null || model == null) return model;
    try {
      final docRef = _db.collection('users').doc(user.uid);
      final updates = <String, dynamic>{
        'provider': 'google',
        if (user.email != null && user.email!.isNotEmpty) 'googleEmail': user.email,
      };
      if (referrerInput != null && referrerInput.isNotEmpty) {
        updates['referrerInput'] = referrerInput;
      }
      if (referrerId != null && referrerId.isNotEmpty) {
        updates['referrerId'] = referrerId;
      }
      await docRef.set(updates, SetOptions(merge: true))
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      // 메타데이터 머지 실패는 가입 자체를 막지 않음
    }
    return model;
  }

  Future<UserModel?> signInWithKakao() async {
    try {
      // #733 — 이전 카카오 세션을 완전 초기화하여 동의 화면을 항상 표시.
      // logout()만으로는 디바이스에 캐시된 토큰이 남아 동의 화면이 스킵되는 사례가 있어 unlink()까지 호출.
      // logout: 로컬 세션 토큰 삭제
      // unlink: 앱-사용자 연결 해제 → 다음 로그인 시 카카오가 동의 화면을 무조건 표시
      try {
        await kakao.UserApi.instance.logout();
      } catch (_) {
        // 이미 로그아웃 상태인 경우 무시
      }
      try {
        await kakao.UserApi.instance.unlink();
      } catch (_) {
        // unlink 실패(미로그인 등)는 무시 — 다음 단계에서 새로 로그인
      }

      // prompts: [Prompt.login] → 카카오 계정 재로그인 강제 (자동로그인 무시).
      // 위 unlink() 로 앱-사용자 연결이 해제됐기 때문에 카카오 서버에서 동의 화면을 자동으로 다시 표시.
      // 동의 항목(닉네임/프로필/이메일) 자체는 Kakao Developers 콘솔에서 활성화 필요.
      // SDK는 -402 에러 발생 시 누락된 동의 항목을 자동으로 추가 요청한다.
      kakao.OAuthToken token;
      if (await kakao.isKakaoTalkInstalled()) {
        try {
          token = await kakao.UserApi.instance.loginWithKakaoTalk();
        } catch (_) {
          // 카카오톡 설치돼 있어도 사용자가 카카오톡 로그인을 취소하면 계정 로그인 폴백
          token = await kakao.UserApi.instance.loginWithKakaoAccount(
            prompts: [kakao.Prompt.login],
          );
        }
      } else {
        token = await kakao.UserApi.instance.loginWithKakaoAccount(
          prompts: [kakao.Prompt.login],
        );
      }

      // 2. 현재 익명 사용자이면 ID 토큰을 함께 전달해 uid를 유지한 채 업그레이드
      String? anonymousIdToken;
      final current = _auth.currentUser;
      if (current != null && current.isAnonymous) {
        try {
          anonymousIdToken = await current.getIdToken();
        } catch (_) {
          anonymousIdToken = null;
        }
      }

      // 3. Firebase Function으로 커스텀 토큰 발급
      final response = await http.post(
        Uri.parse(_kakaoFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accessToken': token.accessToken,
          'anonymousIdToken': ?anonymousIdToken,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('Custom token request failed: ${response.body}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final customToken = data['customToken'] as String?;
      if (customToken == null || customToken.isEmpty) {
        throw Exception('No custom token returned');
      }

      // 4. 익명 → 카카오 업그레이드일 경우 signOut 없이 그대로 signInWithCustomToken 호출.
      //    같은 uid로 발급된 토큰이라 데이터는 그대로 유지됨.
      final credential = await _auth
          .signInWithCustomToken(customToken)
          .timeout(const Duration(seconds: 20));
      if (credential.user == null) throw Exception('Firebase user was not returned.');

      return await _getOrCreateUser(credential.user!);
    } on kakao.KakaoAuthException catch (e) {
      throw Exception('카카오 인증 실패: ${e.error.name}');
    } on TimeoutException {
      throw Exception('카카오 로그인 시간이 초과됐습니다. 다시 시도해 주세요.');
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel> _getOrCreateUser(User firebaseUser, {String? signupSource}) async {
    final docRef = _db.collection('users').doc(firebaseUser.uid);
    final doc = await docRef.get().timeout(const Duration(seconds: 12));
    final profileUpdates = <String, dynamic>{
      'lastActiveAt': FieldValue.serverTimestamp(),
      // 빈 값으로 기존 데이터 덮어쓰지 않음 (카카오 등 커스텀 토큰 로그인 보호)
      if ((firebaseUser.email ?? '').isNotEmpty) 'email': firebaseUser.email,
      if ((firebaseUser.displayName ?? '').isNotEmpty) 'displayName': firebaseUser.displayName,
      if ((firebaseUser.photoURL ?? '').isNotEmpty) 'photoURL': firebaseUser.photoURL,
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
      'signupSource': ?signupSource,
      'subscription': {
        'planId': 'pro', // 베타 기간: 신규 회원 전원 Pro
        'status': 'trial',
        'trialEndAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 90))),
        'currentPeriodEnd': Timestamp.fromDate(DateTime.now().add(const Duration(days: 90))),
        'currentPeriodStart': FieldValue.serverTimestamp(),
        'cancelAtPeriodEnd': false,
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

  /// 이슈 #750 — 마이페이지 프로필 추가정보 저장 (자기소개 + SNS 링크).
  /// users/{uid} 문서에 merge 방식으로 저장. 한쪽만 업데이트도 허용.
  Future<void> updateProfileExtras({
    required String uid,
    String? bio,
    Map<String, String>? socialLinks,
  }) async {
    final updates = <String, dynamic>{};
    if (bio != null) updates['bio'] = bio;
    if (socialLinks != null) {
      // 빈 값(공백) 제거 후 저장.
      final cleaned = <String, String>{};
      socialLinks.forEach((key, value) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) cleaned[key] = trimmed;
      });
      updates['socialLinks'] = cleaned;
    }
    if (updates.isEmpty) return;
    await _db
        .collection('users')
        .doc(uid)
        .set(updates, SetOptions(merge: true))
        .timeout(const Duration(seconds: 12));
  }

  /// 이슈 #750 — 휴대폰 인증 코드 전송 (Firebase Phone Auth).
  ///
  /// [phoneNumber]: E.164 형식 (예: '+821012345678').
  /// [codeSent]: SMS 코드 전송 완료 시 호출. (verificationId, resendToken) 전달.
  /// [verificationCompleted]: Android 자동 인증 감지 시 즉시 완료 콜백.
  /// [verificationFailed]: 검증 요청 실패 시 호출.
  /// [codeAutoRetrievalTimeout]: 자동 검색 타임아웃 시 호출.
  ///
  /// Firebase Console → Authentication → Phone provider 활성화 필요.
  Future<void> sendPhoneVerificationCode({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(PhoneAuthCredential credential) verificationCompleted,
    required void Function(FirebaseAuthException error) verificationFailed,
    void Function(String verificationId)? codeAutoRetrievalTimeout,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: timeout,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout ?? (_) {},
    );
  }

  /// 이슈 #750 — 휴대폰 인증 코드 검증 + users/{uid}.phoneVerified=true 저장.
  ///
  /// 동작:
  /// 1. PhoneAuthCredential 생성 → 현재 사용자에 linkWithCredential (가능한 경우)
  ///    이미 다른 provider(Google/Kakao)로 로그인된 사용자에 phone provider 추가.
  /// 2. linkWithCredential 실패 시 (이미 phone 연결됨 등) — Firestore 업데이트만 수행.
  /// 3. users/{uid} 문서에 phoneVerified=true, phoneNumber 저장.
  Future<void> verifyPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('로그인 상태가 아닙니다.');

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    String? phoneNumber;
    try {
      final result = await user
          .linkWithCredential(credential)
          .timeout(const Duration(seconds: 20));
      phoneNumber = result.user?.phoneNumber;
    } on FirebaseAuthException catch (e) {
      // 이미 휴대폰이 연결돼 있거나 다른 계정에 연결된 경우 — 검증만 시도 후 통과 처리.
      if (e.code == 'provider-already-linked' ||
          e.code == 'credential-already-in-use') {
        // 이미 같은 휴대폰이 연결된 상태 — Firestore만 갱신.
        phoneNumber = user.phoneNumber;
      } else {
        rethrow;
      }
    }

    await _db.collection('users').doc(user.uid).set({
      'phoneVerified': true,
      if (phoneNumber != null && phoneNumber.isNotEmpty)
        'phoneNumber': phoneNumber,
    }, SetOptions(merge: true)).timeout(const Duration(seconds: 12));
  }

  /// 구독 해지 예약 토글
  Future<void> setCancelAtPeriodEnd(String uid, bool cancel) async {
    await _db
        .collection('users')
        .doc(uid)
        .update({'subscription.cancelAtPeriodEnd': cancel})
        .timeout(const Duration(seconds: 10));
  }

  /// 회원 탈퇴 — Firebase Auth + Firestore 사용자 데이터 삭제
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('로그인 상태가 아닙니다.');
    final uid = user.uid;

    // Firestore 사용자 문서 삭제
    try {
      await _db.collection('users').doc(uid).delete()
          .timeout(const Duration(seconds: 10));
    } catch (_) {}

    // Firebase Auth 계정 삭제 (requires-recent-login 에러 시 재로그인 필요)
    await user.delete();
  }

  /// 이메일 재인증 (탈퇴 전 recent-login 필요 시)
  Future<void> reauthWithEmail({required String email, required String password}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('로그인 상태가 아닙니다.');
    final credential = EmailAuthProvider.credential(email: email, password: password);
    await user.reauthenticateWithCredential(credential);
  }

  /// Google 재인증
  Future<void> reauthWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('로그인 상태가 아닙니다.');
    if (kIsWeb) {
      await user.reauthenticateWithPopup(GoogleAuthProvider());
    } else {
      await _ensureGoogleInitialized();
      // 경량 인증 먼저 시도 (이미 로그인된 경우 계정 선택창 스킵)
      GoogleSignInAccount? account;
      try {
        account = await _googleSignIn.attemptLightweightAuthentication();
      } catch (_) {}
      // silent 실패 시 UI 표시
      account ??= await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw Exception('Google 재인증 실패');
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await user.reauthenticateWithCredential(credential);
    }
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
