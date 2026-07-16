// lib/services/connectivity_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  List<ConnectivityResult> _connectivityResults = [ConnectivityResult.none];
  bool _hasInternet = false;
  bool _isInitialized = false;

  ConnectivityService() {
    _initConnectivity();
    _listenConnectivity();
  }

  bool get hasInternet => _hasInternet;
  bool get noInternet => !_hasInternet;
  bool get isInitialized => _isInitialized;

  Future<void> _initConnectivity() async {
    try {
      if (kIsWeb) {
        // Sur le Web, on considère qu'Internet est disponible par défaut
        _updateState([ConnectivityResult.wifi]);
        _isInitialized = true;
        return;
      }
      final results = await _connectivity.checkConnectivity();
      _updateState(results);
      _isInitialized = true;
    } catch (e) {
      debugPrint("❌ Erreur init connectivité : $e");
      _updateState([ConnectivityResult.wifi]); // fallback
      _isInitialized = true;
    }
  }

  void _listenConnectivity() {
    if (kIsWeb) return;
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) => _updateState(results),
      onError: (error) {
        debugPrint("❌ Erreur écoute connectivité : $error");
        _updateState([ConnectivityResult.none]);
      },
    );
  }

  void _updateState(List<ConnectivityResult> results) {
    _connectivityResults = results;
    final previous = _hasInternet;
    _hasInternet = !results.contains(ConnectivityResult.none);
    if (previous != _hasInternet) {
      debugPrint("🌐 Connectivité : ${_hasInternet ? 'Connecté' : 'Déconnecté'}");
      notifyListeners();
    }
  }

  Future<bool> checkConnection() async {
    if (kIsWeb) return true;
    try {
      final results = await _connectivity.checkConnectivity();
      _updateState(results);
    } catch (_) {
      _updateState([ConnectivityResult.none]);
    }
    return _hasInternet;
  }

  Future<void> retryConnection() async {
    await checkConnection();
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}