// lib/widgets/connectivity_wrapper.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';
import '../screens/status/no_internet_screen.dart';

class ConnectivityWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback onRetry;

  const ConnectivityWrapper({
    super.key,
    required this.child,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityService>();

    // Sur le Web, on n'utilise pas la détection de connectivité
    if (kIsWeb) return child;

    if (!connectivity.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (connectivity.noInternet) {
      return NoInternetScreen(onRetry: onRetry);
    }

    return child;
  }
}