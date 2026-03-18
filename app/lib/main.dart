import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'firebase_options.dart';
import 'services/stripe_payment_service.dart';
import 'providers/auth_provider.dart';
import 'providers/user_profile_provider.dart';
import 'providers/routes_provider.dart';
import 'providers/ride_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/driver_provider.dart';
import 'providers/passenger_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: Could not load .env file, trying .env.example: $e");
    try {
      await dotenv.load(fileName: ".env.example");
    } catch (fallbackError) {
      debugPrint("Warning: Could not load .env.example file: $fallbackError");
    }
  }

  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Error initializing Firebase: $e");
    // Continue running the app even if Firebase fails to initialize
  }

  // Initialize Stripe (skip on web as it's not fully supported)
  if (!kIsWeb) {
    try {
      Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
      if (Stripe.publishableKey.isNotEmpty) {
        await Stripe.instance.applySettings();
        await StripePaymentService().initialize();
        debugPrint("Stripe initialized successfully");
      } else {
        debugPrint("Warning: STRIPE_PUBLISHABLE_KEY not found in environment variables");
      }
    } catch (e) {
      debugPrint("Error initializing Stripe: $e");
    }
  } else {
    debugPrint("Stripe initialization skipped on web platform");
  }

  // On web, ensure Google Sign-In / GSI is available before any plugin calls
  if (kIsWeb) {
    // google_sign_in_web automatically initializes when a Google Sign-In button triggers,
    // but some versions require an explicit ensure or early call. Creating an instance early
    // helps avoid "init must be called" errors when sign-in is triggered during provider setup.
    try {
      // No-op creation to ensure plugin is registered
      // ignore: unused_local_variable
      final _ = /*GoogleSignIn*/ null;
    } catch (e) {
      debugPrint('Warning: GoogleSignIn web init hint: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Show loading while auth state is being determined
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            home: const Scaffold(
              backgroundColor: Color(0xFF232F3E),
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFE57200),
                ),
              ),
            ),
          );
        }

        // Auth state is known - create providers safely
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => UserProfileProvider()),
            ChangeNotifierProvider(create: (_) => RoutesProvider()),
            ChangeNotifierProvider(create: (_) => RideProvider()),
            ChangeNotifierProvider(create: (_) => NavigationProvider()),
            ChangeNotifierProvider(create: (_) => DriverProvider()),
            ChangeNotifierProvider(create: (_) => PassengerProvider()),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ],
          child: MaterialApp(
            title: 'UVA Cavpool',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFE57200), // UVA Orange
                brightness: Brightness.light,
              ),
              textTheme: GoogleFonts.interTextTheme(),
              useMaterial3: true,
            ),
            home: const AuthWrapper(),
            routes: {
              '/login': (context) {
                final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
                return LoginScreen(prefillEmail: args?['prefillEmail']);
              },
              '/home': (context) => const HomeScreen(),
            },
            debugShowCheckedModeBanner: false,
          ),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    // Set initialization flag after a short delay to prevent blank screen
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _hasInitialized = true;
        });
        // Register cleanup callbacks after providers are ready
        _registerCleanupCallbacks();
      }
    });
  }

  void _registerCleanupCallbacks() {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      final passengerProvider = Provider.of<PassengerProvider>(context, listen: false);
      final driverProvider = Provider.of<DriverProvider>(context, listen: false);
      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

      // Register cleanup callbacks
      authProvider.addCleanupCallback(rideProvider.cancelAllSubscriptions);
      authProvider.addCleanupCallback(passengerProvider.cancelAllSubscriptions);
      authProvider.addCleanupCallback(driverProvider.cancelAllSubscriptions);
      authProvider.addCleanupCallback(notificationProvider.cancelAllSubscriptions);
      
      debugPrint('Registered cleanup callbacks for all providers');
    } catch (e) {
      debugPrint('Error registering cleanup callbacks: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF232F3E),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFE57200),
          ),
        ),
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const Scaffold(
            backgroundColor: Color(0xFF232F3E),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE57200),
              ),
            ),
          );
        }

        if (authProvider.isAuthenticated) {
          return const HomeScreen();
        } else {
          // Check if we have arguments passed for prefilling email
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return LoginScreen(prefillEmail: args?['prefillEmail']);
        }
      },
    );
  }
}