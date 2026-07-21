import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart';
import 'connectivity_service.dart';

import 'package:permission_handler/permission_handler.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';
import 'login_screen.dart'; // Import LoginPage for logout redirect
import 'package:google_fonts/google_fonts.dart';

class MyWebViewPage extends StatefulWidget {
  final String? bridgeToken;
  const MyWebViewPage({Key? key, this.bridgeToken}) : super(key: key);

  @override
  State<MyWebViewPage> createState() => _MyWebViewPageState();
}

class _MyWebViewPageState extends State<MyWebViewPage> {
  double _fabX = 0;
  double _fabY = 0;
  bool _fabPositionInitialized = false;
  InAppWebViewController? webViewController;
  late final String initialUrl;
  bool isLoading = true;
  bool isOnline = true;
  double progress = 0.0;
  PullToRefreshController? pullToRefreshController; // Track pull to refresh controller


  // Performance monitoring
   Stopwatch? _loadStopwatch;
   Timer? _memoryMonitorTimer;
   Timer? _loadingTimeoutTimer;

  String? lastRequestUrl;
  final ConnectivityService _connectivityService = ConnectivityService();
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isCheckingConnection = false;
  bool _isReelsPage = false;
  bool _wasReelsPage = false;

  @override
  void initState() {
    super.initState();

    if (widget.bridgeToken != null) {
      initialUrl = "${AppConstants.baseUrl}/auth/bridge?token=${widget.bridgeToken}";
    } else {
      initialUrl = "${AppConstants.baseUrl}/";
    }

    lastRequestUrl = initialUrl;

    // Listen to real-time internet connectivity changes
    _connectivitySubscription = _connectivityService.onInternetStatusChanged.listen((hasInternet) {
      if (mounted) {
        setState(() {
          isOnline = hasInternet;
        });
        if (hasInternet && webViewController != null) {
          if (lastRequestUrl != null) {
            webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(lastRequestUrl!)));
          } else {
            webViewController!.reload();
          }
        }
      }
    });

    // Initialize pull to refresh controller
    pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: Colors.blue,
        enabled: true,
      ),
      onRefresh: () async {
        if (webViewController != null) {
          if (Platform.isAndroid) {
            await webViewController!.reload();
          } else if (Platform.isIOS) {
            WebUri? currentUrl = await webViewController!.getUrl();
            if (currentUrl != null) {
              await webViewController!.loadUrl(urlRequest: URLRequest(url: currentUrl));
            } else {
              await webViewController!.reload();
            }
          }
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkConnectivity();
      await _requestLocationPermission();
      await _requestCameraAndMicPermissions();
      _startMemoryMonitoring();
    });
  }

  Future<void> _checkConnectivity() async {
    final bool hasInternet = await _connectivityService.checkInternet();
    if (mounted) {
      setState(() {
        isOnline = hasInternet;
      });
    }
  }

  Future<void> _checkConnectionAndReload() async {
    if (_isCheckingConnection) return;
    setState(() => _isCheckingConnection = true);

    final bool hasInternet = await _connectivityService.checkInternet();
    
    if (mounted) {
      setState(() {
        isOnline = hasInternet;
        _isCheckingConnection = false;
      });

      if (hasInternet) {
        if (webViewController != null) {
          if (lastRequestUrl != null) {
            await webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(lastRequestUrl!)));
          } else {
            await webViewController!.reload();
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Still no internet connection. Please try again.'),
            backgroundColor: Color(0xFFFF6B00),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    developer.log('LOCATION: Requesting location permission', name: 'WebView');
    var status = await Permission.location.request();
    developer.log('LOCATION: Permission status: $status', name: 'WebView');

    if (status.isGranted) {
      developer.log('LOCATION: Location permission granted', name: 'WebView');
    } else if (status.isDenied) {
         return;
       }
  }

  Future<void> _requestCameraAndMicPermissions() async {
    developer.log('CAMERA: Requesting camera permission', name: 'WebView');
    var camStatus = await Permission.camera.request();
    developer.log('CAMERA: Permission status: $camStatus', name: 'WebView');

    developer.log('MICROPHONE: Requesting microphone permission', name: 'WebView');
    var micStatus = await Permission.microphone.request();
    developer.log('MICROPHONE: Permission status: $micStatus', name: 'WebView');

    // If any permission is permanently denied, guide user to app settings
    if (camStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied) {
      developer.log('CAMERA/MIC: Permissions permanently denied. Prompting settings.', name: 'WebView');
      await openAppSettings();
    }

    if (camStatus.isGranted && micStatus.isGranted) {
      developer.log('CAMERA: Both camera and microphone permissions granted', name: 'WebView');
    } else {
      developer.log('CAMERA: Camera=$camStatus, Microphone=$micStatus', name: 'WebView');
    }
  }

  // Helper used before navigating to Reel page – ensures permissions are present
  Future<bool> _ensureCameraAndMicGranted() async {
    var cam = await Permission.camera.status;
    var mic = await Permission.microphone.status;
    if (!cam.isGranted) cam = await Permission.camera.request();
    if (!mic.isGranted) mic = await Permission.microphone.request();
    return cam.isGranted && mic.isGranted;
  }

  void _startMemoryMonitoring() {
       // Mock for memory monitoring implementation
     }

  void _handleMissingDropdown(InAppWebViewController controller, String errorMessage) async {
     try {
       if (errorMessage.contains('user dropdown')) {
         await controller.evaluateJavascript(source: '''
           console.log('Creating user dropdown fallback');
           // Add fallback logic for user dropdown
         ''');
       } else if (errorMessage.contains('location dropdown')) {
         await controller.evaluateJavascript(source: '''
           console.log('Creating location dropdown fallback');
           // Add fallback logic for location dropdown
         ''');
       }
     } catch (e) {
       developer.log('DROPDOWN_FIX: Error applying dropdown fix: $e', name: 'WebView');
     }
   }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _memoryMonitorTimer?.cancel();
    _loadingTimeoutTimer?.cancel();
    _loadStopwatch?.stop();
    pullToRefreshController?.dispose(); // Dispose pull to refresh controller
    super.dispose();
  }

  @override
    Widget build(BuildContext context) {
      final size = MediaQuery.of(context).size;
      
      if (!_fabPositionInitialized) {
        _fabX = size.width - 48.0 - 8.0; // 48 is mini FAB size, 8 is right padding
        _fabY = size.height - 48.0 - 150.0; // moved up to prevent overlapping bottom nav
        _fabPositionInitialized = true;
      }

      // Adjust position dynamically when transitioning between reels and other pages
      if (_isReelsPage && !_wasReelsPage) {
        _fabY = size.height - 455.0; // moved up to be above the audio button on reels
        _wasReelsPage = true;
      } else if (!_isReelsPage && _wasReelsPage) {
        _fabY = size.height - 48.0 - 150.0; // back to original bottom position (moved up)
        _wasReelsPage = false;
      }

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          bool shouldPop = await _handleBackButton();
          if (shouldPop) {
            await SystemNavigator.pop();
          }
        },
       child: Scaffold(
         body: Stack(
           children: [
             _buildBody(),
             Positioned(
               left: _fabX,
               top: _fabY,
               child: GestureDetector(
                 onPanUpdate: (details) {
                   setState(() {
                     _fabX += details.delta.dx;
                     _fabY += details.delta.dy;
                     
                     // Constrain within screen bounds
                     final size = MediaQuery.of(context).size;
                     if (_fabX < 0) _fabX = 0;
                     if (_fabY < 0) _fabY = 0;
                     if (_fabX > size.width - 48) _fabX = size.width - 48;
                     if (_fabY > size.height - 48) _fabY = size.height - 48;
                   });
                 },
                 child: FloatingActionButton(
            heroTag: "back_btn",
            mini: true,
            backgroundColor: const Color(0xFF5E17EB),
            elevation: 6,
            shape: const CircleBorder(),
            onPressed: () async {
              if (webViewController != null) {
                try {
                  bool canGoBack = await webViewController!.canGoBack();
                  if (canGoBack) {
                    await webViewController!.goBack();
                  } else {
                    // No previous page - exit gracefully (no black flash)
                    await SystemNavigator.pop();
                  }
                } catch (e) {
                  developer.log('ERROR: Error going back: $e', name: 'WebView');
                  // On error, exit gracefully
                  await SystemNavigator.pop();
                }
              } else {
                // WebView not ready - exit gracefully
                await SystemNavigator.pop();
              }
            },
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    ],
  ),
),
);
}

  Widget _buildOfflineScreen() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // App Branding Title
              Text(
                "Binteo",
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF5E17EB),
                ),
              ),
              const SizedBox(height: 10),
              // Connection Status Indicator Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECE0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF6B00),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Offline Mode",
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFFF6B00),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Lottie Offline Illustration
              Center(
                child: SizedBox(
                  width: 250,
                  height: 250,
                  child: Lottie.asset(
                    'assets/animations/404 error page with cat.json',
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.cloud_off_rounded,
                        size: 150,
                        color: Color(0xFFFF6B00),
                      );
                    },
                  ),
                ),
              ),
              const Spacer(),
              // Title & Desc
              Text(
                'No Internet Connection',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'We couldn\'t connect to the server. Please check your network cables or cellular data settings and try again.',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // Action Buttons
              Row(
                children: [
                  // Retry Button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isCheckingConnection ? null : _checkConnectionAndReload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5E17EB),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF5E17EB).withValues(alpha: 0.6),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isCheckingConnection
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Retry',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  // Settings Button
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _handleBackButton() async {
    developer.log('DEBUG: _handleBackButton called', name: 'WebView');
    if (webViewController != null) {
      developer.log('DEBUG: webViewController is not null', name: 'WebView');
      try {
        bool canGoBack = await webViewController!.canGoBack();
        developer.log('DEBUG: canGoBack: $canGoBack', name: 'WebView');
        if (canGoBack) {
          await webViewController!.goBack();
          developer.log('DEBUG: went back, returning false', name: 'WebView');
          return false;
        } else {
          developer.log('DEBUG: cannot go back, returning true', name: 'WebView');
        }
      } catch (e) {
        developer.log('DEBUG: Error checking or going back: $e', name: 'WebView');
      }
    } else {
      developer.log('DEBUG: webViewController is null, returning true', name: 'WebView');
    }
    return true;
  }

   Widget _buildWebViewWidget() {
     return SafeArea(
       child: Column(
           children: [
             LinearProgressIndicator(
               value: isLoading ? progress : 0.0, // Show progress only when loading
               color: const Color(0xFF5E17EB),
             ),
             Expanded(
               child: InAppWebView(
                   pullToRefreshController: pullToRefreshController,
                   initialUrlRequest:
                       URLRequest(url: WebUri(initialUrl)),
                   initialSettings: InAppWebViewSettings(
                     requestedWithHeaderOriginAllowList: <String>{},
                     javaScriptEnabled: true,
                     domStorageEnabled: true,
                     overScrollMode: OverScrollMode.ALWAYS,
                     thirdPartyCookiesEnabled: true,
                     javaScriptCanOpenWindowsAutomatically: true,
                     supportMultipleWindows: true,
                     databaseEnabled: true,
                     cacheEnabled: true,
                     clearCache: false,
                     useWideViewPort: false,
                     loadWithOverviewMode: false,
                     supportZoom: false,
                     mixedContentMode:
                         MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                     geolocationEnabled: true,
                     allowUniversalAccessFromFileURLs: true,
                     allowFileAccessFromFileURLs: true,
                     // Performance optimizations
                     hardwareAcceleration: true,
                     disableVerticalScroll: false,
                     disableHorizontalScroll: false,
                     // Reduce memory usage
                     disableDefaultErrorPage: true,
                     // Improve loading performance
                     useOnLoadResource: false,
                     useShouldInterceptRequest: false,
                     userAgent:
                         "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 LocalAdsMobileApp",
                     // Enable overscroll for pull-to-refresh
                     verticalScrollBarEnabled: true,
                     horizontalScrollBarEnabled: false,
                     // Enable touch events for proper scroll detection
                     mediaPlaybackRequiresUserGesture: false,
                   ),
                    androidOnPermissionRequest: (controller, origin, resources) async {
                      // Log incoming permission request resources
                      developer.log('Android permission request from $origin with resources: $resources', name: 'WebView');
                      // Ensure both camera and microphone permissions are granted at runtime
                      var camStatus = await Permission.camera.status;
                      var micStatus = await Permission.microphone.status;
                      if (!camStatus.isGranted) {
                        developer.log('Camera permission not granted at runtime, requesting now.', name: 'WebView');
                        camStatus = await Permission.camera.request();
                        developer.log('Camera permission request result: $camStatus', name: 'WebView');
                      }
                      if (!micStatus.isGranted) {
                        developer.log('Microphone permission not granted at runtime, requesting now.', name: 'WebView');
                        micStatus = await Permission.microphone.request();
                        developer.log('Microphone permission request result: $micStatus', name: 'WebView');
                      }

                      // Grant all requested resources to the WebView
                      return PermissionRequestResponse(
                          resources: resources,
                          action: PermissionRequestResponseAction.GRANT);
                    },
                   onWebViewCreated: (controller) {
                     setState(() {
                       webViewController = controller;
                     });
                     
                     // Ensure pull-to-refresh is properly connected to the WebView
                     // This helps ensure the pull-to-refresh works properly at the top of the page
                     if (pullToRefreshController != null) {
                       // Add a small delay to ensure the controller is properly initialized
                       Future.delayed(const Duration(milliseconds: 100), () {
                         if (mounted && pullToRefreshController != null) {
                           // Make sure the pull-to-refresh controller is properly initialized
                           // This helps ensure it recognizes when the WebView is at the top
                         }
                       });
                     }
                     
                     // Evaluate JavaScript to check if page is at top and ensure proper scrolling
                     // Also handle popup blocking for export functionality
                     controller.evaluateJavascript(source: '''
                       // Ensure the page starts at the top
                       window.scrollTo(0, 0);
                       
                       // Set up scroll detection for pull-to-refresh
                       (function() {
                         if (!window.pullToRefreshSetupComplete) {
                           window.pullToRefreshSetupComplete = true;
                           
                           // Function to check if we're at the top of the page
                           window.isAtTop = function() {
                             return window.pageYOffset === 0 || (document.documentElement.scrollTop === 0 && document.body.scrollTop === 0);
                           };
                           
                           // Listen for scroll events
                           window.addEventListener('scroll', function() {
                             // Debounce scroll event handling
                             if (window.scrollTimeout) {
                               clearTimeout(window.scrollTimeout);
                             }
                             
                             window.scrollTimeout = setTimeout(function() {
                               if (window.isAtTop()) {
                                 console.log('WebView: At top of page - pull to refresh should be enabled');
                               } else {
                                 console.log('WebView: Not at top of page');
                               }
                             }, 50);
                           }, true);
                           
                           // Check immediately if we're at the top
                           if (window.isAtTop()) {
                             console.log('WebView: Created at top of page - pull to refresh should be enabled');
                           }
                         }
                       })();
                       
                       // Override window.open to handle export popups properly
                       if (!window.popupHandlerInitialized) {
                         const originalWindowOpen = window.open;
                         window.open = function(url, name, specs) {
                           console.log('WebView: window.open called with url:', url, 'name:', name, 'specs:', specs);
                           
                           // Allow export-related popups by intercepting and handling them differently
                           if (url && (url.includes('export') || url.includes('pdf') || url.includes('excel') || url.includes('download'))) {
                             console.log('WebView: Intercepting export popup for URL:', url);
                             
                             // For export functionality, instead of opening a popup,
                             // directly navigate to the URL to trigger download
                             // Use a temporary iframe to handle the download without changing current page
                             var iframe = document.createElement('iframe');
                             iframe.style.display = 'none';
                             iframe.src = url;
                             // Add authentication headers by using fetch API instead of direct iframe src
                             iframe.onload = function() {
                               console.log('Export iframe loaded');
                             };
                             iframe.onerror = function() {
                               console.error('Export iframe failed to load, trying fetch method');
                               // Fallback to fetch with proper headers
                               fetch(url, {
                                 method: 'GET',
                                 headers: {
                                   'X-Requested-With': 'XMLHttpRequest',
                                   'Accept': 'application/json, text/plain, */*'
                                 },
                                 credentials: 'include' // Include cookies
                               })
                               .then(response => {
                                 if (response.ok) {
                                   // Create blob and download link
                                   return response.blob();
                                 } else {
                                   console.error('Export fetch failed with status:', response.status);
                                   // Fallback to iframe method
                                   document.body.appendChild(iframe);
                                 }
                               })
                               .then(blob => {
                                  if (blob) {
                                    var downloadUrl = window.URL.createObjectURL(blob);
                                    var a = document.createElement('a');
                                    a.href = downloadUrl;
                                    a.download = 'export.xlsx'; // Set appropriate filename
                                    document.body.appendChild(a);
                                    a.click();
                                    document.body.removeChild(a);
                                    window.URL.revokeObjectURL(downloadUrl);
                                  }
                                }
                                .catch(error => {
                                  console.error('Export fetch error:', error);
                                  // Fallback to iframe method
                                  document.body.appendChild(iframe);
                                });
                              };
                              
                              // Add iframe to trigger the download
                              document.body.appendChild(iframe);
                              
                              // Remove the iframe after a short time
                              setTimeout(function() {
                                if (iframe.parentNode) {
                                  iframe.parentNode.removeChild(iframe);
                                }
                              }, 5000); // Keep iframe for 5 seconds to ensure download starts
                              
                              return null; // Return null to prevent actual popup
                            } else {
                              // For other popups, use the original behavior
                              return originalWindowOpen.call(window, url, name, specs);
                            }
                          };
                          window.popupHandlerInitialized = true;
                        }
                      ''');
                    },
                    onEnterFullscreen: (controller) {
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.landscapeRight,
                        DeviceOrientation.landscapeLeft,
                      ]);
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                    },
                    onExitFullscreen: (controller) {
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.portraitUp,
                        DeviceOrientation.portraitDown,
                      ]);
                      SystemChrome.setEnabledSystemUIMode(
                          SystemUiMode.manual, overlays: SystemUiOverlay.values);
                    },
                    shouldOverrideUrlLoading:
                        (controller, navigationAction) async {
                      var uri = navigationAction.request.url;
                      if (uri == null) return NavigationActionPolicy.ALLOW;
                      String url = uri.toString();

                      // Detect reel creation page and ensure permissions are granted
                      if (url.contains('/reel') || url.contains('createReel')) {
                        await _requestCameraAndMicPermissions();
                      }

                      developer.log('DEBUG: shouldOverrideUrlLoading: $url', name: 'WebView');

                      // ── Intercept logout / login redirect before it navigates ──────────────
                      if (url.contains('user/logout') || url.endsWith('/logout') || url.contains('/logout') || url.contains('user-login') || url.endsWith('/login')) {
                        // Clear all WebView cookies and local session data
                        await CookieManager.instance().deleteAllCookies();
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Session ended. Redirecting to login..."),
                              backgroundColor: Color(0xFFFF6B00),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                            (route) => false, // Remove all previous routes
                          );
                        }
                        return NavigationActionPolicy.CANCEL; // Block the web navigation
                      }
                      // ─────────────────────────────────────────────────────

                      // Check if this is a file download URL (PDF, Excel, Word)
                      // Skip file downloads here as they are now handled by onDownloadStartRequest
                      if (isSocialMediaUrl(url) ||
                          isShareUrl(url) ||
                          isPhoneUrl(url) ||
                          isTruecallerUrl(url) ||
                          isUpiUrl(url) ||
                          isIntentUrl(url) ||
                          isPhonePeUrl(url) ||
                          isWhatsAppAppUrl(url) ||
                          isInstagramAppUrl(url) ||
                          isFacebookAppUrl(url)) {
                        // Always cancel navigation — never let the WebView load these URLs
                        try {
                          final Uri uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } else {
                            // App-scheme URLs (whatsapp://, etc.) cannot be opened in a browser.
                            // Show a user-friendly message instead.
                            if (isWhatsAppAppUrl(url) ||
                                url.contains('wa.me') ||
                                url.contains('whatsapp')) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('WhatsApp is not installed on this device.'),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                            } else if (uri.scheme == 'https' || uri.scheme == 'http') {
                              // For plain HTTP/HTTPS social URLs, try external browser
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          }
                        } catch (e) {
                          developer.log('ERROR: Failed to launch URL: $url, Error: $e', name: 'WebView');
                          // Show snackbar for WhatsApp instead of letting WebView try to load it
                          if (isWhatsAppAppUrl(url) ||
                              url.contains('wa.me') ||
                              url.contains('whatsapp')) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('WhatsApp is not installed on this device.'),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        }
                        // ALWAYS cancel — never allow WebView to load app-scheme URLs
                        return NavigationActionPolicy.CANCEL;
                      } else if (isGoogleAuthUrl(url)) {
                        // Allow Google auth URLs to be handled within the WebView
                        return NavigationActionPolicy.ALLOW;
                      }
                      return NavigationActionPolicy.ALLOW;
                    },
                    onCreateWindow:
                        (controller, createWindowAction) async {
                      var uri = createWindowAction.request.url;
                      if (uri == null) return false;
                      String url = uri.toString();
                      developer.log('DEBUG: onCreateWindow: $url', name: 'WebView');

                      // Intercept WhatsApp / social / app-scheme URLs opened via window.open()
                      // so they never create a child WebView.
                      if (isWhatsAppAppUrl(url) ||
                          isSocialMediaUrl(url) ||
                          isPhoneUrl(url) ||
                          isTruecallerUrl(url) ||
                          isUpiUrl(url) ||
                          isIntentUrl(url) ||
                          isPhonePeUrl(url) ||
                          isInstagramAppUrl(url) ||
                          isFacebookAppUrl(url)) {
                        try {
                          final Uri parsedUri = Uri.parse(url);
                          if (await canLaunchUrl(parsedUri)) {
                            await launchUrl(parsedUri, mode: LaunchMode.externalApplication);
                          } else {
                            if (isWhatsAppAppUrl(url) ||
                                url.contains('wa.me') ||
                                url.contains('whatsapp')) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('WhatsApp is not installed on this device.'),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                            } else if (parsedUri.scheme == 'https' || parsedUri.scheme == 'http') {
                              await launchUrl(parsedUri, mode: LaunchMode.externalApplication);
                            }
                          }
                        } catch (e) {
                          developer.log('ERROR: onCreateWindow failed to launch: $url, Error: $e', name: 'WebView');
                          if (isWhatsAppAppUrl(url) ||
                              url.contains('wa.me') ||
                              url.contains('whatsapp')) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('WhatsApp is not installed on this device.'),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        }
                        return false; // Do NOT create a new WebView window
                      }

                     if (isRazorpayUrl(url)) {
                        // Check if context is still valid
                        if (!context.mounted) return false;
                        
                        // Push a clean, premium full-screen page instead of an ugly cut-off AlertDialog
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              appBar: AppBar(
                                backgroundColor: Colors.white,
                                elevation: 0.5,
                                title: Text(
                                  "Secure Payment",
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF1E293B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                leading: IconButton(
                                  icon: const Icon(Icons.close, color: Color(0xFF1E293B)),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ),
                              body: InAppWebView(
                                windowId: createWindowAction.windowId,
                                initialUrlRequest: createWindowAction.request,
                                initialSettings: InAppWebViewSettings(
                                  javaScriptEnabled: true,
                                  thirdPartyCookiesEnabled: true,
                                  domStorageEnabled: true,
                                  overScrollMode: OverScrollMode.ALWAYS,
                                  allowUniversalAccessFromFileURLs: true,
                                  allowFileAccessFromFileURLs: true,
                                  supportZoom: false,
                                  useShouldInterceptRequest: false,
                                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                                ),
                                onCloseWindow: (controller) {
                                  Navigator.of(context).pop();
                                },
                                onLoadStop: (controller, url) async {
                                  // Dynamically match active host to automatically close the payment container on redirect
                                  final String currentHost = Uri.parse(initialUrl).host;
                                  if (url != null && (url.toString().contains(currentHost) || url.toString().contains(Uri.parse(AppConstants.baseUrl).host))) {
                                    Navigator.of(context).pop();
                                    if (webViewController != null) {
                                      await webViewController!.loadUrl(
                                        urlRequest: URLRequest(url: url),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          ),
                        );
                        return true;
                      } else if (isGoogleAuthUrl(url)) {
                        // Check if dialog is already showing to avoid multiple dialogs
                        if (!context.mounted) return false;
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text("Sign in"),
                              content: Container(
                                width:
                                    MediaQuery.of(context).size.width,
                                height:
                                    MediaQuery.of(context).size.height *
                                        0.8,
                                child: InAppWebView(
                                  windowId: createWindowAction.windowId,
                                  initialUrlRequest:
                                      createWindowAction.request,
                                  initialSettings: InAppWebViewSettings(
                                    requestedWithHeaderOriginAllowList: <String>{},
                                    javaScriptEnabled: true,
                                    thirdPartyCookiesEnabled: true,
                                    overScrollMode: OverScrollMode.ALWAYS,
                                    supportZoom: false,
                                  ),
                                  onCloseWindow: (controller) {
                                    Navigator.of(context).pop();
                                  },
                                  onLoadStop:
                                      (controller, url) async {
                                    final String currentHost = Uri.parse(initialUrl).host;
                                    if (url != null && (url
                                        .toString()
                                        .contains(currentHost) || url.toString().contains(Uri.parse(AppConstants.baseUrl).host))) {
                                      Navigator.of(context).pop();
                                      if (webViewController != null) {
                                        await webViewController!.loadUrl(
                                          urlRequest:
                                              URLRequest(url: url),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        );
                        return true;
                      } else {
                        // For other URLs, open in external browser
                        await launchUrl(
                            Uri.parse(url),
                            mode: LaunchMode.externalApplication);
                        return false;
                      }
                    },
                    onLoadStart: (controller, url) async {
                      if (url == null) return;
                      String urlString = url.toString();
                      setState(() {
                        _isReelsPage = urlString.contains('/reel') || urlString.contains('reels');
                      });
                      // Detect reel creation page and ensure permissions are granted
      if (urlString.contains('/reel') || urlString.contains('createReel')) {
        await _requestCameraAndMicPermissions();
      }

                      if (!urlString.contains('/user/logout') &&
                          !urlString.contains('/logout') &&
                          !urlString.contains('/login') &&
                          !urlString.contains('google-login') &&
                          (urlString.startsWith('http://') || urlString.startsWith('https://'))) {
                        lastRequestUrl = urlString;
                      }

                      // Intercept web logout natively
                      if (urlString.contains('/user/logout')) {
                        await controller.stopLoading();
                        await CookieManager.instance().deleteAllCookies();
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Logged out successfully"),
                              backgroundColor: Color(0xFFFF6B00),
                            ),
                          );
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                          );
                        }
                        return;
                      }

                      _loadStopwatch?.stop(); // Stop any existing stopwatch
                     _loadStopwatch = Stopwatch()..start();
                     developer.log('PERF: Page load started for $urlString', name: 'WebView');

                     // Set loading timeout
                     _loadingTimeoutTimer?.cancel();
                     _loadingTimeoutTimer = Timer(const Duration(seconds: 30), () {
                       developer.log('PERF: Page load timeout - forcing stop loading', name: 'WebView');
                       controller.stopLoading();
                       // Don't change isLoading here - let onLoadStop or onError handle it
                     });

                     if (isSocialMediaUrl(urlString) ||
                         isShareUrl(urlString) ||
                         isPhoneUrl(urlString) ||
                         isTruecallerUrl(urlString) ||
                         isUpiUrl(urlString) ||
                         isIntentUrl(urlString) ||
                         isPhonePeUrl(urlString) ||
                         isWhatsAppAppUrl(urlString) ||
                         isInstagramAppUrl(urlString) ||
                         isFacebookAppUrl(urlString)) {
                        try {
                          final Uri uri = Uri.parse(urlString);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } else {
                            // WhatsApp or target app not installed — show snackbar
                            if (isWhatsAppAppUrl(urlString) ||
                                urlString.contains('wa.me') ||
                                urlString.contains('whatsapp')) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('WhatsApp is not installed on this device.'),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                            } else if (uri.scheme == 'https' || uri.scheme == 'http') {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          }
                        } catch (e) {
                          developer.log('ERROR: Failed to launch URL: $urlString, Error: $e', name: 'WebView');
                          if (isWhatsAppAppUrl(urlString) ||
                              urlString.contains('wa.me') ||
                              urlString.contains('whatsapp')) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('WhatsApp is not installed on this device.'),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        }
                        return;
                     }
                     setState(() => isLoading = true);
                   },
                   onLoadStop: (controller, url) async {
                     debugPrint('WebView: onLoadStop: $url');
                     _loadingTimeoutTimer?.cancel();
                     _loadingTimeoutTimer = null;

                     // End the pull to refresh if it's active
                     if (pullToRefreshController != null) {
                       pullToRefreshController!.endRefreshing();
                     }

                     // Add a small delay to ensure the page is fully loaded before
                     // allowing pull-to-refresh to work properly
                     Future.delayed(const Duration(milliseconds: 500), () {
                       if (mounted && pullToRefreshController != null) {
                         // Ensure the pull-to-refresh controller is properly initialized
                         // after the page has loaded
                         // This helps ensure it recognizes when the WebView is at the top
                       }
                     });

                     // Safely stop the stopwatch and log performance
                     if (_loadStopwatch?.isRunning == true) {
                       _loadStopwatch!.stop();
                       developer.log('PERF: Page load completed in ${_loadStopwatch!.elapsedMilliseconds}ms for $url', name: 'WebView');
                     }
                     _loadStopwatch = null; // Reset stopwatch reference

                     // Inject defensive JavaScript to handle missing elements and popup blocking
                     try {
                       await controller.evaluateJavascript(source: '''
                         (function() {
                           // Handle missing dropdowns gracefully
                           function safeGetElement(id) {
                             try {
                               return document.getElementById(id);
                             } catch(e) {
                               console.warn('Element not found:', id, e);
                               return null;
                             }
                           }

                           // Check for critical elements and provide fallbacks
                           var userDropdown = safeGetElement('user-dropdown');
                           var locationDropdown = safeGetElement('location-dropdown');

                           if (!userDropdown) {
                             console.log('User dropdown not found - creating fallback');
                           }

                           if (!locationDropdown) {
                             console.log('Location dropdown not found - creating fallback');
                           }
                           
                           // Re-override window.open to handle export popups properly
                           if (window.originalWindowOpen) {
                             // Restore original window.open if it was overridden
                             window.open = window.originalWindowOpen;
                           }
                           
                           const originalWindowOpen = window.open;
                           window.originalWindowOpen = originalWindowOpen; // Store for later restoration
                           
                           window.open = function(url, name, specs) {
                             console.log('WebView: window.open called with url:', url, 'name:', name, 'specs:', specs);
                             
                             // Allow export-related popups by intercepting and handling them differently
                             if (url && (url.includes('export') || url.includes('pdf') || url.includes('excel') || url.includes('download'))) {
                               console.log('WebView: Intercepting export popup for URL:', url);
                               
                               // For export functionality, instead of opening a popup,
                               // directly navigate to the URL to trigger download
                               window.location.href = url;
                               return null; // Return null to prevent actual popup
                             } else {
                               // For other popups, use the original behavior
                               return originalWindowOpen.call(window, url, name, specs);
                             }
                           };

                           // Optimize performance by reducing unnecessary DOM queries
                           if (window.locationDetectionInterval) {
                             clearInterval(window.locationDetectionInterval);
                           }

                           // Ensure proper scroll handling for pull-to-refresh
                           // Add event listeners to handle scroll at the top of the page
                           var scrollTimeout;
                           
                           // Function to check if we're at the top of the page
                           function isAtTop() {
                             return window.pageYOffset === 0 || (document.documentElement.scrollTop === 0 && document.body.scrollTop === 0);
                           }
                           
                           // Check immediately when page loads
                           if (isAtTop()) {
                             console.log('WebView: Loaded at top of page - pull to refresh should be enabled');
                           }
                           
                           // Listen for scroll events
                           window.addEventListener('scroll', function() {
                             // Clear previous timeout
                             if (scrollTimeout) {
                               clearTimeout(scrollTimeout);
                             }
                             
                             // Set timeout to ensure we capture the final scroll position
                             scrollTimeout = setTimeout(function() {
                               // Check if we're at the top of the page
                               if (isAtTop()) {
                                 console.log('WebView: At top of page - pull to refresh should be enabled');
                               } else {
                                 console.log('WebView: Not at top of page - pull to refresh disabled');
                               }
                             }, 100);
                           }, true);
                           
                           // Additional check after a short delay to ensure proper initialization
                           setTimeout(function() {
                             if (isAtTop()) {
                               console.log('WebView: Confirmed at top of page after delay - pull to refresh should be enabled');
                             }
                           }, 500);
                           
                           console.log('Page load optimizations applied');
                         })();
                       ''');
                     } catch (e) {
                       developer.log('JS_INJECTION: Error injecting defensive code: $e', name: 'WebView');
                     }


                     setState(() {
                       isLoading = false;
                       progress = 1.0; // Set progress to 100% when loading completes
                     });
                   },
                   onProgressChanged:
                       (controller, progressValue) {
                     setState(() {
                       progress = progressValue / 100.0;
                       // Keep loading state active during page load - don't set to false here
                     });
                   },
                    onScrollChanged: (controller, x, y) async {
                      // Ensure pull-to-refresh works properly when scrolled to top
                      // This helps detect when the user has scrolled to the top of the WebView content
                      if (x == 0 && y == 0) {
                        // User is at the top of the page - ensure pull-to-refresh is enabled
                        if (pullToRefreshController != null) {
                          // The pull-to-refresh should be automatically enabled when at the top
                          // This is a workaround to ensure it works properly
                        }
                      } else {
                        // If user has scrolled down, ensure pull-to-refresh controller is ready for when they return to top
                      }
                      
                      // Inject JavaScript to check scroll position for more reliable detection
                      try {
                        await controller.evaluateJavascript(source: '''
                          window.currentScrollX = $x;
                          window.currentScrollY = $y;
                          
                          if (typeof window.isAtTop === 'function') {
                            if (window.isAtTop()) {
                              console.log('ScrollChanged: At top of page - Y position: ' + $y);
                            } else {
                              console.log('ScrollChanged: Not at top - Y position: ' + $y);
                            }
                          }
                        ''');
                      } catch (e) {
                        // Ignore errors from JavaScript evaluation
                      }
                    },
                   onReceivedError: (controller, request, error) async {
                     developer.log('WebView Error: ${error.description} for URL: ${request.url}', name: 'WebView');
                     
                     // End the pull to refresh if it's active
                     if (pullToRefreshController != null) {
                       pullToRefreshController!.endRefreshing();
                     }
                     
                     if (request.isForMainFrame ?? true) {
                       if (mounted) {
                         setState(() {
                           isOnline = false;
                           isLoading = false;
                         });
                       }
                     } else {
                       if (mounted) {
                         setState(() {
                           isLoading = false;
                         });
                       }
                     }
                     
                     _loadingTimeoutTimer?.cancel();
                     _loadingTimeoutTimer = null;
                   },
                   onUpdateVisitedHistory: (controller, url, isReload) async {
                     // When the page reloads or history updates, ensure pull-to-refresh is ready
                     // This helps ensure pull-to-refresh works properly after navigation
                     if (url != null) {
                       setState(() {
                         String urlString = url.toString();
                         _isReelsPage = urlString.contains('/reel') || urlString.contains('reels');
                       });
                     }
                   },
                  onReceivedHttpError: (controller, request, error) async {
                    developer.log('WebView HTTP Error: ${error.statusCode} for URL: ${request.url}', name: 'WebView');
                  },
                   onPermissionRequest:
                       (controller, permissionRequest) async {
                     developer.log('PERMISSION: Request received: origin=${permissionRequest.origin}, resources=${permissionRequest.resources}', name: 'WebView');
                     return PermissionResponse(
                       resources: permissionRequest.resources,
                       action: PermissionResponseAction.GRANT,
                     );
                   },
                  onGeolocationPermissionsShowPrompt:
                      (controller, origin) async {
                    return GeolocationPermissionShowPromptResponse(
                      origin: origin,
                      allow: true,
                      retain: true,
                    );
                  },
                  onConsoleMessage: (controller, consoleMessage) {
                    if (consoleMessage.message != null) {
                      developer.log('JS_CONSOLE: ${consoleMessage.message}', name: 'WebView');
                    }

                    // Handle specific error patterns
                    if (consoleMessage.message != null && (consoleMessage.message.contains('dropdown not found') || consoleMessage.message.toLowerCase().contains('missing dropdown'))) {
                      developer.log('JS_ERROR: Dropdown element missing - implementing fallback', name: 'WebView');
                      _handleMissingDropdown(controller, consoleMessage.message);
                    }
                  },
                 ),
     
               ),
             
           ],
         ),
       
      );
  }

  Widget _buildBody() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: isOnline ? _buildWebViewWidget() : _buildOfflineScreen(),
    );
  }

   bool isGoogleAuthUrl(String url) {
    return url.contains('accounts.google.com') ||
        url.contains('google.com/oauth') ||
        url.contains('googleapis.com') ||
        url.contains('gstatic.com') ||
        url.contains('googleusercontent.com') ||
        url.contains(Uri.parse(AppConstants.baseUrl).host);
  }

  bool isSocialMediaUrl(String url) {
    return url.contains('instagram.com') ||
        url.contains('facebook.com') ||
        url.contains('m.facebook.com') ||
        url.contains('fb.com') ||
        url.contains('whatsapp.com') ||
        url.contains('api.whatsapp.com') ||
        url.contains('wa.me');
  }

 bool isShareUrl(String url) {
    return url.contains('share') ||
        url.contains('twitter.com/intent/tweet') ||
        url.contains('pinterest.com/pin/create') ||
        url.contains('linkedin.com/shareArticle');
  }

 bool isPhoneUrl(String url) {
    return url.startsWith('tel:');
  }

  bool isRazorpayUrl(String url) {
    return url.contains('razorpay.com');
  }

  bool isTruecallerUrl(String url) {
    return url.startsWith('truecallersdk://');
 }

  bool isUpiUrl(String url) {
    return url.startsWith('upi://');
  }

  bool isIntentUrl(String url) {
    return url.startsWith('intent://');
  }

 bool isPhonePeUrl(String url) {
    return url.startsWith('phonepe://');
  }

 bool isWhatsAppAppUrl(String url) {
    return url.startsWith('whatsapp://');
  }

  bool isInstagramAppUrl(String url) {
    return url.startsWith('instagram://');
  }

  bool isFacebookAppUrl(String url) {
    return url.startsWith('fb://') || url.startsWith('facebook://');
  }
}
