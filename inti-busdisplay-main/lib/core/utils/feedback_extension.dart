import 'package:flutter/material.dart';
import '../models/operation_result.dart';
import '../theme/app_colors.dart';

extension FeedbackContext on BuildContext {
  void showFeedback({required String message, required Color color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void showResult(OperationResult result, {String? fallbackSuccessMessage}) {
    showFeedback(
      message:
          result.message ??
          (result.success
              ? (fallbackSuccessMessage ?? 'Berhasil.')
              : 'Terjadi kesalahan.'),
      color: result.success ? AppColors.success : AppColors.danger,
    );
  }
}
