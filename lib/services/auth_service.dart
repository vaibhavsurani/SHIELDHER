import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
  serverClientId: '635785585974-6g8g6gtnjfkale52ncjea8elfuiqsjbn.apps.googleusercontent.com',
);

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Stream of auth changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Password validation
  static String? validatePassword(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain an uppercase letter';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain a number';
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain a special character';
    }
    return null; // Password is valid
  }

  // Sign In
  Future<AuthResponse> signInWithEmailPassword(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  // Sign Up with phone number and email verification
  Future<AuthResponse> signUpWithEmailPassword(
    String email, 
    String password, 
    String name,
    String phone,
    String username,
  ) async {
    try {
      // Create user
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'phone': phone,
          'username': username,
        },
      );
      
      // Create user profile with username for invite-by-username feature
      if (response.user != null) {
        try {
          await _supabase.from('user_profiles').upsert({
            'user_id': response.user!.id,
            'username': username.toLowerCase(),
            'display_name': name,
            'phone': phone,
          });
        } catch (e) {
          // Profile creation failed, but auth succeeded - log but don't fail
          debugPrint('Warning: Could not create user profile: $e');
        }
      }
      
      return response;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // Google Sign In
  Future<AuthResponse> signInWithGoogle() async {
    try {
      // Web flow (handled by supabase_flutter mostly, but google_sign_in needed for native)
      // For Native (Android/iOS)
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google Sign-In canceled');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('No ID Token found.');
      }

      return await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } on Exception catch (e) {
       throw Exception('Google Sign-In failed: $e');
    }
  }


  // Get user data (from metadata or public table)
  // Assuming we might want to fetch from 'public.users' if we sync it, 
  // or just use user_metadata from the auth user object.
  // For migration simplicity, let's look at user metadata first.
  Map<String, dynamic>? getUserMetadata() {
    return _supabase.auth.currentUser?.userMetadata;
  }

  // Get user name
  String getUserName() {
    final metadata = getUserMetadata();
    return metadata?['name'] ?? 'User';
  }

  // Sign Out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    return await _supabase.auth.signOut();
  }
}
