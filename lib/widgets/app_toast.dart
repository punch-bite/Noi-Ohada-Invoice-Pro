// lib/widgets/app_toast.dart
//
// 🍞 Toast global : permet d'afficher un SnackBar (toast) depuis n'importe
// où (services, stream en temps réel…), sans BuildContext. La clé est passée
// au `scaffoldMessengerKey` du MaterialApp dans main.dart.
import 'package:flutter/material.dart';

/// Clé globale du ScaffoldMessenger pour les toasts.
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Affiche un toast (SnackBar flottant) au-dessus de toute l'application.
void showAppToast(
  String message, {
  Color? background,
  Duration duration = const Duration(seconds: 4),
}) {
  final messenger = appScaffoldMessengerKey.currentState;
  if (messenger == null) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: duration,
        backgroundColor: background ?? const Color(0xFF4338CA),
        content: Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
}
