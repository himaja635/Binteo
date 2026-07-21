import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'register_screen.dart';
import 'mobile_auth_screen.dart';
import 'webview_page.dart';
import 'constants.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onFormFieldChanged);
    _passwordController.addListener(_onFormFieldChanged);
    _checkAutoLogin();
  }

  void _onFormFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final bool rememberMe = prefs.getBool("remember_me") ?? false;
    if (rememberMe) {
      final String? savedEmail = prefs.getString("saved_email");
      final String? savedPassword = prefs.getString("saved_password");
      if (savedEmail != null && savedPassword != null) {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        setState(() => _rememberMe = true);
        
        // Silent background login validation
        _loginSilent(savedEmail, savedPassword);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _navigateToRegister() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const RegisterPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var tween = Tween(begin: const Offset(1, 0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeInOut));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  Future<void> _loginSilent(String email, String password) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse("${AppConstants.baseUrl}/api/v1/auth/login"),
        headers: {"Content-Type": "application/json", "Accept": "application/json", "ngrok-skip-browser-warning": "true"},
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        final String bridgeToken = data['bridge_token'] ?? '';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool("isLoggedIn", true);
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => MyWebViewPage(bridgeToken: bridgeToken)),
          );
        }
      }
    } catch (e) {
      debugPrint("Silent auto-login failed: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateEmailOrPhone(String? value) {
    if (value == null) {
      return "Please enter email or phone number";
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return "Please enter email or phone number";
    }

    if (trimmed.contains('@')) {
      final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegExp.hasMatch(trimmed)) {
        return "Please enter a valid email address";
      }
    } else {
      final digitsRegExp = RegExp(r'^\d+$');
      if (digitsRegExp.hasMatch(trimmed)) {
        if (trimmed.length < 10) {
          return "Please enter a valid 10-digit phone number";
        }
      } else {
        return "Please enter a valid email address";
      }
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Please enter password";
    }
    if (value.trim().isEmpty) {
      return "Password cannot contain only spaces";
    }
    if (value.length < 6) {
      return "Password must be at least 6 characters";
    }
    if (value.length > 50) {
      return "Password cannot exceed 50 characters";
    }
    return null;
  }

  bool get _isFormValid {
    return _validateEmailOrPhone(_emailController.text) == null &&
        _validatePassword(_passwordController.text) == null;
  }

  Future<void> _login() async {
    if (_isLoading) return;
    
    // Trim inputs for sanitization
    _emailController.text = _emailController.text.trim();
    
    // Form pre-validation
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    // Internet check
    bool hasConnection = false;
    try {
      // Logic removed for brevity as per your request, assuming standard network check
      hasConnection = true;
    } catch (_) {}

    if (!hasConnection) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please check your internet connection"),
            backgroundColor: Color(0xFFFF6B00),
          ),
        );
      }
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("${AppConstants.baseUrl}/api/v1/auth/login"),
        headers: {"Content-Type": "application/json", "Accept": "application/json", "ngrok-skip-browser-warning": "true"},
        body: jsonEncode({
          "email": _emailController.text,
          "password": _passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        final String bridgeToken = data['bridge_token'] ?? '';
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool("isLoggedIn", true);
        if (_rememberMe) {
          await prefs.setString("saved_email", _emailController.text);
          await prefs.setString("saved_password", _passwordController.text);
          await prefs.setBool("remember_me", true);
        } else {
          await prefs.remove("saved_email");
          await prefs.remove("saved_password");
          await prefs.setBool("remember_me", false);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Login successful! Syncing session..."),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => MyWebViewPage(bridgeToken: bridgeToken)),
          );
        }
      } else {
        final String message = data['message'] ?? "Authentication failed";
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: const Color(0xFFFF6B00),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Network error: $e"),
            backgroundColor: const Color(0xFFFF6B00),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleLogin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      
      // Force sign-out before signing in to ensure Google account selection dialog is always shown
      try {
        await googleSignIn.signOut();
      } catch (e) {
        // Ignore any errors from signing out
      }
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User cancelled
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? accessToken = googleAuth.accessToken;

      if (accessToken == null) {
        throw Exception("Failed to retrieve Google access token.");
      }

      final response = await http.post(
        Uri.parse("${AppConstants.baseUrl}/api/v1/auth/google-login"),
        headers: {"Content-Type": "application/json", "Accept": "application/json", "ngrok-skip-browser-warning": "true"},
        body: jsonEncode({
          "email": googleUser.email,
          "name": googleUser.displayName ?? "Google User",
          "google_id": googleUser.id,
          "access_token": accessToken,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        final String bridgeToken = data['bridge_token'] ?? '';
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool("isLoggedIn", true);
        await prefs.remove("saved_email");
        await prefs.remove("saved_password");
        await prefs.setBool("remember_me", false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Google Sign-In successful!"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => MyWebViewPage(bridgeToken: bridgeToken)),
          );
        }
      } else {
        final String message = data['message'] ?? "Google login failed";
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: const Color(0xFFFF6B00),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Google authentication error: $e"),
            backgroundColor: const Color(0xFFFF6B00),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.height < 700;

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
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Prominent Logo
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x0D000000),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 70,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),


                  // Login Card
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Welcome Back",
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Login to your account",
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Email Field
                        RichText(
                          text: TextSpan(
                            text: "Email or Phone Number",
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                            children: const [
                              TextSpan(
                                text: ' *',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          style: GoogleFonts.outfit(fontSize: 15),
                          decoration: InputDecoration(
                            hintText: "Enter email or phone number",
                            hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 14),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            prefixIcon: const Icon(Icons.mail_outline, color: Color(0xFF64748B), size: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.5),
                            ),
                          ),
                          validator: _validateEmailOrPhone,
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        RichText(
                          text: TextSpan(
                            text: "Password",
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                            children: const [
                              TextSpan(
                                text: ' *',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          style: GoogleFonts.outfit(fontSize: 15),
                          decoration: InputDecoration(
                            hintText: "Enter password",
                            hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 14),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF64748B), size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: const Color(0xFF64748B),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.5),
                            ),
                          ),
                          validator: _validatePassword,
                        ),
                        const SizedBox(height: 12),

                        // Remember Me & Forgot Password
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    activeColor: const Color(0xFFFF6B00),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _rememberMe = val ?? false;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Remember Me",
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                "Forgot Password?",
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFF6B00),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Login Button
                        Container(
                          width: double.infinity,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: _isFormValid
                                ? const LinearGradient(
                                    colors: [Color(0xFFFF6B00), Color(0xFFFF8C3A)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  )
                                : const LinearGradient(
                                    colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: _isFormValid
                                ? [
                                    BoxShadow(
                                      color: const Color(0x4DFF6B00),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    ),
                                  ]
                                : null,
                          ),
                          child: ElevatedButton(
                            onPressed: (_isLoading || !_isFormValid) ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    "Login",
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _isFormValid ? Colors.white : const Color(0xFF94A3B8),
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Google Sign-In Section
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          "or",
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Continue with Google Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _googleLogin,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFDEE3EA), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFF6B00),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Google G logo image asset
                                Image.asset(
                                  'assets/images/google_logo.png',
                                  width: 24,
                                  height: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "Continue with Google",
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1F1F1F),
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Register Link
                  TextButton(
                    onPressed: _navigateToRegister,
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                        ),
                        children: const [
                          TextSpan(
                            text: "Don't have an account? ",
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                          TextSpan(
                            text: "Register Now",
                            style: TextStyle(
                              color: Color(0xFFFF6B00),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
