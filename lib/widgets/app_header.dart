import 'package:flutter/material.dart';

/// Common app header widget used across all screens
/// Displays logo, app name, live/offline status, notifications, and menu
class AppHeader extends StatelessWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final bool showLiveStatus;
  final bool isLive;
  final VoidCallback? onLiveToggle;
  final VoidCallback? onNotificationTap;
  final int notificationCount;

  const AppHeader({
    super.key,
    this.scaffoldKey,
    this.showLiveStatus = false,
    this.isLive = false,
    this.onLiveToggle,
    this.onNotificationTap,
    this.notificationCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo and brand name
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo - uses PNG if available, fallback to gradient container
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFC2185B), Color(0xFFAD1457)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.shield, color: Colors.white, size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'ShieldHer',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFC2185B),
                      letterSpacing: -0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Action buttons
          Row(
            children: [
              // Live status indicator (optional)
              if (showLiveStatus)
                GestureDetector(
                  onTap: onLiveToggle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isLive ? const Color(0xFFC2185B) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isLive ? Colors.white : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isLive ? 'Live' : 'Offline',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isLive ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (showLiveStatus) const SizedBox(width: 4),
              // Notification bell with badge
              Stack(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, size: 22),
                      color: Colors.black87,
                      onPressed: onNotificationTap ?? () {},
                    ),
                  ),
                  if (notificationCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFC2185B),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          '$notificationCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              // Menu
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.menu_rounded, size: 22),
                  color: Colors.black87,
                  onPressed: () => scaffoldKey?.currentState?.openDrawer(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
