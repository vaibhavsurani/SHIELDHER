import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:shieldher/screens/home_screen.dart';
import 'package:shieldher/screens/login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = Supabase.instance.client.auth.currentSession;
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
