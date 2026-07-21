import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'about_us_screen.dart';
import 'firebase_test_screen.dart';
import '../test_cloudinary_screen.dart';

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
          seedColor: const Color(0xFF40916C),
          primary: const Color(0xFF2D6A4F),
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
  late AnimationController _silkController;
  late AnimationController _logoController;

  int _taglineIndex = 0;
  final List<String> _taglines = [
    "Design Your Dream Outfit",
    "Shop Premium Fabrics",
    "AI Virtual Trial",
    "Connect With Tailors",
    "Custom Fashion Made Easy",
  ];
  Timer? _taglineTimer;

  final List<String> _images = [
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

  @override
  void initState() {
    super.initState();
    _silkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _taglineTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _taglineIndex = (_taglineIndex + 1) % _taglines.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _silkController.dispose();
    _logoController.dispose();
    _taglineTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF6FCF6),
      body: Stack(
        children: [
          // ─── Silk Background ───────────────────────────────────────────
          _buildSilkBackground(),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  _buildTopRow(),

                  const Spacer(flex: 1),

                  _buildHeroSection(screenHeight),

                  const Spacer(flex: 1),

                  // ─── Bended Image Scroll ────────────────────────────────
                  _buildBendedImageScroll(),

                  const Spacer(flex: 2),

                  // ─── Action Section (Specular Style) ────────────────────
                  _buildActionButtons(),

                  const SizedBox(height: 16),

                  _buildStakeholderChips(),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // Hidden Debug Icon
          Positioned(
            bottom: 10,
            left: 10,
            child: Opacity(
              opacity: 0.2,
              child: IconButton(
                icon: const Icon(Icons.settings_input_component, size: 14),
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

  Widget _buildSilkBackground() {
    return AnimatedBuilder(
      animation: _silkController,
      builder: (context, child) {
        return CustomPaint(
          painter: SilkPainter(
            animationValue: _silkController.value,
            color: const Color(0xFFBAE0D4),
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildTopRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ScaleTransition(
            scale: CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
            child: FadeTransition(
              opacity: _logoController,
              child: Image.asset('assets/images/transparent_logo.png', height: 44),
            ),
          ),
          _buildGlassIconButton(
            icon: Icons.cloud_upload_outlined,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TestCloudinaryScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(double screenHeight) {
    return Column(
      children: [
        Text(
          "Sketch2Stitch",
          style: TextStyle(
            fontSize: screenHeight < 700 ? 38 : 46,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1B4332),
            letterSpacing: -1.8,
            height: 1,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 24,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Text(
              _taglines[_taglineIndex],
              key: ValueKey<int>(_taglineIndex),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                color: Color(0xFF2D6A4F),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBendedImageScroll() {
    return SizedBox(
      height: 200,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            physics: const BouncingScrollPhysics(),
            itemCount: _images.length,
            itemBuilder: (context, index) {
              return Container(
                width: 150,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  image: DecorationImage(
                    image: AssetImage('assets/images/${_images[index]}'),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            top: -65,
            left: -50,
            right: -50,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFF6FCF6),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.elliptical(
                    MediaQuery.of(context).size.width + 100,
                    80,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -65,
            left: -50,
            right: -50,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFF6FCF6),
                borderRadius: BorderRadius.vertical(
                  top: Radius.elliptical(
                    MediaQuery.of(context).size.width + 100,
                    80,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SpecularButton(
          text: "Signup",
          baseColor: const Color(0xFF2D6A4F),
          lineColor: Colors.white,
          textColor: Colors.white,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
        ),
        const SizedBox(height: 14),
        SpecularButton(
          text: "Login",
          baseColor: Colors.white.withAlpha(100),
          lineColor: const Color(0xFF2D6A4F),
          textColor: const Color(0xFF1B4332),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
          blur: 10,
        ),
        const SizedBox(height: 14),
        SpecularButton(
          text: "About Us",
          baseColor: Colors.transparent,
          lineColor: const Color(0xFF40916C),
          textColor: const Color(0xFF1B4332),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutUsScreen())),
          height: 48,
        ),
      ],
    );
  }

  Widget _buildStakeholderChips() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStakeholderChip("Customer", Icons.auto_awesome_rounded),
        _buildStakeholderChip("Tailor", Icons.content_cut_rounded),
        _buildStakeholderChip("Retailer", Icons.storefront_rounded),
      ],
    );
  }

  Widget _buildStakeholderChip(String label, IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(130),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withAlpha(100), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: const Color(0xFF2D6A4F)),
              const SizedBox(width: 5),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1B4332))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton({required IconData icon, required VoidCallback onPressed}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(100),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withAlpha(150), width: 1),
          ),
          child: IconButton(
            icon: Icon(icon, color: const Color(0xFF2D6A4F), size: 22),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

class SpecularButton extends StatefulWidget {
  final String text;
  final Color baseColor;
  final Color lineColor;
  final Color textColor;
  final VoidCallback onTap;
  final double blur;
  final double height;

  const SpecularButton({
    super.key,
    required this.text,
    required this.baseColor,
    required this.lineColor,
    required this.textColor,
    required this.onTap,
    this.blur = 0,
    this.height = 58,
  });

  @override
  State<SpecularButton> createState() => _SpecularButtonState();
}

class _SpecularButtonState extends State<SpecularButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
          child: Container(
            width: double.infinity,
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.baseColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withAlpha(40), width: 1),
            ),
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: SpecularPainter(
                        animationValue: _controller.value,
                        lineColor: widget.lineColor,
                      ),
                      size: Size(double.infinity, widget.height),
                    );
                  },
                ),
                Center(
                  child: Text(
                    widget.text,
                    style: TextStyle(
                      color: widget.textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SpecularPainter extends CustomPainter {
  final double animationValue;
  final Color lineColor;

  SpecularPainter({required this.animationValue, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));
    
    // Specular shine movement simulation
    final double pos = -1.0 + (animationValue * 3.0);
    
    final Paint shinePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(pos - 0.2, -1.0),
        end: Alignment(pos + 0.2, 1.0),
        colors: [
          lineColor.withAlpha(0),
          lineColor.withAlpha(100),
          lineColor.withAlpha(200),
          lineColor.withAlpha(100),
          lineColor.withAlpha(0),
        ],
        stops: const [0.0, 0.45, 0.5, 0.55, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw rim shine
    canvas.drawRRect(rrect, shinePaint);
    
    // Gaussian-like soft glow behind the line
    final Paint glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(pos - 0.4, -1.0),
        end: Alignment(pos + 0.4, 1.0),
        colors: [
          lineColor.withAlpha(0),
          lineColor.withAlpha(30),
          lineColor.withAlpha(0),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      
    canvas.drawRRect(rrect, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SilkPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  SilkPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Background layer
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF6FCF6));

    // Multiple flowing "silk" paths
    for (int i = 0; i < 3; i++) {
      final path = Path();
      final double yBase = size.height * (0.3 + i * 0.25);
      
      path.moveTo(0, yBase);
      
      for (double x = 0; x <= size.width; x += 10) {
        final double relativeX = x / size.width;
        final double wave = math.sin(relativeX * 2 * math.pi + animationValue * 2 * math.pi + i * math.pi / 2);
        final double wave2 = math.cos(relativeX * 3 * math.pi - animationValue * math.pi);
        path.lineTo(x, yBase + wave * 40 + wave2 * 20);
      }
      
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
      
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withAlpha(50 + i * 40),
              color.withAlpha(10),
            ],
          ).createShader(Offset.zero & size)
          ..imageFilter = ImageFilter.blur(sigmaX: 50, sigmaY: 50),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
