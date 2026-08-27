import 'package:flutter/material.dart';

/// Uses Google's own officially published "G" logo asset (the standard
/// asset Google provides for third-party "Sign in with Google" buttons)
/// instead of hand-painting the mark -- the painted version didn't render
/// cleanly, and Google's brand guidelines expect the exact asset anyway.
class GoogleLogo extends StatelessWidget {
  final double size;
  const GoogleLogo({super.key, this.size = 20});

  static const _officialAssetUrl =
      'https://developers.google.com/identity/images/g-logo.png';

  @override
  Widget build(BuildContext context) {
    return Image.network(
      _officialAssetUrl,
      width: size,
      height: size,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.g_mobiledata,
        size: size * 1.4,
        color: const Color(0xFF4285F4),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          width: size,
          height: size,
          child: const Center(
            child: SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
          ),
        );
      },
    );
  }
}