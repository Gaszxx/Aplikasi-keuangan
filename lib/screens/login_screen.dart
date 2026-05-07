import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
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

  void _onNumberPressed(String number) {
    if (_enteredPin.length < _pinLength) {
      setState(() {
        _enteredPin += number;
        _hasError = false;
      });

      if (_enteredPin.length == _pinLength) {
        _verifyPin();
      }
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _hasError = false;
      });
    }
  }

  Future<void> _verifyPin() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(_enteredPin);

    if (success) {
      // Hapus UI Error jika ada
      setState(() => _hasError = false);
      // Nanti kita arahkan ke Dashboard dari sini
      debugPrint("Login Berhasil! Role: ${authProvider.currentRole}");
    } else {
      setState(() {
        _hasError = true;
        _enteredPin = ''; // Reset input jika salah
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  const Icon(Icons.lock_outline, size: 64, color: AppColors.primary),
                  const SizedBox(height: 24),
                  const Text('Masukkan PIN', style: AppStyles.heading1),
                  const SizedBox(height: 8),
                  Text(
                    _hasError ? 'PIN salah, coba lagi.' : 'Sistem Keuangan Internal',
                    style: AppStyles.body.copyWith(
                      color: _hasError ? AppColors.error : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              _buildPinIndicators(),
              PinKeypad(
                onNumberPressed: _onNumberPressed,
                onBackspacePressed: _onBackspacePressed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (index) {
        final isFilled = index < _enteredPin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8.0),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? AppColors.primary : Colors.transparent,
            border: Border.all(
              color: isFilled ? AppColors.primary : AppColors.glassBorder,
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}