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
  late AnimationController _auroraController;
  late AnimationController _logoController;
  late PageController _pageController;

  int _taglineIndex = 0;
  final List<String> _taglines = [
    "Design Your Dream Outfit",
    "Shop Premium Fabrics And Elements",
    "Preview Your Design With Virtual Trial",
    "Connect With Skilled Tailors",
    "Save Measurement in Our App",
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
    // Slow aurora animation: 20 seconds loop
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _pageController = PageController(viewportFraction: 0.5, initialPage: 1000);

    _taglineTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
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
    _auroraController.dispose();
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
          _buildAuroraBackground(),

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

  Widget _buildAuroraBackground() {
    return AnimatedBuilder(
      animation: _auroraController,
      builder: (context, child) {
        return CustomPaint(
          painter: AuroraPainter(
            animationValue: _auroraController.value,
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
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withAlpha(80),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Image.asset('assets/images/transparent_logo.png', height: 44),
              ),
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
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Soft glow behind title
                Container(
                  width: 250,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFBAE0D4).withAlpha(40),
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFBAE0D4).withAlpha(30),
                        blurRadius: 60,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
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
              ],
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
                        borderRadius: BorderRadius.circular(32), // Slightly larger radius
                        image: DecorationImage(
                          image: AssetImage('assets/images/${_images[imgIndex]}'),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withAlpha(10),
                            BlendMode.darken,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2), // Stronger soft shadow
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withAlpha(40),
                          width: 1,
                        ),
                      ),
                      // Faint inner highlight
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withAlpha(20),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.4],
                          ),
                        ),
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
          height: 50,
        ),
        const SizedBox(height: 14),
        SpecularButton(
          text: "Login",
          baseColor: Colors.white.withAlpha(40), // More transparent glass
          lineColor: Colors.white.withAlpha(180),
          textColor: const Color(0xFF1B4332),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
          blur: 15, // Better blur
          height: 50,
        ),
        const SizedBox(height: 14),
        SpecularButton(
          text: "About Us",
          baseColor: Colors.transparent,
          lineColor: Colors.white.withAlpha(150),
          textColor: const Color(0xFF1B4332),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutUsScreen())),
          height: 50,
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
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Realism
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(80), // Premium transparency
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withAlpha(60), width: 0.8), // Softer border
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: const Color(0xFF2D6A4F)),
              const SizedBox(width: 5),
              Text(
                label, 
                style: const TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.bold, 
                  color: Color(0xFF1B4332),
                ),
              ),
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
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(80),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withAlpha(60), width: 0.8),
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
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
          child: Container(
            width: double.infinity,
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.baseColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withAlpha(30), width: 1), // Softer border
            ),
            child: Stack(
              children: [
                // Faint inner highlight for glass buttons
                if (widget.baseColor.alpha < 255)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withAlpha(40),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5],
                      ),
                    ),
                  ),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
    final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    
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

class AuroraPainter extends CustomPainter {
  final double animationValue;

  AuroraPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint();

    // Subtle base background color
    canvas.drawRect(rect, paint..color = const Color(0xFFF6FCF6));

    final double time = animationValue * 2 * math.pi;

    // We draw elongated "ribbons" instead of simple circles.
    // Each ribbon has its own animation and color profile.
    
    // Ribbon 1: Emerald (Primary Aurora)
    _drawRibbon(
      canvas,
      size,
      const Color(0xFFBAE0D4).withAlpha(180),
      Offset(size.width * 0.2, size.height * 0.3),
      Offset(size.width * 0.8, size.height * 0.5),
      math.sin(time) * 40,
      120.0,
    );

    // Ribbon 2: Mint/Light Green
    _drawRibbon(
      canvas,
      size,
      const Color(0xFFD8F3DC).withAlpha(160),
      Offset(size.width * 0.1, size.height * 0.6),
      Offset(size.width * 0.9, size.height * 0.4),
      math.cos(time * 0.7) * 50,
      100.0,
    );

    // Ribbon 3: Teal Accent
    _drawRibbon(
      canvas,
      size,
      const Color(0xFF95D5B2).withAlpha(140),
      Offset(size.width * 0.4, size.height * 0.1),
      Offset(size.width * 0.6, size.height * 0.9),
      math.sin(time * 0.5) * 60,
      150.0,
    );

    // Ribbon 4: Soft Cyan
    _drawRibbon(
      canvas,
      size,
      const Color(0xFFA8E6CF).withAlpha(120),
      Offset(size.width * 0.8, size.height * 0.2),
      Offset(size.width * 0.2, size.height * 0.8),
      math.cos(time * 0.3) * 30,
      80.0,
    );
  }

  void _drawRibbon(
    Canvas canvas,
    Size size,
    Color color,
    Offset start,
    Offset end,
    double offset,
    double blurSigma,
  ) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..imageFilter = ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma);

    final Path path = Path();
    path.moveTo(start.dx + offset, start.dy);
    path.quadraticBezierTo(
      size.width / 2 + offset * 1.5,
      size.height / 2 + offset,
      end.dx + offset,
      end.dy,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
