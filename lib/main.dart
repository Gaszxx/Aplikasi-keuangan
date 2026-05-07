import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Tambahan untuk mengatur Status Bar HP
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

// Import File Kita
import 'theme/app_colors.dart';
import 'providers/auth_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_layout.dart';


void main() async {
  // 1. Tahan UI sampai mesin siap
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Buat Status Bar (Jam/Sinyal HP) menjadi transparan agar desain imersif
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Akan otomatis menyesuaikan tema nanti
    ),
  );

  // 3. Nyalakan Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()), 
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()), 
      ],
      // Consumer memantau tema secara real-time
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          
          // Mengatur warna ikon status bar agar kontras dengan tema
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarIconBrightness: themeProvider.isDarkMode ? Brightness.light : Brightness.dark,
          ));

          return MaterialApp(
            title: 'Aplikasi Keuangan',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode, 
            
            // --- TEMA TERANG (LIGHT MODE) ---
            theme: ThemeData(
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFF5F7FA),
              cardColor: Colors.white,
              primaryColor: const Color(0xFF007A3D), // Hijau Tua
              useMaterial3: true,
              // ColorScheme memastikan DatePicker/Dialog bawaan Flutter pakai warna kita, bukan ungu default
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF007A3D), 
                secondary: AppColors.primary,
                surface: Colors.white,
                error: AppColors.error,
              ),
              appBarTheme: const AppBarTheme(
                systemOverlayStyle: SystemUiOverlayStyle.dark,
              ),
            ),
            
            // --- TEMA GELAP (DARK MODE) ---
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF121212),
              cardColor: const Color(0xFF1E1E1E),
              primaryColor: AppColors.primary, // Hijau Neon
              useMaterial3: true,
              colorScheme: const ColorScheme.dark(
                primary: AppColors.primary,
                secondary: AppColors.primary,
                surface: Color(0xFF1E1E1E),
                error: AppColors.error,
              ),
              appBarTheme: const AppBarTheme(
                systemOverlayStyle: SystemUiOverlayStyle.light,
              ),
            ),
            
            home: const AuthWrapper(), 
          );
        },
      ),
    );
  }
}

// --- PENGATUR LALU LINTAS OTOMATIS (AUTH WRAPPER) ---
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<AuthProvider>().checkAuthStatus());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isAuthenticated) {
          return const MainLayout();
        }
        return const LoginScreen();
      },
    );
  }
}