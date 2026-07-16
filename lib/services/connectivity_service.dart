import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  
  // 1. On utilise une liste pour être conforme aux nouvelles versions du plugin
  List<ConnectivityResult> _connectivityResults = [ConnectivityResult.none];
  bool _hasInternet = false;

  ConnectivityService() {
    _initConnectivity();
    _listenConnectivity();
  }

  // Getters adaptés
  List<ConnectivityResult> get connectivityResults => _connectivityResults;
  bool get hasInternet => _hasInternet;
  bool get noInternet => !_hasInternet;

  Future<void> _initConnectivity() async {
    try {
      final List<ConnectivityResult> results = (await _connectivity.checkConnectivity()) as List<ConnectivityResult>;
      _updateState(results);
    } catch (e) {
      _hasInternet = false;
      notifyListeners();
    }
  }

  void _listenConnectivity() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateState(results);
    } as void Function(ConnectivityResult event)?);
  }

  void _updateState(List<ConnectivityResult> results) {
    _connectivityResults = results;
    
    // 2. On vérifie si la liste contient autre chose que 'none'
    // Si la liste contient ConnectivityResult.none, on n'est pas connecté
    _hasInternet = !results.contains(ConnectivityResult.none);
    
    notifyListeners();
  }

  Future<bool> checkConnection() async {
    final ConnectivityResult results = await _connectivity.checkConnectivity();
    _updateState(results as List<ConnectivityResult>);
    return _hasInternet;
  }

  Future<void> retryConnection() async {
    await checkConnection();
  }
}