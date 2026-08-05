import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/shared/auth_wrapper.dart';
import 'firebase_options.dart';
import 'services/data_seed_service.dart'; // Add this import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // ─── DATA SEEDING ──────────────────────────────────────────────────────
  // ⚠️ RUN THIS ONCE to populate your Firestore with sample data
  // After running once, COMMENT OUT or REMOVE these lines
  // Uncomment the lines below to seed data:
  
  try {
    print('🌱 Seeding data...');
    final seedService = DataSeedService();
    await seedService.seedAllData();
    print('✅ Data seeded successfully!');
  } catch (e) {
    print('❌ Error seeding data: $e');
  }
  
  // ─── END DATA SEEDING ──────────────────────────────────────────────────
  
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
        primaryColor: const Color(0xFF2C5C44),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C5C44),
          primary: const Color(0xFF2C5C44),
          secondary: const Color(0xFF4E8B6F),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}