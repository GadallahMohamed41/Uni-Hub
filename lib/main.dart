import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/features/splash/presentation/screens/splash_screen.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/features/home/presentation/providers/posts_provider.dart';
import 'package:project_test2/core/theme/theme_provider.dart';
import 'package:project_test2/core/providers/locale_provider.dart';
import 'package:project_test2/core/theme/theme_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_test2/firebase_options.dart';
import 'package:project_test2/core/config/supabase_config.dart';
import 'package:project_test2/core/services/push_notifications_service.dart';
import 'package:project_test2/core/services/deep_link_service.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

bool get _isMobilePlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[BG-FCM] Handler started — messageId=${message.messageId}');
    await PushNotificationsService.showBackgroundNotification(message);
    debugPrint('[BG-FCM] Notification shown successfully');
  } catch (e, stack) {
    debugPrint('[BG-FCM] CRASH in background handler: $e\n$stack');
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrapper());
}

class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({super.key});

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  bool _initialized = false;
  late ThemeRepository _themeRepository;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Optimize startup memory allocation limits
    imageCache.maximumSize = 100;
    imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50MB
    _initSystem();
  }

  Future<void> _initSystem() async {
    try {
      // 1. Initialize Firebase Core
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      try {
        if (kDebugMode) {
          await FirebaseAppCheck.instance.activate(
            providerAndroid: AndroidDebugProvider(),
            providerApple: AppleDebugProvider(),
          );
        } else {
          await FirebaseAppCheck.instance.activate(
            providerAndroid: AndroidPlayIntegrityProvider(),
            providerApple: AppleAppAttestProvider(),
          );
        }
        debugPrint('[AppCheck] Activated successfully');
      } catch (e) {
        debugPrint('[AppCheck] Activation failed: $e');
      }

      // 3. Offline settings configuration for Firestore
      if (!kIsWeb) {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      }

      // 4. Background message registration
      if (_isMobilePlatform) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      }

      // 5. Load SharedPreferences and build ThemeRepository
      final prefs = await SharedPreferences.getInstance();
      _themeRepository = ThemeRepository(prefs);

      if (mounted) {
        setState(() {
          _initialized = true;
        });

        // 6. Non-critical deferred services post-render of actual UI
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initDeferredServices();
        });
      }
    } catch (e, stack) {
      debugPrint('[Bootstrapper] FATAL BOOT ERROR: $e\n$stack');
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Initialization Error:\n$_error',
                style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    if (!_initialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BootSplashScreen(),
      );
    }

    return MyApp(themeRepository: _themeRepository);
  }
}

class BootSplashScreen extends StatelessWidget {
  const BootSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school_rounded,
                size: 100,
                color: Colors.white,
              ),
              SizedBox(height: 40),
              Text(
                "NATU-Students",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Services that do NOT need to block the first frame.
/// Called after the UI is already visible (no skipped frames).
Future<void> _initDeferredServices() async {
  // Supabase initialization (network call — defer it)
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    // Anonymous sign-in for storage access (non-blocking, best-effort)
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession == null) {
      // Fire-and-forget: deliberately not awaited — best-effort only
      unawaited(() async {
        try {
          await auth.signInAnonymously();
        } catch (e) {
          debugPrint('[Supabase] Anonymous sign-in failed: $e');
        }
      }());
    }
  } catch (e) {
    debugPrint('[Supabase] Init failed: $e');
  }

  if (_isMobilePlatform) {
    try {
      await PushNotificationsService.instance.initialize();
      PushNotificationsService.instance.attachNavigatorKey(rootNavigatorKey);
    } catch (e) {
      debugPrint('[FCM] Push notifications init failed: $e');
    }
  }

  DeepLinkService.instance.initializeWithNavigatorKey();
}

class MyApp extends StatelessWidget {
  final ThemeRepository themeRepository;

  const MyApp({super.key, required this.themeRepository});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PostsProvider()),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(
            repository: themeRepository,
            initialIsDark: themeRepository.isDarkMode(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, child) {
          return MaterialApp(
            title: 'NATU-Students',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            locale: localeProvider.locale,
            navigatorKey: rootNavigatorKey,
            supportedLocales: const [
              Locale('en'),
              Locale('ar', 'EG'),
              Locale('ar'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
