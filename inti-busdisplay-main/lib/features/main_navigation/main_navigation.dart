import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/route_provider.dart';
import '../../core/theme/app_colors.dart';
import '../home/widgets/app_header.dart';
import '../home/widgets/display_setting_card.dart';
import '../home/widgets/preview_card.dart';
import '../home/widgets/quick_action_card.dart';
import '../home/widgets/route_card.dart';
import '../home/widgets/send_button.dart';
import '../home/widgets/status_card.dart';

/// Layar kontrol utama. Semua pengaturan ada di satu layar dan tombol Kirim
/// selalu terlihat:
/// - landscape / layar lebar: 2 kolom (preview + rute | tampilan + preset)
/// - portrait: 1 kolom yang bisa digulir, tombol Kirim menempel di bawah
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  /// Lebar minimum (dp) untuk tata letak 2 kolom.
  static const double twoColumnMinWidth = 640;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  @override
  void initState() {
    super.initState();
    // Rute pertama kali dimuat saat app dibuka, yang bisa terjadi sebelum
    // backend jalan atau HP tersambung WiFi. Muat ulang setiap kali halaman
    // utama tampil (termasuk tepat setelah pairing).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RouteProvider>().refreshRoutes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns =
                constraints.maxWidth >= MainNavigation.twoColumnMinWidth;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppHeader(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: twoColumns
                        ? const _TwoColumnLayout()
                        : const _SingleColumnLayout(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TwoColumnLayout extends StatelessWidget {
  const _TwoColumnLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Expanded(
          flex: 11,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PreviewCard(),
                _Gap(),
                ApiSyncWarningBanner(),
                RouteCard(),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 9,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DisplaySettingCard(),
                      _Gap(),
                      QuickActionCard(),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10),
              SendToDisplayButton(),
            ],
          ),
        ),
      ],
    );
  }
}

class _SingleColumnLayout extends StatelessWidget {
  const _SingleColumnLayout();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PreviewCard(),
                _Gap(),
                ApiSyncWarningBanner(),
                RouteCard(),
                _Gap(),
                DisplaySettingCard(),
                _Gap(),
                QuickActionCard(),
              ],
            ),
          ),
        ),
        SizedBox(height: 10),
        SendToDisplayButton(),
      ],
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 10);
}
