import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Notifikasi singkat di bagian ATAS layar. Pengganti SnackBar: SnackBar muncul
/// di bawah dan menutupi tombol "Kirim ke Display", serta mengantre sehingga
/// pesan lama masih tampil beberapa detik setelah aksi berikutnya.
///
/// Hanya satu toast tampil sekaligus; toast baru langsung menggantikan yang
/// lama. Ketuk atau geser ke atas untuk menutup lebih cepat.
class AppToast {
  AppToast._();

  static const Duration successDuration = Duration(milliseconds: 2200);
  static const Duration otherDuration = Duration(milliseconds: 3800);

  static _ToastHandle? _current;

  static void show(
    BuildContext context, {
    required String message,
    required Color color,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _current?.remove();

    final handle = _ToastHandle();
    handle.entry = OverlayEntry(
      builder: (_) => _ToastHost(
        message: message,
        color: color,
        duration: color == AppColors.success ? successDuration : otherDuration,
        onDismissed: handle.remove,
      ),
    );
    _current = handle;
    overlay.insert(handle.entry);
  }
}

class _ToastHandle {
  late final OverlayEntry entry;
  bool _removed = false;

  void remove() {
    if (_removed) return;
    _removed = true;
    if (AppToast._current == this) AppToast._current = null;
    entry.remove();
  }
}

class _ToastHost extends StatefulWidget {
  final String message;
  final Color color;
  final Duration duration;
  final VoidCallback onDismissed;

  const _ToastHost({
    required this.message,
    required this.color,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    _timer = Timer(widget.duration, _close);
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SlideTransition(
                position: _slide,
                child: FadeTransition(
                  opacity: _controller,
                  child: Dismissible(
                    key: const ValueKey('app-toast'),
                    direction: DismissDirection.up,
                    onDismissed: (_) => widget.onDismissed(),
                    child: GestureDetector(
                      onTap: _close,
                      child: AppToastCard(
                        message: widget.message,
                        color: widget.color,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tampilan toast: kartu putih dengan aksen warna status di kiri.
class AppToastCard extends StatelessWidget {
  final String message;
  final Color color;

  const AppToastCard({super.key, required this.message, required this.color});

  IconData get _icon {
    if (color == AppColors.success) return Icons.check_circle_rounded;
    if (color == AppColors.warning) return Icons.warning_amber_rounded;
    if (color == AppColors.danger) return Icons.error_rounded;
    return Icons.info_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        child: Row(
          children: [
            Icon(_icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
