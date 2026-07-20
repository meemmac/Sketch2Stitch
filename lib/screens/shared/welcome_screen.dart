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
  late AnimationController _auroraController;
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
    'crochet.jpg', 'embroidery.jpg', 'lace.jpg', 'silk.jpg',
    'saree.jpg', 'textile.jpg', 'tassel.jpg', 'fab.jpg'
  ];

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

                  _buildHorizontalGallery(screenHeight),

                  const Spacer(flex: 1),

                  _buildActionButtons(),

                  const SizedBox(height: 12),

                  _buildStakeholderChips(),

                  const SizedBox(height: 8),
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
          gradient: RadialGradient(colors: [color, color.withAlpha(0)]),
        ),
      ),
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
              child: Image.asset('assets/images/transparent_logo.png', height: 42),
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
            fontSize: screenHeight < 700 ? 36 : 44,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1B4332),
            letterSpacing: -1.5,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 22,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Text(
              _taglines[_taglineIndex],
              key: ValueKey<int>(_taglineIndex),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF2D6A4F),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalGallery(double screenHeight) {
    double galleryHeight = screenHeight * 0.28;
    if (galleryHeight > 240) galleryHeight = 240;

    return SizedBox(
      height: galleryHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _images.length,
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          return Container(
            width: galleryHeight * 0.75,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              image: DecorationImage(
                image: AssetImage('assets/images/${_images[index]}'),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                )
              ],
              border: Border.all(color: Colors.white.withAlpha(180), width: 1.5),
            ),
          );
        },
      ),
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
        const SizedBox(height: 12),
        _buildGlassButton(
          "Login",
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutUsScreen())),
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          label: const Text("About Us", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF1B4332), padding: EdgeInsets.zero),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(String text, Color bg, Color textColor, VoidCallback onTap, {bool hasGlow = false}) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: hasGlow ? [BoxShadow(color: bg.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 6))] : [],
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
      ),
    );
  }

  Widget _buildGlassButton(String text, VoidCallback onTap) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(80),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withAlpha(120), width: 1.2),
            ),
            alignment: Alignment.center,
            child: Text(text, style: const TextStyle(color: Color(0xFF1B4332), fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
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
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(100),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withAlpha(80), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: const Color(0xFF2D6A4F)),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1B4332))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton({required IconData icon, required VoidCallback onPressed}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha(120), width: 1),
          ),
          child: IconButton(
            icon: Icon(icon, color: const Color(0xFF2D6A4F), size: 20),
            onPressed: onPressed,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ),
      ),
    );
  }
}