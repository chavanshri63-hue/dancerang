import 'package:flutter/material.dart';

class BackgroundImageWidget extends StatelessWidget {
  final String? imageUrl;
  final String defaultImageUrl;
  final Widget child;
  final BoxFit fit;

  const BackgroundImageWidget({
    super.key,
    required this.imageUrl,
    required this.defaultImageUrl,
    required this.child,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final String? src = (imageUrl != null && imageUrl!.trim().isNotEmpty)
        ? imageUrl!.trim()
        : (defaultImageUrl.trim().isNotEmpty ? defaultImageUrl.trim() : null);

    // Validate URL format
    final bool isValidUrl = src != null && 
        src.isNotEmpty && 
        (src.startsWith('http://') || src.startsWith('https://'));

    return Container(
      decoration: !isValidUrl
          ? null
          : BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(src),
                fit: fit,
                onError: (exception, stackTrace) {
                },
              ),
            ),
      child: child,
    );
  }
}
