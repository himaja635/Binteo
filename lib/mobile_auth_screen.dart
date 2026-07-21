import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'webview_page.dart';
import 'constants.dart';


class MobileAuthScreen extends StatefulWidget {
  const MobileAuthScreen({Key? key}) : super(key: key);

  @override
  State<MobileAuthScreen> createState() => _MobileAuthScreenState();
}

class _MobileAuthScreenState extends State<MobileAuthScreen> {
  int _currentStep = 1; // 1: Mobile Verification, 2: Personal Details
  bool _isLoading = false;
  bool _otpSent = false;
  bool _isRegistered = false;

  // Controllers for Step 1
  final _mobileController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  // Form Keys
  final _mobileFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _detailsFormKey = GlobalKey<FormState>();

  // Controllers for Step 2
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _referralController = TextEditingController();
  late TextEditingController _readOnlyMobileController;

  String _verifiedMobile = "";

  @override
  void initState() {
    super.initState();
    _mobileController.addListener(_onFormFieldChanged);
    for (int i = 0; i < 6; i++) {
      _otpControllers[i].addListener(_onFormFieldChanged);
    }
    _nameController.addListener(_onFormFieldChanged);
    _emailController.addListener(_onFormFieldChanged);
    _referralController.addListener(_onFormFieldChanged);
    _readOnlyMobileController = TextEditingController();
  }

  void _onFormFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _mobileController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    _nameController.dispose();
    _emailController.dispose();
    _referralController.dispose();
    _readOnlyMobileController.dispose();
    super.dispose();
  }

  // --- Validations ---

  String? _validateMobileNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Mobile Number is required";
    }
    final trimmed = value.trim();
    if (trimmed.length != 10 || !RegExp(r'^\d{10}$').hasMatch(trimmed)) {
      return "Please enter a valid 10-digit mobile number";
    }
    return null;
  }



  String? _validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Name is required";
    }
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return "Please enter a valid name";
    }
    if (trimmed.length > 50) {
      return "Please enter a valid name";
    }
    // Only alphabets and spaces, no numbers, no special characters
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(trimmed)) {
      return "Please enter a valid name";
    }
    return null;
  }

  String? _validateEmailOptional(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional
    }
    final trimmed = value.trim();
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(trimmed)) {
      return "Please enter a valid email address";
    }
    return null;
  }

  // --- API / Logic Flows ---

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _sendOtp() async {
    if (_isLoading) return;
    if (!_mobileFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    bool hasConnection = await _checkInternetConnection();
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

    final mobileNumber = _mobileController.text.trim();

    try {
      // Try hitting the backend OTP endpoint
      final response = await http.post(
        Uri.parse("${AppConstants.baseUrl}/api/v1/auth/send-otp"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "ngrok-skip-browser-warning": "true"
        },
        body: jsonEncode({"phone": mobileNumber}),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        setState(() {
          _isRegistered = data['is_registered'] ?? false;
          _otpSent = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("OTP sent successfully!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final String message = data['message'] ?? "Failed to send OTP";
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: const Color(0xFFFF6B00)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: const Color(0xFFFF6B00)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  

  void _verifyOtp() {
    final otpStr = _otpControllers.map((c) => c.text).join();
    if (otpStr.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid OTP"),
          backgroundColor: Color(0xFFFF6B00),
        ),
      );
      return;
    }

    if (!_isRegistered) {
      // For new registration, transition locally to details step.
      // We will perform actual verification in _submitDetails along with registration.
      setState(() {
        _verifiedMobile = _mobileController.text.trim();
        _readOnlyMobileController.text = "+91 $_verifiedMobile";
        _currentStep = 2; // Navigate to Personal Details
      });
      return;
    }

    // For registered users, verify OTP and login immediately
    _loginWithOtp(otpStr);
  }

  Future<void> _loginWithOtp(String otpStr) async {
    setState(() => _isLoading = true);

    bool hasConnection = await _checkInternetConnection();
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

    final mobileNumber = _mobileController.text.trim();

    try {
      final response = await http.post(
        Uri.parse("${AppConstants.baseUrl}/api/v1/auth/verify-otp"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "ngrok-skip-browser-warning": "true"
        },
        body: jsonEncode({
          "phone": mobileNumber,
          "otp": otpStr,
          "name": "Existing User",
          "email": null
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        final String bridgeToken = data['bridge_token'] ?? '';
        _completeLoginAndRedirect(bridgeToken);
      } else {
        final String message = data['message'] ?? "Invalid OTP code";
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: const Color(0xFFFF6B00)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: const Color(0xFFFF6B00)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  



  Future<void> _submitDetails() async {
    if (_isLoading) return;
    if (!_detailsFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    bool hasConnection = await _checkInternetConnection();
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

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _verifiedMobile;
    final otpStr = _otpControllers.map((c) => c.text).join();
    final referral = _referralController.text.trim();

    try {
      final response = await http.post(
        Uri.parse("${AppConstants.baseUrl}/api/v1/auth/verify-otp"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "ngrok-skip-browser-warning": "true"
        },
        body: jsonEncode({
          "phone": phone,
          "otp": otpStr,
          "name": name,
          "email": email.isEmpty ? null : email,
          "referred_by": referral.isEmpty ? null : referral,
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);

      if ((response.statusCode == 201 || response.statusCode == 200) && data['status'] == 'success') {
        final String bridgeToken = data['bridge_token'] ?? '';
        _completeLoginAndRedirect(bridgeToken);
      } else {
        final String message = data['message'] ?? "Registration failed";
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: const Color(0xFFFF6B00)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: const Color(0xFFFF6B00)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  

  Future<void> _completeLoginAndRedirect(String bridgeToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("isLoggedIn", true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Authentication successful! Redirecting..."),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => MyWebViewPage(bridgeToken: bridgeToken)),
        (route) => false,
      );
    }
  }

  // --- UI Layouts ---

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.height < 700;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () {
            if (_currentStep == 2) {
              setState(() {
                _currentStep = 1;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          _currentStep == 1 ? "Verify Mobile Number" : "Personal Details",
          style: GoogleFonts.outfit(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        height: double.infinity,
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
            child: _currentStep == 1
                ? _buildVerificationStep(isSmallScreen)
                : _buildPersonalDetailsStep(isSmallScreen),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationStep(bool isSmallScreen) {
    return Column(
      children: [
        // Illustration
        Container(
          height: isSmallScreen ? 150 : 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/mobile_verify_illustration.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 16),

        Text(
          "Enter your mobile number",
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "We will send you a one-time password (OTP)",
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Mobile Form
        Form(
          key: _mobileFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel("Mobile Number"),
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.number,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                style: GoogleFonts.outfit(fontSize: 16),
                maxLength: 10,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  hintText: "Enter 10 digit mobile number",
                  hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  prefixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 16),
                      const Icon(Icons.phone_outlined, color: Color(0xFF64748B), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "+91",
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 20,
                        width: 1,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(width: 12),
                    ],
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
                validator: _validateMobileNumber,
              ),
              const SizedBox(height: 20),

              // Send OTP Button
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: _mobileController.text.length == 10
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
                  boxShadow: _mobileController.text.length == 10
                      ? [
                          BoxShadow(
                            color: const Color(0x4DFF6B00),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: ElevatedButton(
                  onPressed: (_isLoading) ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading && !_otpSent
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "Send OTP",
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _mobileController.text.length == 10
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),

        // OTP Section (Only shows after OTP is sent successfully)
        if (_otpSent) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  "Enter OTP sent to your mobile number",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
            ],
          ),
          const SizedBox(height: 20),

          Form(
            key: _otpFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel("Verify OTP"),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: (MediaQuery.of(context).size.width - 48 - 40) / 6,
                      child: TextFormField(
                        controller: _otpControllers[index],
                        focusNode: _otpFocusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(1),
                        ],
                        decoration: InputDecoration(
                          counterText: "",
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.5),
                          ),
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            if (index < 5) {
                              FocusScope.of(context).requestFocus(_otpFocusNodes[index + 1]);
                            } else {
                              FocusScope.of(context).unfocus();
                            }
                          } else {
                            if (index > 0) {
                              FocusScope.of(context).requestFocus(_otpFocusNodes[index - 1]);
                            }
                          }
                          setState(() {});
                        },
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),

                // Verify Button
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: _isOtpComplete
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
                    boxShadow: _isOtpComplete
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFF6B00).withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: ElevatedButton(
                    onPressed: (_isLoading || !_isOtpComplete) ? null : _verifyOtp,
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
                            "Verify",
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _isOtpComplete ? Colors.white : const Color(0xFF94A3B8),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildPersonalDetailsStep(bool isSmallScreen) {
    return Column(
      children: [
        // Illustration
        Container(
          height: isSmallScreen ? 140 : 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/personal_details_illustration.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 16),

        Text(
          "Please enter your details",
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "This information will help us personalize your experience",
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Form Details
        Form(
          key: _detailsFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel("Full Name"),
              TextFormField(
                controller: _nameController,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                style: GoogleFonts.outfit(fontSize: 15),
                decoration: InputDecoration(
                  hintText: "Enter your full name",
                  hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF64748B), size: 20),
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
                validator: _validateFullName,
              ),
              const SizedBox(height: 16),

              _buildLabel("Email Address (Optional)", isRequired: false),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                style: GoogleFonts.outfit(fontSize: 15),
                decoration: InputDecoration(
                  hintText: "Enter your email address",
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
                validator: _validateEmailOptional,
              ),
              const SizedBox(height: 16),

              _buildLabel("Referral Code (Optional)", isRequired: false),
              TextFormField(
                controller: _referralController,
                textCapitalization: TextCapitalization.characters,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                style: GoogleFonts.outfit(fontSize: 15),
                decoration: InputDecoration(
                  hintText: "Enter referral code (if any)",
                  hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  prefixIcon: const Icon(Icons.card_giftcard, color: Color(0xFF64748B), size: 20),
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
              ),
              const SizedBox(height: 16),

              _buildLabel("Mobile Number"),
              TextFormField(
                controller: _readOnlyMobileController,
                readOnly: true,
                style: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFF64748B)),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF94A3B8), size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "We will use this number for all communications",
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: _isDetailsFormValid
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
                  boxShadow: _isDetailsFormValid
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF6B00).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: ElevatedButton(
                  onPressed: (_isLoading || !_isDetailsFormValid) ? null : _submitDetails,
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
                          "Submit",
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isDetailsFormValid ? Colors.white : const Color(0xFF94A3B8),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
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

  bool get _isOtpComplete {
    return _otpControllers.every((controller) => controller.text.isNotEmpty);
  }

  bool get _isDetailsFormValid {
    return _validateFullName(_nameController.text) == null &&
        _validateEmailOptional(_emailController.text) == null;
  }
}
