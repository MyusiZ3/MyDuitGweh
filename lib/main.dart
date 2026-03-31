import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'utils/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyDuitGwehApp());
}

class MyDuitGwehApp extends StatelessWidget {
  const MyDuitGwehApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Duit Gweh',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // DEBUG LOG
        debugPrint('--- AUTH GATE STATE: ${snapshot.connectionState} ---');
        debugPrint('--- HAS USER: ${snapshot.hasData} | UID: ${snapshot.data?.uid} ---');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashView();
        }

        final user = snapshot.data;

        return FutureBuilder<bool>(
          // Use a unique key to force rebuild of FutureBuilder when user changes
          key: ValueKey(user?.uid ?? 'logged-out'),
          future: _checkOnboarding(),
          builder: (context, onbSnapshot) {
            if (onbSnapshot.connectionState == ConnectionState.waiting) {
              return const SplashView();
            }

            final onboardingDone = onbSnapshot.data ?? false;
            debugPrint('--- ONBOARDING DONE: $onboardingDone ---');

            if (!onboardingDone) {
              return const OnboardingScreen();
            }

            if (user != null) {
              debugPrint('--- NAVIGATING TO MAIN NAV ---');
              return const MainNav();
            } else {
              debugPrint('--- NAVIGATING TO LOGIN SCREEN ---');
              return const LoginScreen();
            }
          },
        );
      },
    );
  }

  Future<bool> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_completed') ?? false;
  }
}

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
