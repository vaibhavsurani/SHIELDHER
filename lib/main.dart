import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.grey.shade50,
        primaryColor: const Color(0xFFC2185B),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFC2185B),
          secondary: Color(0xFFAB47BC),
          background: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.dark, // Dark icons for light background
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}


