import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final InternetConnection _internetConnection = InternetConnection();

  StreamController<bool>? _statusController;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<InternetStatus>? _internetSubscription;
  bool _lastStatus = true;

  Stream<bool> get onInternetStatusChanged {
    if (_statusController == null) {
      _statusController = StreamController<bool>.broadcast(
        onListen: _startListening,
        onCancel: _stopListening,
      );
    }
    return _statusController!.stream;
  }

  Future<bool> checkInternet() async {
    try {
      // 1. Check local interface status first
      final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
      if (results.contains(ConnectivityResult.none)) {
        return false;
      }
      // 2. Perform actual host lookup verification
      final bool hasAccess = await _internetConnection.hasInternetAccess;
      _lastStatus = hasAccess;
      return hasAccess;
    } catch (e) {
      debugPrint("ERROR checkInternet: $e");
      return false;
    }
  }

  void _startListening() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) async {
      if (results.contains(ConnectivityResult.none)) {
        // Delay before notifying offline to avoid brief connectivity flashes
        await Future.delayed(const Duration(seconds: 2));
        final bool stillHasAccess = await _internetConnection.hasInternetAccess;
        _notify(stillHasAccess);
      } else {
        // When connectivity is present, verify actual internet access
        final bool hasAccess = await _internetConnection.hasInternetAccess;
        _notify(hasAccess);
      }
    });

    _internetSubscription = _internetConnection.onStatusChange.listen((status) {
      final bool hasAccess = (status == InternetStatus.connected);
      _notify(hasAccess);
    });
  }

  void _notify(bool hasAccess) {
    if (_lastStatus != hasAccess) {
      _lastStatus = hasAccess;
      _statusController?.add(hasAccess);
    }
  }

  void _stopListening() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _internetSubscription?.cancel();
    _internetSubscription = null;
    _statusController?.close();
    _statusController = null;
  }
}
