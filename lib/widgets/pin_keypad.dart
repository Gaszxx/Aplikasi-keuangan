import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

class PinKeypad extends StatelessWidget {
  final Function(String) onNumberPressed;
  final VoidCallback onBackspacePressed;

  const PinKeypad({
    super.key,
    required this.onNumberPressed,
    required this.onBackspacePressed,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.5,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        if (index == 9) return const SizedBox.shrink(); // Ruang kosong kiri bawah
        if (index == 11) {
          return _buildButton(
            child: const Icon(Icons.backspace_outlined, color: AppColors.textPrimary),
            onTap: onBackspacePressed,
          );
        }
        
        final number = index == 10 ? '0' : '${index + 1}';
        return _buildButton(
          child: Text(number, style: AppStyles.heading2),
          onTap: () => onNumberPressed(number),
        );
      },
    );
  }

  Widget _buildButton({required Widget child, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.primary.withOpacity(0.2),
        child: Container(
          decoration: AppStyles.glassDecoration.copyWith(
            color: Colors.transparent, 
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}