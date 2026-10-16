import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/connection_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/feedback_extension.dart';
import '../../../core/widgets/primary_button.dart';
import 'quick_action_card.dart';

/// Tombol utama yang selalu terlihat di layar kontrol. Selama menunggu balasan
/// panel (maks. BleService.ackTimeout) tombol menampilkan loading dan tidak
/// bisa ditekan dua kali.
class SendToDisplayButton extends StatefulWidget {
  const SendToDisplayButton({super.key});

  @override
  State<SendToDisplayButton> createState() => _SendToDisplayButtonState();
}

class _SendToDisplayButtonState extends State<SendToDisplayButton> {
  bool _sending = false;

  Future<void> _send() async {
    final connectionProvider = context.read<ConnectionProvider>();
    final payload = buildCurrentPayload(context);

    setState(() => _sending = true);
    final result = await connectionProvider.sendPayload(payload);
    if (!mounted) return;
    setState(() => _sending = false);

    // lastApiSyncFailed bisa tersisa dari pengiriman sebelumnya; warna kuning
    // hanya untuk pengiriman INI yang sampai ke panel tapi gagal sinkron.
    if (result.success && connectionProvider.lastApiSyncFailed) {
      context.showFeedback(
        message: result.message ?? 'Gagal sinkron ke server.',
        color: AppColors.warning,
      );
      return;
    }

    context.showResult(result);
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      label: _sending ? 'Menunggu panel...' : 'Kirim ke Display',
      icon: Icons.send_rounded,
      gradient: AppColors.heroButtonGradient,
      isLoading: _sending,
      onTap: _send,
    );
  }
}
