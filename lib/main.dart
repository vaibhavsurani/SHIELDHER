import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shieldher/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://ddyqzkpkkdntkbnmiltq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRkeXF6a3Bra2RudGtibm1pbHRxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAzMzk1NjksImV4cCI6MjA4NTkxNTU2OX0.OqCZOFUHobY9dvDoNATetQBd-ojyqrVffvho6jnPayo',
  );
  runApp(const ShieldHerApp());
}

class ShieldHerApp extends StatelessWidget {
  const ShieldHerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ShieldHer',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212), // Deep dark background
        primaryColor: const Color(0xFFE91E63), // Safety Pink/Red
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE91E63),
          secondary: Color(0xFFAB47BC),
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
