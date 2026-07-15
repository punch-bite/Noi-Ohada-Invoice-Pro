// lib/services/connectivity_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  ConnectivityResult _connectivityResult = ConnectivityResult.none;
  bool _hasInternet = false;

  ConnectivityService() {
    _initConnectivity();
    _listenConnectivity();
  }

  ConnectivityResult get connectivityResult => _connectivityResult;
  bool get hasInternet => _hasInternet;
  bool get noInternet => !_hasInternet;

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateState(result);
    } catch (e) {
      _hasInternet = false;
      notifyListeners();
    }
  }

  void _listenConnectivity() {
    _connectivity.onConnectivityChanged.listen((result) {
      _updateState(result);
    });
  }

  void _updateState(ConnectivityResult result) {
    _connectivityResult = result;
    _hasInternet = result != ConnectivityResult.none;
    notifyListeners();
  }

  Future<bool> checkConnection() async {
    final result = await _connectivity.checkConnectivity();
    _updateState(result);
    return _hasInternet;
  }

  Future<void> retryConnection() async {
    await checkConnection();
    notifyListeners();
  }
}