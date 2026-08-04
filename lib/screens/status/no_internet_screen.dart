// lib/screens/status/no_internet_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/connectivity_service.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/glass_widgets.dart';

class NoInternetScreen extends StatelessWidget {
  final VoidCallback? onRetry; // ✅ Optionnel

  const NoInternetScreen({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
        final connectivity = context.watch<ConnectivityService>();
    final theme = context.watch<ThemeProvider>();
    final textColor = theme.textColor ?? Colors.black;
    final subTextColor = theme.subTextColor ?? Colors.grey;

        return GlassScaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.orange.withValues(alpha: 0.85),
                      Colors.deepOrange.withValues(alpha: 0.6),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 44,
                  color: Colors.white,
                ),
              ).animate().scale(
                    begin: const Offset(0.6, 0.6),
                    end: const Offset(1, 1),
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 20),
              Text(
                'Pas de connexion internet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vérifiez votre réseau et réessayez',
                style: TextStyle(
                  fontSize: 14,
                  color: subTextColor,
                ),
              ),
              const SizedBox(height: 32),
                            SizedBox(
                width: 200,
                child: GradientButton(
                  label: 'Réessayer',
                  icon: Icons.refresh_rounded,
                  height: 48,
                  onPressed: () {
                    if (onRetry != null) {
                      onRetry!();
                    } else {
                      // Logique par défaut : utiliser le service de connectivité
                      connectivity.retryConnection();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}