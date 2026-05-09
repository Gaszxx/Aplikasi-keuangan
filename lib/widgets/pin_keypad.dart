import 'package:flutter/material.dart';

class PinKeypad extends StatelessWidget {
  final Function(String) onNumberPressed;
  final VoidCallback onBackspacePressed;
  final bool isDisabled; // Untuk memblokir sentuhan saat verifikasi

  const PinKeypad({
    super.key,
    required this.onNumberPressed,
    required this.onBackspacePressed,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.2, // Agak membulat (bukan terlalu kotak)
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        if (index == 9) return const SizedBox.shrink(); // Kiri bawah kosong
        
        if (index == 11) {
          return _buildButton(
            context: context,
            child: Icon(Icons.backspace_rounded, color: theme.colorScheme.onSurface, size: 28),
            onTap: isDisabled ? null : onBackspacePressed, // Disable jika loading
          );
        }
        
        final number = index == 10 ? '0' : '${index + 1}';
        return _buildButton(
          context: context,
          child: Text(
            number, 
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          onTap: isDisabled ? null : () => onNumberPressed(number),
        );
      },
    );
  }

  Widget _buildButton({required BuildContext context, required Widget child, VoidCallback? onTap}) {
    final theme = Theme.of(context);
    
    return Material(
      color: Colors.transparent, // Background tembus pandang
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(), // Efek sentuhan membulat sempurna
        splashColor: theme.colorScheme.primary.withOpacity(0.15),
        highlightColor: theme.colorScheme.primary.withOpacity(0.05),
        child: Container(
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}