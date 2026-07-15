// lib/widgets/connectivity_wrapper.dart
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../screens/status/no_internet_screen.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onRetry;

  const ConnectivityWrapper({
    super.key,
    required this.child,
    this.onRetry,
  });

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  ConnectivityResult _connectivityResult = ConnectivityResult.none;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _listenConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _connectivityResult = result;
      _isChecking = false;
    });
  }

  void _listenConnectivity() {
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _connectivityResult = result;
        if (result != ConnectivityResult.none && widget.onRetry != null) {
          widget.onRetry!();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_connectivityResult == ConnectivityResult.none) {
      return NoInternetScreen(
        onRetry: () {
          setState(() {});
          if (widget.onRetry != null) {
            widget.onRetry!();
          }
        },
      );
    }

    return widget.child;
  }
}