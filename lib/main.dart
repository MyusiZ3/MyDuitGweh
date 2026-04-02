import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:camera_android/camera_android.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'utils/app_theme.dart';
import 'utils/tone_dictionary.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_nav.dart';
import 'screens/maintenance_gate_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/auth_service.dart';
import 'services/update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FIX: Force Camera2 implementation to avoid CameraX "Unsupported value" crash on some devices (like Xiaomi)
  if (defaultTargetPlatform == TargetPlatform.android) {
    CameraPlatform.instance = AndroidCamera();
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // VITAL: Tarik memori kepribadian sebelum layar pertama di-render!
  await ToneManager.loadTone();

  runApp(const MyDuitGwehApp());
}

class MyDuitGwehApp extends StatelessWidget {
  const MyDuitGwehApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Keajaiban terjadi di sini: Jika Tone berubah, SELURUH App ikut berubah otomatis!
    return ValueListenableBuilder<AppTone>(
      valueListenable: ToneManager.notifier,
      builder: (context, activeTone, child) {
        return MaterialApp(
          title: 'My Duit Gweh',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = FirebaseAuth.instance.authStateChanges();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      // CRITICAL: Provide initialData so hot reload doesn't lose current state
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        // DEBUG LOG
        debugPrint('--- AUTH GATE STATE: ${snapshot.connectionState} ---');
        debugPrint(
            '--- HAS USER: ${snapshot.hasData} | UID: ${snapshot.data?.uid} ---');

        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
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
              debugPrint('--- NAVIGATING TO MAINTENANCE WRAPPER ---');
              return MaintenanceGateWrapper(user: user);
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

class MaintenanceGateWrapper extends StatefulWidget {
  final User user;
  const MaintenanceGateWrapper({super.key, required this.user});

  @override
  State<MaintenanceGateWrapper> createState() => _MaintenanceGateWrapperState();
}

class _MaintenanceGateWrapperState extends State<MaintenanceGateWrapper> {
  late final Stream<DocumentSnapshot> _configStream;
  Future<bool>? _adminFuture;

  @override
  void initState() {
    super.initState();
    _configStream = FirebaseFirestore.instance
        .collection('app_config')
        .doc('global')
        .snapshots();
    _adminFuture = AuthService().isAdmin(uid: widget.user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _configStream,
      builder: (context, snapshot) {
        debugPrint(
            '--- MAINTENANCE GATE: connState=${snapshot.connectionState}, hasData=${snapshot.hasData}, hasError=${snapshot.hasError} ---');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashView();
        }

        // Jika error atau dokumen tidak ada, langsung masuk
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          debugPrint(
              '--- MAINTENANCE GATE: No config doc or error, going to MainNav ---');
          return const MainNav();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final isMaintenance = data['isMaintenance'] ?? false;
        final maintenanceMsg = data['maintenanceMessage'] ??
            'Aplikasi sedang dalam pemeliharaan rutin.';
            
        if (!isMaintenance) {
          // Check for updates if not in maintenance
          WidgetsBinding.instance.addPostFrameCallback((_) {
            UpdateService.checkAndShowUpdateDialog(context);
          });
          return const MainNav();
        }

        // Jika maintenance aktif, cek apakah user adalah admin/superadmin
        return FutureBuilder<bool>(
          future: _adminFuture,
          builder: (context, adminSnapshot) {
            if (adminSnapshot.connectionState == ConnectionState.waiting) {
              return const SplashView();
            }

            final isAdmin = adminSnapshot.data ?? false;

            if (isAdmin) {
              return const MainNav();
            } else {
              return MaintenanceGateScreen(message: maintenanceMsg);
            }
          },
        );
      },
    );
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
              child: const Icon(Icons.account_balance_wallet_rounded,
                  size: 40, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
