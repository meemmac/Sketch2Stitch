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

class AppleCardClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;

    // We create a smooth arc at the top and bottom
    // The curve starts from the sides and peaks in the middle
    const double curveHeight = 35.0;

    path.moveTo(0, curveHeight);
    
    // Top Arc
    path.quadraticBezierTo(
      width / 2, -curveHeight / 2, 
      width, curveHeight
    );
    
    path.lineTo(width, height - curveHeight);
    
    // Bottom Arc
    path.quadraticBezierTo(
      width / 2, height + curveHeight / 2, 
      0, height - curveHeight
    );
    
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
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
  late PageController _pageController;

  int _taglineIndex = 0;
  final List<String> _taglines = [
    "Design Your Dream Outfit",
    "Shop Premium Fabrics",
    "AI Virtual Trial",
    "Connect With Tailors",
    "Custom Fashion Made Easy",
  ];
  Timer? _taglineTimer;
  Timer? _slideshowTimer;

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

    _pageController = PageController(viewportFraction: 0.5, initialPage: 1000);

    _taglineTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _taglineIndex = (_taglineIndex + 1) % _taglines.length;
        });
      }
    });

    _slideshowTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && _pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _silkController.dispose();
    _logoController.dispose();
    _pageController.dispose();
    _taglineTimer?.cancel();
    _slideshowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF6FCF6),
      body: Stack(
        children: [
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

                  _buildBendedSlideshow(),

                  const Spacer(flex: 2),

                  _buildActionButtons(),

                  const SizedBox(height: 16),

                  _buildStakeholderChips(),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

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
    return FadeTransition(
      opacity: _logoController,
      child: Column(
        children: [
          SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
                .animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic)),
            child: Text(
              "Sketch2Stitch",
              style: TextStyle(
                fontSize: screenHeight < 700 ? 38 : 46,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1B4332),
                letterSpacing: -1.8,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 32,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Text(
                _taglines[_taglineIndex],
                key: ValueKey<int>(_taglineIndex),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xFF0F2E20),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBendedSlideshow() {
    return SizedBox(
      height: 200,
      child: ClipPath(
        clipper: AppleCardClipper(),
        child: PageView.builder(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            final imgIndex = index % _images.length;
            return AnimatedBuilder(
              animation: _pageController,
              builder: (context, child) {
                double value = 1.0;
                if (_pageController.position.haveDimensions) {
                  value = _pageController.page! - index;
                  value = (1 - (value.abs() * 0.2)).clamp(0.0, 1.0);
                }
                return Center(
                  child: Transform.scale(
                    scale: Curves.easeOut.transform(value),
                    child: Container(
                      width: 160,
                      height: 180,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        image: DecorationImage(
                          image: AssetImage('assets/images/${_images[imgIndex]}'),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
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
          height: 50, // Match LoginScreen
        ),
        const SizedBox(height: 14),
        SpecularButton(
          text: "Login",
          baseColor: Colors.white.withAlpha(100),
          lineColor: const Color(0xFF2D6A4F),
          textColor: const Color(0xFF1B4332),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
          blur: 10,
          height: 50, // Match LoginScreen
        ),
        const SizedBox(height: 14),
        SpecularButton(
          text: "About Us",
          baseColor: Colors.transparent,
          lineColor: const Color(0xFF40916C),
          textColor: const Color(0xFF1B4332),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutUsScreen())),
          height: 50, // Match LoginScreen
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
        borderRadius: BorderRadius.circular(14), // Match LoginScreen
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
          child: Container(
            width: double.infinity,
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.baseColor,
              borderRadius: BorderRadius.circular(14), // Match LoginScreen
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
                      fontSize: 16, // Match LoginScreen
                      fontWeight: FontWeight.w600, // Match LoginScreen
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
    final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14)); // Match LoginScreen radius
    
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

    canvas.drawRRect(rrect, shinePaint);
    
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
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF6FCF6));

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
