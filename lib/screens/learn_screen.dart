import 'package:flutter/material.dart';
import 'package:shieldher/widgets/app_header.dart'; // Import AppHeader
import 'package:shieldher/widgets/accessibility_warning_widget.dart';

class LearnScreen extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final VoidCallback? onNotificationTap;
  final int notificationCount;
  final Function(int) onNavigate; // Add onNavigate callback
  final bool isAccessibilityEnabled;
  final VoidCallback onEnableAccessibility;

  const LearnScreen({
    super.key,
    required this.scaffoldKey,
    this.onNotificationTap,
    this.notificationCount = 0,
    required this.onNavigate,
    required this.isAccessibilityEnabled,
    required this.onEnableAccessibility,
  });

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _showWarning = true;
  
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
          AppHeader(
            scaffoldKey: widget.scaffoldKey,
            onNotificationTap: widget.onNotificationTap,
            notificationCount: widget.notificationCount,
          ),
          
          if (!widget.isAccessibilityEnabled && _showWarning)
            AccessibilityWarningWidget(
              onEnablePressed: widget.onEnableAccessibility,
              onDismiss: () {}, 
              canDismiss: false,
            ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                children: [
                  // --- Level 1 ---
                  _buildLevelSection(
                    level: 1, 
                    presses: 3, 
                    title: "Level 1: Silent Alert", 
                    descriptionPoints: [
                      "Sends your Live Location instantly.",
                      "Sends background SOS SMS to all contacts.",
                      "Discreet operation (no sound)."
                    ],
                    color: Colors.orange.shade700
                  ),
                  
                  _buildEscalationArrow("Press 1 more time to escalate (4x total)"),
                  
                  // --- Level 2 ---
                  _buildLevelSection(
                    level: 2, 
                    presses: 4, 
                    title: "Level 2: Active Tracking", 
                    descriptionPoints: [
                      "Initiates call to primary emergency contact.",
                      "Enables real-time location tracking loop.",
                      "Updates location every 15 seconds."
                    ],
                    color: Colors.deepOrange.shade700
                  ),
                  
                  _buildEscalationArrow("Press 1 more time to escalate (5x total)"),
                  
                  // --- Level 3 ---
                  _buildLevelSection(
                    level: 3, 
                    presses: 5, 
                    title: "Level 3: Full Emergency", 
                    descriptionPoints: [
                      "Starts audio recording immediately.",
                      "Plays loud siren to attract attention.",
                      "Broadcasts high-priority alerts to everyone."
                    ],
                    color: Colors.red.shade900
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // --- Got It Button ---
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => widget.onNavigate(0),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: Colors.pink.withOpacity(0.4),
                      ),
                      child: const Text("Got it!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelSection({required int level, required int presses, required String title, required List<String> descriptionPoints, required Color color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          )
        ]
      ),
      child: Column(
        children: [
          // Title
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 20),
          
          // Animation
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none, // Allow drawing outside bounds
              children: [
                // Phone
                Container(
                  width: 100,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300, width: 3),
                  ),
                ),
                
                // Volume Down Indicator Icon (New)
                Positioned(
                  left: -50, 
                  top: 30,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: Column(
                            children: [
                              Icon(Icons.volume_up_rounded, size: 28, color: color),
                              const SizedBox(height: 2),
                              Icon(Icons.arrow_downward_rounded, size: 24, color: color),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Buttons
                Positioned(
                  left: -3, top: 40,
                  child: Column(
                    children: [
                      Container(width: 4, height: 20, color: Colors.grey.shade300),
                      const SizedBox(height: 6),
                      // Animated Button
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Container(
                              width: 4, height: 20,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10 * _fadeAnimation.value)]
                              ),
                            ),
                          );
                        }
                      )
                    ],
                  ),
                ),
                // Press Count Text
                Positioned(
                  right: -10, bottom: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                    ),
                    child: Text("${presses}x", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  )
                )
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Description Points
          Column(
            children: descriptionPoints.map((point) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Icon(Icons.check_circle, size: 18, color: color.withOpacity(0.8)),
                   const SizedBox(width: 8),
                   Expanded(
                     child: Text(
                       point, 
                       style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.4)
                     )
                   ),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEscalationArrow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.arrow_downward_rounded, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Icon(Icons.arrow_downward_rounded, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}
