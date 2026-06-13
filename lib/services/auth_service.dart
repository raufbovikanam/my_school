import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:desktop_webview_auth/desktop_webview_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'local_db_helper.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  static const String _isLoggedInKey = 'is_logged_in';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '938898056822-oeg6nghfu6gkt6ijasd632jthlroheqc.apps.googleusercontent.com',
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  );

  GoogleSignInAccount? _currentUser;
  String? _desktopAccessToken;
  GoogleSignInAccount? get currentUser => _currentUser;

  Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, value);
  }

  Future<void> _setLoggedIn(bool value) async {
    await setLoggedIn(value);
  }

  Future<bool> isLocallyLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  Future<AuthClient?> get authClient async {
    if (Platform.isWindows) {
      if (_desktopAccessToken == null) return null;
      final credentials = AccessCredentials(
        AccessToken(
          'Bearer',
          _desktopAccessToken!,
          DateTime.now().add(const Duration(hours: 1)).toUtc(),
        ),
        null,
        _googleSignIn.scopes,
      );
      return authenticatedClient(http.Client(), credentials);
    }

    final user = _currentUser ?? await signInSilently();
    if (user == null) return null;

    final authentication = await user.authentication;
    final token = authentication.accessToken;

    if (token == null) return null;

    final credentials = AccessCredentials(
      AccessToken(
        'Bearer',
        token,
        DateTime.now().add(const Duration(hours: 1)).toUtc(),
      ),
      null,
      _googleSignIn.scopes,
    );

    return authenticatedClient(http.Client(), credentials);
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      if (Platform.isWindows) {
        final clientId = '938898056822-oeg6nghfu6gkt6ijasd632jthlroheqc.apps.googleusercontent.com';

        final provider = GoogleAuth(
          clientId: clientId,
          scopes: _googleSignIn.scopes,
        );

        final result = await DesktopWebviewAuth().signIn(provider);

        if (result == null) return null;
        final accessToken = result.accessToken;
        final idToken = result.idToken;

        if (accessToken == null) return null;
        _desktopAccessToken = accessToken;

        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: accessToken,
          idToken: idToken,
        );
        await _auth.signInWithCredential(credential);

        await _setLoggedIn(true);
        return null;
      }

      _currentUser = await _googleSignIn.signIn();
      if (_currentUser != null) {
        final GoogleSignInAuthentication googleAuth = await _currentUser!.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await _auth.signInWithCredential(credential);

        await _setLoggedIn(true);
      }
      return _currentUser;
    } catch (error) {
      debugPrint('Sign in failed: $error');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      if (Platform.isWindows) {
        _desktopAccessToken = null;
        await _auth.signOut();
        await LocalDbHelper.instance.closeDatabase();
        await _setLoggedIn(false);
        _currentUser = null;
        return;
      }

      await _googleSignIn.signOut();
      await _auth.signOut();
      await LocalDbHelper.instance.closeDatabase();
      await _setLoggedIn(false);
      _currentUser = null;
    } catch (e) {
      debugPrint('Sign out failed: $e');
    }
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      if (Platform.isWindows) {
        return null;
      }
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser != null) {
        final GoogleSignInAuthentication googleAuth = await _currentUser!.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await _auth.signInWithCredential(credential);

        await _setLoggedIn(true);
      }
      return _currentUser;
    } catch (e) {
      debugPrint('Sign in silently failed: $e');
      return null;
    }
  }

  Future<bool> isSignedIn() async {
    if (await isLocallyLoggedIn()) return true;
    if (Platform.isWindows) {
      return _desktopAccessToken != null || _auth.currentUser != null;
    }
    return await _googleSignIn.isSignedIn();
  }
}