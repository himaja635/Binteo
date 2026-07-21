import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'webview_page.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import 'constants.dart';
import 'package:google_fonts/google_fonts.dart';

class LaundryIntroScreen extends StatefulWidget {
  const LaundryIntroScreen({Key? key}) : super(key: key);

  @override
  State<LaundryIntroScreen> createState() => _LaundryIntroScreenState();
}

class _LaundryIntroScreenState extends State<LaundryIntroScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _autoNavTimer;

  @override
  void initState() {
    super.initState();

    // 1. Set up premium 1.5 seconds animation controller for fade/scale effects
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutBack, // Elegant ease-in-out curve with a subtle overshoot bounce
    ));

    // Start the animation
    _controller.forward();

    // 2. Schedule navigation after exactly 3 seconds
    _autoNavTimer = Timer(const Duration(seconds: 3), _navigate);
  }

  @override
  void dispose() {
    _controller.dispose();
    _autoNavTimer?.cancel();
    super.dispose();
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    
    final prefs = await SharedPreferences.getInstance();
    final bool onboardingDone = prefs.getBool('onboardingCompleted') ?? false;
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    
    if (!mounted) return;

    Widget targetScreen;
    if (isLoggedIn) {
      targetScreen = const MyWebViewPage();
    } else if (onboardingDone) {
      targetScreen = const LoginPage();
    } else {
      targetScreen = const OnboardingScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var tween = Tween(begin: const Offset(0, 1), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeInOut));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFF8C39), // Soft vibrant orange
              Color(0xFFFF6B00), // Core brand orange
              Color(0xFFE05F00), // Deep premium orange
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _animation,
            child: ScaleTransition(
              scale: _animation,
              child: Container(
                width: 220, // Expanded width to perfectly fit the rectangular logo aspect ratio
                height: 140, // Standard premium card height
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), // Elegant white padding border
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain, // Fits the full image beautifully inside without cropping!
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
