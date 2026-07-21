import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'webview_page.dart';
import 'constants.dart';


class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _referralController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(_onFormFieldChanged);
    _lastNameController.addListener(_onFormFieldChanged);
    _emailController.addListener(_onFormFieldChanged);
    _phoneController.addListener(_onFormFieldChanged);
    _passwordController.addListener(_onFormFieldChanged);
    _confirmPasswordController.addListener(_onFormFieldChanged);
    _referralController.addListener(_onFormFieldChanged);

    // Auto-fill referral code from URL query parameter 'reff' if available
    try {
      final refCode = Uri.base.queryParameters['reff'];
      if (refCode != null && refCode.isNotEmpty) {
        _referralController.text = refCode;
      }
    } catch (_) {}
  }

  void _onFormFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  String? _validateNameCore(String? value, String fieldName) {
    if (value == null) return "Please enter your $fieldName";
    final trimmed = value.trim();
    if (trimmed.isEmpty) return "Please enter your $fieldName";
    if (trimmed.length < 2) return "$fieldName must be at least 2 characters";
    if (trimmed.length > 50) return "$fieldName cannot exceed 50 characters";
    if (RegExp(r'^\d+$').hasMatch(trimmed)) return "$fieldName cannot contain only numbers";
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(trimmed)) return "Please enter a valid $fieldName";
    return null;
  }

  String? _validateFirstName(String? value) => _validateNameCore(value, "first name");
  String? _validateLastName(String? value) => _validateNameCore(value, "last name");

  String? _validateEmail(String? value) {
    if (value == null) {
      return "Please enter your email address";
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return "Please enter your email address";
    }
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(trimmed)) {
      return "Please enter a valid email address";
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null) {
      return "Please enter your phone number";
    }
    final cleaned = value.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) {
      return "Please enter your phone number";
    }
    if (cleaned.length != 10 && cleaned.length != 11) {
      return "Phone number must be 10 or 11 digits";
    }
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return "Please enter a valid phone number";
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
    if (!RegExp(r'[A-Z]').hasMatch(value) ||
        !RegExp(r'[a-z]').hasMatch(value) ||
        !RegExp(r'[0-9]').hasMatch(value)) {
      return "Password must contain uppercase, lowercase and a number";
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Please confirm your password";
    }
    if (value != _passwordController.text) {
      return "Passwords do not match";
    }
    return null;
  }

  bool get _isFormValid {
    return _validateFirstName(_firstNameController.text) == null &&
        _validateLastName(_lastNameController.text) == null &&
        _validateEmail(_emailController.text) == null &&
        _validatePhone(_phoneController.text) == null &&
        _validatePassword(_passwordController.text) == null &&
        _validateConfirmPassword(_confirmPasswordController.text) == null &&
        _acceptTerms;
  }

  Future<void> _register() async {
    if (_isLoading) return;

    // Trim and sanitize inputs
    _firstNameController.text = _firstNameController.text.trim();
    _lastNameController.text = _lastNameController.text.trim();
    _emailController.text = _emailController.text.trim();
    _phoneController.text = _phoneController.text.replaceAll(RegExp(r'\s+'), '');

    // Form pre-validation
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please accept Terms & Conditions and Privacy Policy"),
          backgroundColor: Color(0xFFFF6B00),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Internet connectivity check
    bool hasConnection = false;
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 4));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        hasConnection = true;
      }
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
        Uri.parse("${AppConstants.baseUrl}/api/v1/auth/register"),
        headers: {"Content-Type": "application/json", "Accept": "application/json", "ngrok-skip-browser-warning": "true"},
        body: jsonEncode({
          "firstname": _firstNameController.text.trim(),
          "lastname": _lastNameController.text.trim(),
          "email": _emailController.text,
          "phone": _phoneController.text,
          "password": _passwordController.text,
          "password_confirmation": _confirmPasswordController.text,
          "is_business": 0,
          "referred_by": _referralController.text.trim().isEmpty ? null : _referralController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        final String bridgeToken = data['bridge_token'] ?? '';
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool("isLoggedIn", true);
        await prefs.setString("saved_email", _emailController.text);
        await prefs.setString("saved_password", _passwordController.text);
        await prefs.setBool("remember_me", true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Registration successful! Syncing session..."),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => MyWebViewPage(bridgeToken: bridgeToken)),
          );
        }
      } else {
        String message = data['message'] ?? "Registration failed";
        if (data['errors'] != null) {
          final errors = data['errors'] as Map<String, dynamic>;
          if (errors.isNotEmpty) {
            final firstError = errors.values.first;
            if (firstError is List && firstError.isNotEmpty) {
              message = firstError.first.toString();
            } else {
              message = firstError.toString();
            }
          }
        }
        
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
                          height: 60,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 0),

                  // Register Card
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
                          "Create your account",
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Join thousands of buyers and sellers growing together",
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 20),

                        const SizedBox(height: 4),

                        // Fields Helper Builder
                        _buildLabel("First Name"),
                        _buildTextField(
                          controller: _firstNameController,
                          hint: "Enter your first name",
                          icon: Icons.person_outline,
                          validator: _validateFirstName,
                        ),
                        const SizedBox(height: 14),

                        _buildLabel("Last Name"),
                        _buildTextField(
                          controller: _lastNameController,
                          hint: "Enter your last name",
                          icon: Icons.person_outline,
                          validator: _validateLastName,
                        ),
                        const SizedBox(height: 14),

                        _buildLabel("Email Address"),
                        _buildTextField(
                          controller: _emailController,
                          hint: "Enter your email",
                          icon: Icons.mail_outline,
                          keyboard: TextInputType.emailAddress,
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 14),

                        _buildLabel("Phone Number"),
                        _buildTextField(
                          controller: _phoneController,
                          hint: "Enter your phone number",
                          icon: Icons.phone_android_outlined,
                          keyboard: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          validator: _validatePhone,
                        ),
                        const SizedBox(height: 14),

                        _buildLabel("Password"),
                        _buildPasswordField(
                          controller: _passwordController,
                          hint: "Create password",
                          obscure: _obscurePassword,
                          onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                          validator: _validatePassword,
                        ),
                        const SizedBox(height: 14),

                        _buildLabel("Confirm Password"),
                        _buildPasswordField(
                          controller: _confirmPasswordController,
                          hint: "Re-enter password",
                          obscure: _obscureConfirmPassword,
                          onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          validator: _validateConfirmPassword,
                        ),
                        const SizedBox(height: 14),


                        const SizedBox(height: 16),

                        // Terms & Conditions Checkbox
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _acceptTerms,
                                activeColor: const Color(0xFFFF6B00),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _acceptTerms = val ?? false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                    height: 1.4,
                                  ),
                                  children: const [
                                    TextSpan(text: "I accept the "),
                                    TextSpan(
                                      text: "Terms & Conditions",
                                      style: TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(text: " and "),
                                    TextSpan(
                                      text: "Privacy Policy",
                                      style: TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Register Button
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
                            onPressed: (_isLoading || !_isFormValid) ? null : _register,
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
                                    "Register",
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

                  // Bottom Text (Already have an account? Login Now)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                        ),
                        children: const [
                          TextSpan(
                            text: "Already have an account? ",
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                          TextSpan(
                            text: "Login Now",
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
    );
  }

  Widget _buildLabel(String text, {bool isRequired = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          text: text,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF475569),
          ),
          children: isRequired
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]
              : const [],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: GoogleFonts.outfit(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
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
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: GoogleFonts.outfit(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF64748B), size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: const Color(0xFF64748B),
            size: 20,
          ),
          onPressed: onToggle,
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
      validator: validator,
    );
  }
}