import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  final double rating;
  final double size;

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = index < rating.floor();
        final half = index == rating.floor() && rating - rating.floor() >= 0.5;
        return Icon(
          half ? Icons.star_half : (filled ? Icons.star : Icons.star_border),
          color: const Color(0xFFFDE807),
          size: size,
        );
      }),
    );
  }
}