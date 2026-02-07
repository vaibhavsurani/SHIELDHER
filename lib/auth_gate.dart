import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:shieldher/screens/home_screen.dart';
import 'package:shieldher/screens/login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // Listen for auth state changes and sync profile when user logs in
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && data.session?.user != null) {
        _syncUserProfile(data.session!.user);
      }
    });
  }

  Future<void> _syncUserProfile(User user) async {
    try {
      // Check if profile already exists
      final existingProfile = await _supabase
          .from('user_profiles')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingProfile == null) {
        // Create profile from user metadata
        final metadata = user.userMetadata;
        await _supabase.from('user_profiles').insert({
          'user_id': user.id,
          'username': (metadata?['username'] ?? user.email?.split('@').first ?? 'user_${user.id.substring(0, 8)}').toString().toLowerCase(),
          'display_name': metadata?['name'] ?? 'User',
          'phone': metadata?['phone'] ?? '',
        });
        print('User profile created for: ${user.id}');
      }
    } catch (e) {
      print('Error syncing user profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<AuthState>(
        stream: _supabase.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = _supabase.auth.currentSession;
          // User is logged in
          if (session != null) {
            return const HomeScreen();
          }

          // User is NOT logged in
          else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
