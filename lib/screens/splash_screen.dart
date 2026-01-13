import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'home_screen.dart';

// Custom painter for dancer silhouette
class DancerSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Draw dancer silhouette - dynamic pose with raised arm and bent leg
    // Head
    path.addOval(Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.25),
      width: size.width * 0.16,
      height: size.width * 0.16,
    ));
    
    // Body
    path.addRect(Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.45),
      width: size.width * 0.12,
      height: size.height * 0.25,
    ));
    
    // Raised arm (left)
    path.addRect(Rect.fromCenter(
      center: Offset(size.width * 0.35, size.height * 0.35),
      width: size.width * 0.08,
      height: size.height * 0.2,
    ));
    
    // Lower arm (left)
    path.addRect(Rect.fromCenter(
      center: Offset(size.width * 0.25, size.height * 0.45),
      width: size.width * 0.15,
      height: size.width * 0.08,
    ));
    
    // Right arm
    path.addRect(Rect.fromCenter(
      center: Offset(size.width * 0.65, size.height * 0.45),
      width: size.width * 0.08,
      height: size.height * 0.15,
    ));
    
    // Left leg (bent)
    path.addRect(Rect.fromCenter(
      center: Offset(size.width * 0.45, size.height * 0.7),
      width: size.width * 0.06,
      height: size.height * 0.2,
    ));
    
    // Right leg (straight)
    path.addRect(Rect.fromCenter(
      center: Offset(size.width * 0.55, size.height * 0.75),
      width: size.width * 0.06,
      height: size.height * 0.2,
    ));
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    // Start animation
    _animationController.forward();
    
    // Navigate after 3 seconds
    _navigateAfterDelay();

    // One-time progress animation (fills once)
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    );
    _progressController.forward();
  }

  void _navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 3));
    
    if (mounted) {
      // Check if user is already logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Pure black background
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Align(
                  alignment: const Alignment(0, -0.12),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      _SplashLogo(),
                      Positioned(
                        // Pull tagline + progress up to sit just below the visible logo
                        bottom: -40, // place just under the logo image
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'One platform. Endless rhythm.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.5,
                              child: AnimatedBuilder(
                                animation: _progressController,
                                builder: (context, _) {
                                  return LinearProgressIndicator(
                                    value: _progressAnimation.value,
                                    minHeight: 3,
                                    color: const Color(0xFFE53935),
                                    backgroundColor: const Color(0x22FFFFFF),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Widget that tries to render `assets/dancerang_splash.png`.
/// Falls back to a vector painter if the asset is missing.
class _SplashLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final double maxWidth = MediaQuery.of(context).size.width * 0.92; // larger size
    return SizedBox(
      width: maxWidth,
      child: Image.asset(
        'assets/dancerang_splash.jpg',
        fit: BoxFit.contain,
      ),
    );
  }
}
