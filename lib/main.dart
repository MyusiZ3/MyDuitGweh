import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:camera_android/camera_android.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'services/security_service.dart';
import 'services/security_listener_service.dart';
import 'package:my_duit_gweh/services/notification_service.dart';
import 'utils/app_theme.dart';
import 'utils/tone_dictionary.dart';
import 'utils/navigator_key.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_nav.dart';
import 'screens/maintenance_gate_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/auth_service.dart';
import 'services/update_service.dart';
import 'screens/security_gate_screen.dart';
import 'services/notif_sync_service.dart';
import 'services/notif_listener_bridge.dart';
import 'screens/suspension_gate_screen.dart';

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

  // Init Workmanager untuk background sync notifikasi
  await NotifSyncService.init();
  // Init local notifications
  await NotificationService().init();
  // Restore listener state jika sebelumnya aktif
  await NotifListenerBridge.initOnAppStart();

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
          navigatorKey: navigatorKey,
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
  late final Future<bool> _isSafeFuture;
  Future<bool>? _onboardingFuture;

  @override
  void initState() {
    super.initState();
    _authStream = FirebaseAuth.instance.authStateChanges();
    _isSafeFuture = SecurityService.isDeviceSafe();
    _onboardingFuture = _checkOnboarding();
  }

  /// Dipanggil oleh OnboardingScreen saat user selesai onboarding
  void _onOnboardingComplete() {
    setState(() {
      _onboardingFuture = Future.value(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isSafeFuture,
      builder: (context, safetySnapshot) {
        if (safetySnapshot.connectionState == ConnectionState.waiting) {
          return const SplashView();
        }

        if (safetySnapshot.data == false) {
          return const SecurityGateScreen();
        }

        // STEP 1: Cek onboarding DULU sebelum cek auth
        return FutureBuilder<bool>(
          future: _onboardingFuture,
          builder: (context, onbSnapshot) {
            if (onbSnapshot.connectionState == ConnectionState.waiting) {
              return const SplashView();
            }

            final onboardingDone = onbSnapshot.data ?? false;
            if (!onboardingDone) {
              debugPrint('--- NAVIGATING TO ONBOARDING ---');
              return OnboardingScreen(
                onComplete: _onOnboardingComplete,
              );
            }

            // STEP 2: Onboarding selesai, baru cek auth
            return StreamBuilder<User?>(
              stream: _authStream,
              initialData: FirebaseAuth.instance.currentUser,
              builder: (context, snapshot) {
                final user = snapshot.data;
                debugPrint('--- AUTH GATE LOG: user=$user, connState=${snapshot.connectionState} ---');

                if (snapshot.connectionState == ConnectionState.waiting &&
                    user == null) {
                  return const SplashView();
                }

                if (user == null) {
                  debugPrint('--- NAVIGATING TO LOGIN SCREEN ---');
                  return const LoginScreen();
                }

                debugPrint('--- NAVIGATING TO USER STATUS WRAPPER ---');
                return UserGateWrapper(user: user);
              },
            );
          },
        );
      },
    );
  }

  Future<bool> _checkOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('onboarding_completed') ?? false;
    } catch (_) {
      return false;
    }
  }
}

class UserGateWrapper extends StatefulWidget {
  final User user;
  const UserGateWrapper({super.key, required this.user});

  @override
  State<UserGateWrapper> createState() => _UserGateWrapperState();
}

class _UserGateWrapperState extends State<UserGateWrapper> {
  late final Stream<DocumentSnapshot> _userStream;

  @override
  void initState() {
    super.initState();
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashView();
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return MaintenanceGateWrapper(user: widget.user);
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final isDeactivated = data['isDeactivated'] ?? false;
        final untilTimestamp = data['deactivatedUntil'] as Timestamp?;
        final reason =
            data['deactivatedReason'] ?? 'Melanggar Kebijakan Platform.';

        if (isDeactivated) {
          if (untilTimestamp != null) {
            final DateTime until = untilTimestamp.toDate();
            if (DateTime.now().isAfter(until)) {
              return MaintenanceGateWrapper(user: widget.user);
            }
          }

          return SuspensionGateScreen(
            reason: reason,
            until: untilTimestamp?.toDate(),
          );
        }

        return MaintenanceGateWrapper(user: widget.user);
      },
    );
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

        // Jika error atau dokumen tidak ada, kita harus hati-hati
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          final error = snapshot.error?.toString().toLowerCase() ?? '';
          if (error.contains('permission-denied') || error.contains('not find document')) {
            debugPrint('--- MAINTENANCE GATE: Auth/Permission issue detected. Staying in safe zone. ---');
            return const SplashView(); 
          }
          
          debugPrint(
              '--- MAINTENANCE GATE: Fallback to MainNav (error: $error) ---');
          return const MainNav();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final isMaintenance = data['isMaintenance'] ?? false;
        final maintenanceMsg = data['maintenanceMessage'] ??
            'Aplikasi sedang dalam pemeliharaan rutin.';
            
        // Selalu cek admin untuk menyalakan Security Listener di background
        return FutureBuilder<bool>(
          future: _adminFuture,
          builder: (context, adminSnapshot) {
            final isAdmin = adminSnapshot.data ?? false;
            debugPrint('--- AUTH GATE: User=${widget.user.email}, isAdmin=$isAdmin');
            
            if (isAdmin) {
              SecurityListenerService().startListening(widget.user.uid);
            }

            if (!isMaintenance) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                UpdateService.syncUpdateDialog(context, data);
              });
              return const MainNav();
            }

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
            SizedBox(
              width: 80,
              height: 80,
              child: Image.asset(
                'assets/images/logo_loading.png',
                width: 60,
                height: 60,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
