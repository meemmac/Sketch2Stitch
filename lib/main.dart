import 'package:flutter/material.dart';

void main() {
  runApp(const Sketch2StitchTestApp());
}

class Sketch2StitchTestApp extends StatelessWidget {
  const Sketch2StitchTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sketch2Stitch Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: const WelcomeTestScreen(),
    );
  }
}

class WelcomeTestScreen extends StatefulWidget {
  const WelcomeTestScreen({super.key});

  @override
  State<WelcomeTestScreen> createState() => _WelcomeTestScreenState();
}

class _WelcomeTestScreenState extends State<WelcomeTestScreen> {
  int _tapCount = 0;

  void _handleTap() {
    setState(() {
      _tapCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.checkroom,
                  size: 80,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Sketch2Stitch',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'If you can see this on your phone,\nFlutter setup is working correctly!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _handleTap,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: Text(
                    _tapCount == 0
                        ? 'Tap to test'
                        : 'Tapped $_tapCount time${_tapCount == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 16),
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