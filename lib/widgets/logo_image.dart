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
          return _buildImageWithGlassEffect(
            Image.memory(
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

    // Asset image
    if (path!.startsWith('assets/')) {
      return _buildImageWithGlassEffect(
        Image.asset(
          path!,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        ),
      );
    }

    // Sinon, c'est un chemin de fichier (local)
    if (!kIsWeb) {
      try {
        return _buildImageWithGlassEffect(
          Image.file(
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

  Widget _buildImageWithGlassEffect(Widget image) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.2 - 2),
        child: image,
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[300]!,
            Colors.grey[400]!,
          ],
        ),
        borderRadius: BorderRadius.circular(width * 0.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Icon(
        Icons.business,
        size: width * 0.45,
        color: Colors.white,
      ),
    );
  }
}