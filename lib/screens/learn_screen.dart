import 'package:flutter/material.dart';
import 'package:shieldher/widgets/app_header.dart'; // Import AppHeader

class LearnScreen extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final VoidCallback? onNotificationTap;
  final int notificationCount;
  final Function(int) onNavigate; // Add onNavigate callback

  const LearnScreen({
    super.key,
    required this.scaffoldKey,
    this.onNotificationTap,
    this.notificationCount = 0,
    required this.onNavigate,
  });

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  // ignore: unused_field
  int _currentStep = 0;
  // ignore: unused_field
  final int _totalSteps = 3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
     _fadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Header
          AppHeader(
            scaffoldKey: widget.scaffoldKey,
            onNotificationTap: widget.onNotificationTap,
            notificationCount: widget.notificationCount,
          ),
          
          Expanded(
            child: SingleChildScrollView(
              child: SizedBox(
                height: MediaQuery.of(context).size.height - 150, // Approx height ensuring validation
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // Header Text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        "How to Use SOS",
                        style: TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.pink.shade700
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
            const SizedBox(height: 10),
             const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                "Learn how to activate emergency mode even when your screen is locked.",
                style: TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ),
            
            const Spacer(),
            
            // Animated Visuals
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Phone Silhouette
                  Container(
                    width: 180,
                    height: 320,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.grey.shade300, width: 4),
                      boxShadow: [
                         BoxShadow(
                          color: Colors.pink.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ]
                    ),
                  ),
                  
                  // Volume Buttons (Left Side)
                  Positioned(
                    left: -4, // Peek out
                    top: 80,
                    child: Column(
                      children: [
                        // Volume Up (Static)
                        Container(
                          width: 8,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4), 
                              bottomLeft: Radius.circular(4)
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                         // Volume Down (Animated)
                        AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _scaleAnimation.value,
                              child: Container(
                                width: 8,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.pink.shade600, // Active Color
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(4), 
                                    bottomLeft: Radius.circular(4)
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.pink.withOpacity(0.4),
                                      blurRadius: 10 * _fadeAnimation.value,
                                      spreadRadius: 2,
                                    )
                                  ]
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  
                   // Screen Content (Internal)
                   Positioned(
                     top: 40,
                     child: Icon(
                       Icons.local_police, 
                       size: 60, 
                       color: Colors.pink.shade100
                     )
                   ),
                   Positioned(
                     bottom: 40,
                     child: AnimatedBuilder(
                       animation: _controller,
                       builder: (context, child) {
                         return Text(
                           "PRESS 3 TIMES",
                           style: TextStyle(
                             fontWeight: FontWeight.bold,
                             color: Colors.pink.shade600.withOpacity(_fadeAnimation.value),
                             letterSpacing: 1.5,
                           ),
                         );
                       }
                     )
                   )
                ],
              ),
            ),
            
            const Spacer(),
            
            // Steps Overlay
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.pink.shade100),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                       color: Colors.white,
                       shape: BoxShape.circle,
                       border: Border.all(color: Colors.pink.shade200),
                    ),
                    child: Text(
                      "3x", 
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 20, 
                        color: Colors.pink.shade700
                      )
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Volume Down Button",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Press rapidy to trigger Emergency Mode instantly.",
                          style: TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            
            // Done Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => widget.onNavigate(0), // Go back to Home Tab
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: Colors.pink.withOpacity(0.4),
                  ),
                  child: const Text(
                    "Got it!",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
