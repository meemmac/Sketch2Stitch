import 'dart:ui';
import 'package:flutter/material.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Premium gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF4FAF0),
                  Color(0xFFE4F2DC),
                  Color(0xFFD6E9CC),
                ],
              ),
            ),
          ),

          // Decorative glow - top
          Positioned(
            top: -80,
            right: -70,
            child: _glowCircle(
              240,
              const Color(0xFF81C784).withValues(alpha: 0.35),
            ),
          ),

          // Decorative glow - middle
          Positioned(
            top: 380,
            left: -100,
            child: _glowCircle(
              250,
              const Color(0xFFA5D6A7).withValues(alpha: 0.30),
            ),
          ),

          // Decorative glow - bottom
          Positioned(
            bottom: -100,
            right: -80,
            child: _glowCircle(
              280,
              const Color(0xFF66BB6A).withValues(alpha: 0.20),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 35),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _glassButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => Navigator.pop(context),
                        ),
                        const Text(
                          'ABOUT US',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3,
                            color: Color(0xFF37643B),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // Hero image
                    // Hero image with centered logo
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 245,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2E7D32)
                                    .withValues(alpha: 0.18),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(
                                  'assets/images/Aboutus.png',
                                  fit: BoxFit.cover,
                                ),

                                // Premium green overlay
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.05),
                                        const Color(0xFF1B5E20)
                                            .withValues(alpha: 0.45),
                                      ],
                                    ),
                                  ),
                                ),

                                // Shine effect
                                Positioned(
                                  top: -80,
                                  left: -60,
                                  child: Transform.rotate(
                                    angle: -0.5,
                                    child: Container(
                                      width: 100,
                                      height: 400,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withValues(alpha: 0.0),
                                            Colors.white.withValues(alpha: 0.25),
                                            Colors.white.withValues(alpha: 0.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Centered transparent logo
                        Image.asset(
                          'assets/images/transparent_logo.png',
                          height: 115,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),

                    const SizedBox(height: 35),

                    // Heading
                    const Center(
                      child: Column(
                        children: [
                          Text(
                            'Designed by You.',
                            style: TextStyle(
                              fontSize: 29,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E3D22),
                              letterSpacing: -0.8,
                            ),
                          ),
                          Text(
                            'Stitched for You.',
                            style: TextStyle(
                              fontSize: 29,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4C8C4A),
                              letterSpacing: -0.8,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Liquid glass description
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 20,
                          sigmaY: 20,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.75),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2E7D32)
                                    .withValues(alpha: 0.08),
                                blurRadius: 25,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Sketch2Stitch is a digital tailoring platform '
                                'that connects customers with skilled tailors and '
                                'trusted fabric retailers, all in one seamless '
                                'experience.\n\n'
                                'From choosing fabrics and designs to taking smart '
                                'measurements and doorstep delivery, Sketch2Stitch '
                                'makes custom clothing simple, personal, and '
                                'accessible.\n\n'
                                'Customers can design outfits their way, tailors '
                                'can grow their business with verified profiles '
                                'and smart tools, and retailers can showcase '
                                'premium fabrics to the right audience.',
                            textAlign: TextAlign.justify,
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF344536),
                              height: 1.7,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Feature glass chips
                    Row(
                      children: [
                        Expanded(
                          child: _featureGlass(
                            Icons.draw_rounded,
                            'Design',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _featureGlass(
                            Icons.content_cut_rounded,
                            'Stitch',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _featureGlass(
                            Icons.local_shipping_outlined,
                            'Deliver',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    const Center(
                      child: Text(
                        'One platform  •  One workflow  •  Perfectly stitched',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF608064),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _glowCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 80,
            spreadRadius: 30,
          ),
        ],
      ),
    );
  }

  static Widget _glassButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 15,
            sigmaY: 15,
          ),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: const Color(0xFF315D35),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _featureGlass(
      IconData icon,
      String title,
      ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 15,
          sigmaY: 15,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: const Color(0xFF4C8C4A),
                size: 26,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF315D35),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}