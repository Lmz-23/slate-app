import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class VoiceInputButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const VoiceInputButton({
    super.key,
    required this.isListening,
    required this.onStart,
    required this.onStop,
  });

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        if (widget.isListening) {
          _animationController.forward();
        }
      }
    });
  }

  @override
  void didUpdateWidget(VoiceInputButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !oldWidget.isListening) {
      _animationController.forward();
    } else if (!widget.isListening && oldWidget.isListening) {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isListening ? widget.onStop : widget.onStart,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.isListening ? AppColors.error : AppColors.surfaceLight,
          boxShadow: widget.isListening
              ? [
                  BoxShadow(
                    color: AppColors.error.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing ring animation
            if (widget.isListening)
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: _opacityAnimation.value),
                          width: 3,
                        ),
                      ),
                    ),
                  );
                },
              ),
            // Mic icon
            Icon(
              widget.isListening ? Icons.stop : Icons.mic,
              color: widget.isListening ? Colors.white : AppColors.primary,
              size: 28,
            ),
            // Listening indicator dot
            if (widget.isListening)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: AppColors.error,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.graphic_eq,
                    size: 8,
                    color: AppColors.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
