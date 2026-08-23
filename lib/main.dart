import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_links/app_links.dart';
import 'screens/shared/auth_wrapper.dart';
import 'screens/shared/login_screen.dart';
import 'screens/shared/reset_password_screen.dart';
import 'firebase_options.dart';

/// Global navigator key so the deep-link listener (which lives outside
/// any widget's BuildContext) can still push routes.
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // `debugPrint` still writes to the console in release builds, and the
  // remaining call sites log caught exceptions — which can carry Firestore
  // document paths and user ids. Silence them outside debug so nothing
  // internal is exposed on a shipped build; developers keep the logs.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const Sketch2StitchApp());
}

class Sketch2StitchApp extends StatefulWidget {
  const Sketch2StitchApp({super.key});

  @override
  State<Sketch2StitchApp> createState() => _Sketch2StitchAppState();
}

class _Sketch2StitchAppState extends State<Sketch2StitchApp> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _listenForDeepLinks();
  }

  void _listenForDeepLinks() {
    // Handles links tapped while the app is already running or backgrounded.
    _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingLink(uri);
    });

    // Handles the case where the app was launched cold by tapping the link.
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleIncomingLink(uri);
    });
  }

  void _handleIncomingLink(Uri uri) {
    debugPrint('🔗 Incoming deep link: $uri');

    if (uri.scheme != 'sketch2stitch') return;

    // sketch2stitch://reset?oobCode=...  -> the password-reset email, bounced
    // here by public/action.html so the new password is set inside the app.
    if (uri.host == 'reset') {
      final oobCode = uri.queryParameters['oobCode'];
      if (oobCode == null || oobCode.isEmpty) return;
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(oobCode: oobCode),
        ),
        (route) => false,
      );
      return;
    }

    // sketch2stitch://reset-done -> kept for links already in users' inboxes
    // that still point at the old Firebase-hosted reset page.
    if (uri.host == 'reset-done') {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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