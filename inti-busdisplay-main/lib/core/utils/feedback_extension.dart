import 'package:flutter/material.dart';
import '../models/operation_result.dart';
import '../theme/app_colors.dart';
import '../widgets/app_toast.dart';

extension FeedbackContext on BuildContext {
  void showFeedback({required String message, required Color color}) {
    if (!mounted) return;
    AppToast.show(this, message: message, color: color);
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
