import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shieldher/auth_gate.dart';
import 'package:shieldher/services/power_button_sos_service.dart';
import 'package:shieldher/services/audio_recorder_service.dart';
import 'package:shieldher/services/emergency_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Initialize Supabase
    try {
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL'] ?? '',
        anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
      );
    } catch (e) {
      // already initialized or error
      debugPrint("Supabase init error (or already initialized): $e");
    }

    // 2. Initialize Power Button SOS Service (after Supabase is ready)
    PowerButtonSOSService().initialize();
    
    // 3. Sync any pending offline audio recordings AND contacts
    await AudioRecorderService().syncPendingUploads();
    await EmergencyService().syncPendingContacts();

    // 2. Minimum splash duration for branding (optional, keeps logo visible for at least 1.5s)
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    // 3. Navigate to AuthGate
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AuthGate(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
             Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC2185B).withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.shield, size: 80, color: Color(0xFFC2185B));
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
            // App Name
            const Text(
              "SHIELDHER",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                color: Color(0xFFC2185B),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Safety for every woman",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 48),
            // Loading Indicator
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC2185B)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
