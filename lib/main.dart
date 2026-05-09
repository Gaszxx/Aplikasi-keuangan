import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

// --- IMPORT FILE KITA ---
import 'theme/app_colors.dart';
import 'theme/app_styles.dart';
import 'providers/auth_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_layout.dart';

void main() async {
  // 1. Tahan UI sampai mesin (Firebase) siap
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().init();
  // 2. Buat Status Bar (Jam/Sinyal HP) menjadi transparan untuk efek imersif
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // 3. Kunci Orientasi HP (Aplikasi ERP ini fokus di mode Portrait agar layout tidak pecah)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 4. Nyalakan Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const BidadariERPApp());
}

class BidadariERPApp extends StatelessWidget {
  const BidadariERPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      // Consumer memantau tema secara real-time dari ThemeProvider
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          // Mengatur warna ikon status bar agar kontras dengan tema saat ini
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarIconBrightness: themeProvider.isDarkMode
                  ? Brightness.light
                  : Brightness.dark,
            ),
          );

          return MaterialApp(
            title: 'Bidadari ERP',
            debugShowCheckedModeBanner:
                false, // Hilangkan pita 'DEBUG' merah di pojok
            themeMode: themeProvider.themeMode,

            // ==========================================
            // --- TEMA TERANG (LIGHT MODE) ENTERPRISE ---
            // ==========================================
            theme: ThemeData(
              useMaterial3: true,
              fontFamily:
                  'PlusJakartaSans', // Font profesional kita (Pastikan sudah di-download & daftar di pubspec.yaml)
              brightness: Brightness.light,
              scaffoldBackgroundColor: AppColors.backgroundLight,

              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                secondary: AppColors.kelapa, // Aksen warna bisnis
                surface: AppColors.surfaceLight,
                background: AppColors.backgroundLight,
                error: AppColors.error,
              ),

              // Standarisasi Kartu (Card) Global
              cardTheme: CardThemeData(
                color: AppColors.surfaceLight,
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: AppStyles.cardRadius,
                  side: BorderSide(
                    color: AppColors.textSecondary.withOpacity(0.08),
                  ), // Border sangat tipis ala iOS
                ),
              ),

              // Standarisasi AppBar Global
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.backgroundLight,
                elevation: 0,
                scrolledUnderElevation:
                    0, // Mencegah warna berubah saat di-scroll di Material 3
                centerTitle: false,
                iconTheme: IconThemeData(color: AppColors.textPrimary),
                titleTextStyle: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),

              // Standarisasi Teks Global
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: AppColors.textPrimary),
                bodyMedium: TextStyle(color: AppColors.textSecondary),
              ),
            ),

            // ==========================================
            // ==========================================
            // --- TEMA GELAP (DARK MODE) ENTERPRISE ---
            // ==========================================
            darkTheme: ThemeData(
              useMaterial3: true,
              fontFamily: 'PlusJakartaSans',
              brightness: Brightness.dark,
              scaffoldBackgroundColor: AppColors.backgroundDark,

              colorScheme: const ColorScheme.dark(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                secondary: AppColors.kelapa,
                surface: AppColors.surfaceDark,
                background: AppColors.backgroundDark,
                error: AppColors.error,
              ),

              cardTheme: CardThemeData(
                color: AppColors.surfaceDark,
                elevation: 0.0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: AppStyles.cardRadius,
                  side: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
              ), // <--- INI KURUNG TUTUP YANG TADI HILANG

              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.backgroundDark,
                elevation: 0.0,
                scrolledUnderElevation: 0.0,
                centerTitle: false,
                iconTheme: IconThemeData(color: AppColors.textPrimaryDark),
                titleTextStyle: TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),

              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: AppColors.textPrimaryDark),
                bodyMedium: TextStyle(color: AppColors.textSecondaryDark),
              ),
            ),

            // --- ROUTER AWAL ---
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

// --- PENGATUR LALU LINTAS OTOMATIS & SECURITY (AUTH WRAPPER) ---
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

// Tambahkan 'with WidgetsBindingObserver' agar bisa memantau aplikasi
class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  DateTime? _lastPausedTime; // Menyimpan waktu kapan aplikasi ditinggalkan

  @override
  void initState() {
    super.initState();
    // 1. Daftarkan pemantau (Observer) saat aplikasi pertama kali jalan
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => context.read<AuthProvider>().checkAuthStatus());
  }

  @override
  void dispose() {
    // 2. Lepas pemantau saat aplikasi dihancurkan (mencegah memory leak)
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 3. MESIN WAKTU KEMANAN (App Lifecycle)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      // Saat User menekan tombol Home atau pindah ke aplikasi lain (Background)
      _lastPausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // Saat User kembali membuka Bidadari ERP (Foreground)
      if (_lastPausedTime != null) {
        final difference = DateTime.now().difference(_lastPausedTime!);

        // Cek apakah ditinggalkan lebih dari 3 menit
        if (difference.inMinutes >= 4) {
          // KUNCI APLIKASI! Paksa Logout / Minta PIN lagi
          context.read<AuthProvider>().logout();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // Jika status true, masuk aplikasi. Jika false, hadapkan ke gembok PIN!
        if (auth.isAuthenticated) {
          return const MainLayout();
        }
        return const LoginScreen();
      },
    );
  }
}
