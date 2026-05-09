import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk Getaran (Haptic Feedback)
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/pin_keypad.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _enteredPin = '';
  static const int _pinLength = 6;
  bool _hasError = false;
  bool _isLoading = false; // Mengunci layar saat proses verifikasi

  void _onNumberPressed(String number) {
    if (_enteredPin.length < _pinLength && !_isLoading) {
      HapticFeedback.lightImpact(); // Getaran halus ala iOS/Android Flagship
      
      setState(() {
        _enteredPin += number;
        _hasError = false;
      });

      // Jika sudah 6 digit, otomatis verifikasi
      if (_enteredPin.length == _pinLength) {
        _verifyPin();
      }
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isNotEmpty && !_isLoading) {
      HapticFeedback.selectionClick();
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _hasError = false;
      });
    }
  }

  Future<void> _verifyPin() async {
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(_enteredPin);

    if (success) {
      setState(() {
        _hasError = false;
        _isLoading = false;
      });
      debugPrint("Login Berhasil! Role: ${authProvider.currentRole}");
      // Tidak perlu Navigator.push karena AuthWrapper di main.dart otomatis memindahkan layar
    } else {
      HapticFeedback.vibrate(); // Getaran kasar menandakan error
      setState(() => _hasError = true);
      
      // UX Trick: Beri jeda 500ms sebelum menghapus PIN agar user sadar PIN-nya salah
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _enteredPin = '';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Membaca tema dari main.dart tanpa hardcode
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: Center(
          // RESPONSIVE: Mengunci lebar form agar tidak melar di Tablet/Web
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // --- HEADER SECTION ---
                  Column(
                    children: [
                      // Logo Box Modern
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.shield_outlined, size: 48, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Bidadari ERP',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _hasError ? 'PIN salah, silakan coba lagi.' : 'Masukkan PIN Anda',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _hasError ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                          fontWeight: _hasError ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  
                  // --- PIN INDICATOR SECTION ---
                  _buildPinIndicators(theme),
                  
                  // --- KEYPAD SECTION ---
                  PinKeypad(
                    onNumberPressed: _onNumberPressed,
                    onBackspacePressed: _onBackspacePressed,
                    isDisabled: _isLoading, // Kunci tombol saat loading
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinIndicators(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (index) {
        final isFilled = index < _enteredPin.length;
        
        // Logika warna titik PIN
        Color dotColor = Colors.transparent;
        if (_hasError) {
          dotColor = theme.colorScheme.error; // Merah jika salah
        } else if (isFilled) {
          dotColor = theme.colorScheme.primary; // Teal jika terisi
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150), // Animasi membesar/mengecil halus
          margin: const EdgeInsets.symmetric(horizontal: 10.0),
          width: isFilled ? 16 : 12, // Membesar sedikit saat diisi
          height: isFilled ? 16 : 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
            border: Border.all(
              color: _hasError 
                  ? theme.colorScheme.error 
                  : (isFilled ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.3)),
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}