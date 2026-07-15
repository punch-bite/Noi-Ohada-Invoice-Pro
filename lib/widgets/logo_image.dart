// lib/widgets/logo_image.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LogoImage extends StatelessWidget {
  final String? path;
  final double width;
  final double height;
  final BoxFit fit;

  const LogoImage({
    super.key,
    this.path,
    this.width = 80,
    this.height = 80,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (path == null || path!.isEmpty) {
      return _buildPlaceholder();
    }

    // Détecter si c'est une data URI (base64)
    if (path!.startsWith('data:image')) {
      try {
        final parts = path!.split(',');
        if (parts.length == 2) {
          final base64String = parts[1];
          final bytes = base64Decode(base64String);
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (_, __, ___) => _buildPlaceholder(),
            ),
          );
        }
      } catch (_) {
        return _buildPlaceholder();
      }
    }

    // Sinon, c'est un chemin de fichier (local)
    if (!kIsWeb) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(path!),
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          ),
        );
      } catch (_) {
        return _buildPlaceholder();
      }
    }

    // Sur le Web, si ce n'est pas une data URI, on affiche le placeholder
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Icon(
        Icons.business,
        size: width * 0.5,
        color: Colors.grey[600],
      ),
    );
  }
}