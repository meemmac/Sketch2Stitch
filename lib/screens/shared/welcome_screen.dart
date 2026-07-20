import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'about_us_screen.dart';
import 'firebase_test_screen.dart';
import '../customer/browsing/browse_shell.dart';
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
  late AnimationController _auroraController;
  late AnimationController _logoController;
  late AnimationController _floatController;

  int _taglineIndex = 0;
  final List<String> _taglines = [
    "Design Your Dream Outfit",
    "Shop Premium Fabrics",
    "AI Virtual Trial",
    "Connect With Tailors",
    "Custom Fashion Made Easy",
  ];
  Timer? _taglineTimer;

  @override
  void initState() {
    super.initState();
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _taglineTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _taglineIndex = (_taglineIndex + 1) % _taglines.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _auroraController.dispose();
    _logoController.dispose();
    _floatController.dispose();
    _taglineTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FCF6),
      body: Stack(
        children: [
          // ─── Aurora Background ──────────────────────────────────────────
          _buildAuroraBackground(),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  // ─── Top Row ────────────────────────────────────────────────
                  _buildTopRow(),

                  const Spacer(flex: 1),

                  // ─── Hero Section (Title + Tagline) ─────────────────────────
                  _buildHeroSection(),

                  const SizedBox(height: 20),

                  // ─── Fashion Collage ────────────────────────────────────────
                  _buildFashionCollage(),

                  const Spacer(flex: 2),

                  // ─── Action Section ─────────────────────────────────────────
                  _buildActionButtons(),

                  const SizedBox(height: 16),

                  // ─── Stakeholder Chips ──────────────────────────────────────
                  _buildStakeholderChips(),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // ─── Hidden Debug Icon ──────────────────────────────────────────
          Positioned(
            bottom: 10,
            left: 10,
            child: Opacity(
              opacity: 0.2,
              child: IconButton(
                icon: const Icon(Icons.settings_input_component, size: 16),
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
        return Stack(
          children: [
            _buildAuroraBlob(
              color: const Color(0xFFD8F3DC).withAlpha(150),
              size: 400,
              offset: Offset(
                math.sin(_auroraController.value * 2 * math.pi) * 50 - 50,
                math.cos(_auroraController.value * 2 * math.pi) * 50 + 100,
              ),
            ),
            _buildAuroraBlob(
              color: const Color(0xFFB7E4C7).withAlpha(120),
              size: 500,
              offset: Offset(
                math.cos(_auroraController.value * 2 * math.pi) * 80 + 150,
                math.sin(_auroraController.value * 2 * math.pi) * 80 + 300,
              ),
            ),
            _buildAuroraBlob(
              color: const Color(0xFF95D5B2).withAlpha(100),
              size: 450,
              offset: Offset(
                math.sin(_auroraController.value * 2 * math.pi) * 100 + 200,
                -100,
              ),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAuroraBlob({required Color color, required double size, required Offset offset}) {
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withAlpha(0)],
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ScaleTransition(
            scale: CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
            child: FadeTransition(
              opacity: _logoController,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF40916C).withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Image.asset(
                  'assets/images/transparent_logo.png',
                  height: 50,
                ),
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

  Widget _buildHeroSection() {
    return Column(
      children: [
        const Text(
          "Sketch2Stitch",
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1B4332),
            letterSpacing: -2,
            height: 1,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 24,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.5),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              _taglines[_taglineIndex],
              key: ValueKey<int>(_taglineIndex),
              style: const TextStyle(
                fontSize: 18,
                color: Color(0xFF2D6A4F),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFashionCollage() {
    return SizedBox(
      height: 320,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildCollageItem('crochet.jpg', -15, -100, -80, 0.9),
          _buildCollageItem('embroidery.jpg', 10, 80, -100, 1.1),
          _buildCollageItem('lace.jpg', -5, 120, 20, 1.0),
          _buildCollageItem('silk.jpg', 8, -120, 60, 1.2),
          _buildCollageItem('saree.jpg', -12, 40, 140, 0.8),
          _buildCollageItem('textile.jpg', 5, -60, -160, 1.0),
          _buildCollageItem('tassel.jpg', 15, 150, -180, 0.7),
          // Main center image
          _buildCollageItem('fab.jpg', 0, 0, 10, 1.4, isCenter: true),
        ],
      ),
    );
  }

  Widget _buildCollageItem(String asset, double rotation, double x, double y, double scale, {bool isCenter = false}) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        double floatY = math.sin(_floatController.value * 2 * math.pi + (x.abs() * 0.01)) * 10;
        return Transform.translate(
          offset: Offset(x, y + floatY),
          child: Transform.rotate(
            angle: rotation * math.pi / 180,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: isCenter ? 140 : 100,
                height: isCenter ? 180 : 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  image: DecorationImage(
                    image: AssetImage('assets/images/$asset'),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                  border: Border.all(color: Colors.white.withAlpha(180), width: 2),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildPrimaryButton(
          "Signup",
          const Color(0xFF40916C),
          Colors.white,
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
          hasGlow: true,
        ),
        const SizedBox(height: 16),
        _buildGlassButton(
          "Login",
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutUsScreen())),
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: const Text(
            "About Us",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF1B4332)),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(String text, Color bg, Color textColor, VoidCallback onTap, {bool hasGlow = false}) {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: hasGlow ? [
          BoxShadow(
            color: bg.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ] : [],
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildGlassButton(String text, VoidCallback onTap) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(100),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withAlpha(150), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF1B4332),
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
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
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(120),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withAlpha(100), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: const Color(0xFF2D6A4F)),
              const SizedBox(width: 6),
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
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(100),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withAlpha(150), width: 1),
          ),
          child: IconButton(
            icon: Icon(icon, color: const Color(0xFF2D6A4F)),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}