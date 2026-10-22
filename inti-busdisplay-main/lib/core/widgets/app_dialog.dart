import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/operation_result.dart';
import '../theme/app_colors.dart';

/// Dialog standar untuk form dan konfirmasi: ikon + judul di atas, isi, pesan
/// galat di dalam dialog, lalu tombol Batal dan aksi utama selebar dialog.
///
/// [onSubmit] dijalankan saat tombol utama ditekan; selama berjalan tombol
/// menampilkan loading. Hasil sukses menutup dialog dan dikembalikan ke
/// pemanggil `showDialog`; hasil gagal tetap membuka dialog dan menampilkan
/// pesannya (isian tidak hilang). Kembalikan null untuk tidak melakukan apa
/// pun.
class AppFormDialog extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? child;
  final String submitLabel;
  final String cancelLabel;

  /// Aksi berbahaya (hapus): ikon dan tombol utama berwarna merah.
  final bool destructive;
  final Future<OperationResult?> Function() onSubmit;

  const AppFormDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    this.subtitle,
    this.child,
    this.cancelLabel = 'Batal',
    this.destructive = false,
  });

  @override
  State<AppFormDialog> createState() => _AppFormDialogState();
}

class _AppFormDialogState extends State<AppFormDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.onSubmit();
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == null) return;
    if (result.success) {
      Navigator.pop(context, result);
    } else {
      setState(() => _error = result.message ?? 'Terjadi kesalahan.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color tone = widget.destructive
        ? AppColors.danger
        : AppColors.primary;

    return Dialog(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon, color: tone, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (widget.subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              widget.subtitle!,
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.child != null) ...[
                const SizedBox(height: 18),
                widget.child!,
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                _ErrorBox(message: _error!),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.subtleFill,
                        foregroundColor: AppColors.textPrimary,
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                      child: Text(widget.cancelLabel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tone,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(widget.submitLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;

  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Label kecil di atas isian form.
class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
