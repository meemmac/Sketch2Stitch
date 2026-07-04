import 'package:flutter/material.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_fabrics_screen.dart';

void main() {
  runApp(const Sketch2StitchApp());
}

class Sketch2StitchApp extends StatelessWidget {
  const Sketch2StitchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sketch2Stitch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF224F34),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF224F34),
          primary: const Color(0xFF224F34),
          secondary: const Color(0xFF64CD57),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const BrowseFabricsScreen(),
    );
  }
}