import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'main_layout.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // --- ANIMASI FADE-IN (Muncul Perlahan) ---
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    // Jalankan timer untuk pindah layar
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Tahan layar selama 2.5 detik agar logo terlihat jelas
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;


    // Cek apakah user sudah login. 
    // Jika belum, lempar ke Layar PIN. Jika sudah, langsung ke Dashboard.
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (_) => const AuthWrapper())
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface, // Menyesuaikan Dark/Light Mode otomatis
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- LOGO BIDADARI ---
              // Pastikan nama file di bawah ini sama persis dengan yang ada di folder assets
              Image.asset(
                'assets/images/logo_bidadari.png',
                width: 350, 
                height: 350,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 40),

              // --- INDIKATOR LOADING & TEKS ---
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Menyiapkan Data Keuangan...',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.grey,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}