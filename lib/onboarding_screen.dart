import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'webview_page.dart';
import 'splash_screen.dart';
import 'login_screen.dart';
import 'constants.dart';

class OnboardingSlide {
  final String title;
  final String description;
  final String imageUrl;

  OnboardingSlide({
    required this.title,
    required this.description,
    required this.imageUrl,
  });

  factory OnboardingSlide.fromJson(Map<String, dynamic> json) {
    return OnboardingSlide(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'] ?? '',
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<OnboardingSlide> _slides = [];
  bool _isLoading = false; // Set to false to immediately load the static/fallback slides without spinner blocking

  // Fallback onboarding slides if the API is offline or fails
  final List<OnboardingSlide> _fallbackSlides = [
    OnboardingSlide(
      title: "Discover Nearby Opportunities",
      description: "Find listings, offers, services, jobs, properties, and products around your location.",
      imageUrl: "assets/images/oboarding1.png",
    ),
    OnboardingSlide(
      title: "Advertise & Grow Your Business",
      description: "Create listings, promote your products, and boost visibility with banner advertising packages.",
      imageUrl: "assets/images/onboarding2.png",
    ),
    OnboardingSlide(
      title: "Reach More Customers & Generate Leads",
      description: "Publish across multiple locations and connect directly with interested customers.",
      imageUrl: "assets/images/onboarding3 (1).png",
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize slides with fallback pages immediately so there is no blank screen
    _slides = List.from(_fallbackSlides);
    _fetchOnboardingSlides();
  }

  Future<void> _fetchOnboardingSlides() async {
    try {
      final response = await http.get(
        Uri.parse("${AppConstants.baseUrl}/api/v1/onboarding"),
        headers: {
          "Accept": "application/json",
          "ngrok-skip-browser-warning": "true",
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final List<dynamic> list = data['data'];
          final parsedSlides = list.map((item) => OnboardingSlide.fromJson(item)).toList();
          
          if (mounted) {
            setState(() {
              // Ensure we have exactly three slides by taking 3 or padding with fallbacks
              if (parsedSlides.length >= 3) {
                _slides = parsedSlides.sublist(0, 3);
              } else {
                _slides = parsedSlides;
                for (int i = _slides.length; i < 3; i++) {
                  _slides.add(_fallbackSlides[i]);
                }
              }
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching onboarding slides: $e");
    }
  }

  Future<void> _onIntroEnd(BuildContext context) async {
    debugPrint('OnboardingScreen: _onIntroEnd called');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingCompleted', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var tween = Tween(begin: const Offset(0, 1), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeInOut));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _limitCharacters(String text, int limit) {
    if (text.length <= limit) {
      return text;
    }
    return '${text.substring(0, limit)}...';
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.height < 700;
    
    // Pixel-perfect height allocations based on complete screen height
    final double imageHeight = size.height * 0.55;
    final double textHeight = size.height * 0.45;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFAFBFC),
              Color(0xFFF5F7FA),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // --- Swipable PageView (covers complete screen height so swiping text or image transitions both) ---
            PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemBuilder: (context, index) {
                final slide = _slides[index];
                return Column(
                  children: [
                    // Upper 55% Screen Height - Image Container
                    SizedBox(
                      height: imageHeight,
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          children: [
                            // Transparent spacer to leave room for the fixed Skip button overlay
                            const SizedBox(height: 50),
                            
                            // Illustration Image
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 15,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: slide.imageUrl.startsWith('http')
                                      ? Image.network(
                                          slide.imageUrl,
                                          fit: BoxFit.contain,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return const Center(
                                              child: CircularProgressIndicator(
                                                color: Color(0xFFFF6B00),
                                              ),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Center(
                                              child: Icon(
                                                Icons.image_not_supported_outlined,
                                                color: Colors.grey,
                                                size: 48,
                                              ),
                                            );
                                          },
                                        )
                                      : Image.asset(
                                          slide.imageUrl,
                                          fit: BoxFit.contain,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Lower 45% Screen Height - Text Content Container
                    SizedBox(
                      height: textHeight,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          // Bottom padding leaves room for the fixed Dots & Buttons overlay
                          padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 140.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Title Text (Split dynamically to color last word orange)
                              Builder(
                                builder: (context) {
                                  final fullTitle = slide.title;
                                  final words = fullTitle.trim().split(' ');
                                  String firstPart = '';
                                  String secondPart = '';
                                  if (words.length > 1) {
                                    secondPart = words.last;
                                    firstPart = words.sublist(0, words.length - 1).join(' ') + ' ';
                                  } else {
                                    firstPart = fullTitle;
                                  }
                                  return RichText(
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    text: TextSpan(
                                      style: GoogleFonts.outfit(
                                        fontSize: isSmallScreen ? 23 : 26,
                                        fontWeight: FontWeight.bold,
                                        height: 1.25,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: _limitCharacters(firstPart, 60),
                                          style: const TextStyle(color: Color(0xFF1E293B)),
                                        ),
                                        TextSpan(
                                          text: _limitCharacters(secondPart, 30),
                                          style: const TextStyle(color: Color(0xFFFF6B00)),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              ),
                              const SizedBox(height: 10),

                              // Description Text
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text(
                                  _limitCharacters(slide.description, 280),
                                  textAlign: TextAlign.center,
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: const Color(0xFF64748B),
                                    height: 1.45,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // --- Fixed Top Bar (Skip Button) Overlay ---
            Positioned(
              top: 0,
              right: 0,
              left: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _onIntroEnd(context),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Text(
                          "Skip",
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- Fixed Bottom Actions (Dots & Buttons) Overlay ---
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Custom Smooth Dots Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_slides.length, (index) => _buildDot(index)),
                      ),
                      const SizedBox(height: 20),

                      // Next / Get Started Buttons
                      if (_currentPage == _slides.length - 1) ...[
                        // Last Screen Action Buttons
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () => _onIntroEnd(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B00),
                              elevation: 4,
                              shadowColor: const Color(0x66FF6B00),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Get Started",
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // Other Screens Action Buttons
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B00),
                              elevation: 4,
                              shadowColor: const Color(0x66FF6B00),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Next Opportunity",
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    final bool isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFFF6B00) : Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

}
