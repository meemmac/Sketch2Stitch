import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'about_us_screen.dart';
import 'firebase_test_screen.dart';

void main() {
  runApp(const Sketch2StitchApp());
}

class Sketch2StitchApp extends StatelessWidget {
  const Sketch2StitchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sketch2Stitch',
      theme: ThemeData(
        fontFamily: 'Roboto',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          primary: const Color(0xFF2E7D32),
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late AnimationController _particleController;
  late AnimationController _floatController;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _particleController.dispose();
    _floatController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F1), // Ultra-premium soft green
      body: Stack(
        children: [
          // 🌊 Floating fabric-like particles in background
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                painter: FabricParticlePainter(_particleController.value),
                size: Size.infinite,
              );
            },
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🏷 Top Left Logo
                  Padding(
                    padding: const EdgeInsets.only(left: 20, top: 20),
                    child: Image.asset(
                      'assets/images/transparent_logo.png',
                      height: 55,
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ✍️ Main Tagline Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Sketch2Stitch",
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: Colors.green.shade900,
                            letterSpacing: -1.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          "Design Your Dress, Buy Materials, and Get It Stitched in One Place",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.green.shade800.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 🃏 Stakeholder Cards with Glassmorphism & Parallax
                  SizedBox(
                    height: 260,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildStakeholderCard(
                          "Tailor",
                          "Access digital measurements, manage orders, and showcase your craftsmanship.",
                          Icons.content_cut_rounded,
                          0,
                        ),
                        _buildStakeholderCard(
                          "Customer",
                          "Customize designs, trial with AI, purchase premium fabrics, and connect with tailors.",
                          Icons.auto_awesome_rounded,
                          1,
                        ),
                        _buildStakeholderCard(
                          "Retailer",
                          "Expand your reach by listing high-quality fabrics and fashion accessories.",
                          Icons.storefront_rounded,
                          2,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 🖼 Bended Horizontal Image Scroll
                  _buildBendedImageScroll(),

                  const SizedBox(height: 40),

                  // 🔘 Glowing Login / Signup Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildGlowButton(
                            "Login",
                            Colors.white,
                            Colors.green.shade900,
                            false,
                            () {},
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildGlowButton(
                            "Signup",
                            Colors.green.shade800,
                            Colors.white,
                            true,
                            () {},
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 50),

                  // 🛠 Help Getting Started Section
                  _buildHelpSection(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          // Subtle Debug/Test Access
          Positioned(
            right: 10,
            top: 10,
            child: Opacity(
              opacity: 0.3,
              child: IconButton(
                icon: const Icon(Icons.settings_input_component, size: 18),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FirebaseTestScreen()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBendedImageScroll() {
    final List<String> images = [
      'crochet.jpg',
      'embroidery.jpg',
      'fab.jpg',
      'fab2.jpg',
      'fabrics_rolled.jpg',
      'gorgeous.jpg',
      'lace.jpg',
      'saree.jpg',
      'silk.jpg',
      'tassel.jpg',
      'textile.jpg',
    ];

    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          // The actual scrolling list
          ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: images.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              return Container(
                width: 150,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  image: DecorationImage(
                    image: AssetImage('assets/images/${images[index]}'),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
              );
            },
          ),
          // Top Ellipse to create "bend"
          Positioned(
            top: -65,
            left: -50,
            right: -50,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F9F1), // Background color
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.elliptical(MediaQuery.of(context).size.width + 100, 80),
                ),
              ),
            ),
          ),
          // Bottom Ellipse to create "bend"
          Positioned(
            bottom: -65,
            left: -50,
            right: -50,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F9F1), // Background color
                borderRadius: BorderRadius.vertical(
                  top: Radius.elliptical(MediaQuery.of(context).size.width + 100, 80),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStakeholderCard(String title, String desc, IconData icon, int index) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        // Parallax / Gentle Drifting Effect
        double verticalOffset = math.sin(_floatController.value * 2 * math.pi + (index * 1.5)) * 12;
        return Transform.translate(
          offset: Offset(0, verticalOffset),
          child: Container(
            width: 280,
            margin: const EdgeInsets.only(right: 20, top: 10, bottom: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.shade900.withOpacity(0.04),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: Colors.green.shade800, size: 30),
                      ),
                      const Spacer(),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        desc,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87.withOpacity(0.7),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlowButton(String text, Color bgColor, Color textColor, bool hasGlow, VoidCallback onTap) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: hasGlow ? [
              BoxShadow(
                color: Colors.green.shade500.withOpacity(0.4 * _glowController.value),
                blurRadius: 20 * _glowController.value,
                spreadRadius: 2 * _glowController.value,
              )
            ] : [],
          ),
          child: Material(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            elevation: hasGlow ? 0 : 4,
            shadowColor: Colors.black12,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: bgColor == Colors.white 
                      ? Border.all(color: Colors.green.shade100, width: 1.5) 
                      : null,
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHelpSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "HELP GETTING STARTED",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Colors.green.shade900.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 25),
          _buildHelpItem(
            "Design and Measurement",
            "The design feature provides a platform where users can design their ideas or upload custom reference images.Customers save and update body measurements in inches. Each field has a guide button with step-by-step measuring instructions. Saved measurements are used automatically in the Cart and Virtual Trial",
            Icons.brush_rounded,
          ),
          const SizedBox(height: 25),
          _buildHelpItem(
            "Virtual Trial",
            "This feature lets customers upload their photo (or use a default mannequin) and preview how their chosen outfit will look before placing an order. It also displays estimated fabric requirements in gaj and inches, allows users to add style and fit notes, and provides a Go to Cart option to proceed with the purchase.",
            Icons.checkroom_rounded,
          ),
          const SizedBox(height: 25),
          _buildHelpItem(
            "About Us",
            "Discover the story behind Sketch2Stitch and our vision for the future of custom fashion.",
            Icons.info_outline_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutUsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String desc, IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                  )
                ],
              ),
              child: Icon(icon, color: Colors.green.shade700, size: 26),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FabricParticlePainter extends CustomPainter {
  final double animationValue;

  FabricParticlePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.shade200.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final random = math.Random(555);

    for (int i = 0; i < 15; i++) {
      // Slow, organic movement
      double x = (random.nextDouble() * size.width + (animationValue * 40 * (random.nextDouble() + 0.5))) % size.width;
      double y = (random.nextDouble() * size.height + (math.sin(animationValue * math.pi * 2 + i) * 20)) % size.height;
      
      double radius = 50 + random.nextDouble() * 80;
      
      final path = Path();
      int points = 10;
      for (int j = 0; j < points; j++) {
        double angle = (j * 2 * math.pi) / points;
        // Wavy edges for fabric feel
        double wave = 0.2 * math.sin(animationValue * math.pi * 2 + j * 1.5);
        double r = radius * (0.8 + wave);
        double px = x + math.cos(angle) * r;
        double py = y + math.sin(angle) * r;
        if (j == 0) path.moveTo(px, py);
        else path.lineTo(px, py);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
