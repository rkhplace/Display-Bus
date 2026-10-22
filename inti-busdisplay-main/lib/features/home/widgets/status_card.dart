import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/connection_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/feedback_extension.dart';
import '../../../core/widgets/app_sheet.dart';

class StatusCard extends StatelessWidget {
  const StatusCard({super.key});

  void _showBluetoothScanner(BuildContext context) {
    final provider = context.read<ConnectionProvider>();
    provider.startBleScan();

    // Id perangkat yang sedang dihubungkan, supaya tombolnya loading dan
    // tidak bisa ditekan dua kali.
    String? connectingId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.card,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: appSheetShape,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Consumer<ConnectionProvider>(
          builder: (context, prov, child) {
            final Widget body;
            if (prov.scanResults.isEmpty) {
              body = prov.isScanning
                  ? const SheetMessage(
                      icon: Icons.bluetooth_searching_rounded,
                      message: 'Mencari panel di sekitar...',
                      color: AppColors.primary,
                    )
                  : SheetMessage(
                      icon: prov.scanError != null
                          ? Icons.bluetooth_disabled_rounded
                          : Icons.search_off_rounded,
                      message:
                          prov.scanError ?? 'Tidak ada perangkat ditemukan.',
                      color: prov.scanError != null
                          ? AppColors.danger
                          : AppColors.textSecondary,
                    );
            } else {
              body = ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: prov.scanResults.length,
                itemBuilder: (context, index) {
                  final result = prov.scanResults[index];
                  final id = result.device.remoteId.toString();
                  final name = result.device.platformName;
                  final connecting = connectingId == id;

                  return SheetListTile(
                    icon: Icons.bluetooth_rounded,
                    title: name.isEmpty ? 'Panel tanpa nama' : name,
                    subtitle: id,
                    action: SheetActionButton(
                      label: connecting ? 'Menghubungkan...' : 'Hubungkan',
                      onPressed: connectingId != null
                          ? null
                          : () async {
                              setSheetState(() => connectingId = id);
                              final outcome = await prov.connectToDevice(
                                result.device,
                              );
                              if (!ctx.mounted) return;
                              setSheetState(() => connectingId = null);
                              // Tampilkan dulu, baru tutup: setelah pop, ctx
                              // sudah tidak terpasang.
                              ctx.showResult(outcome);
                              if (outcome.success) Navigator.pop(ctx);
                            },
                    ),
                  );
                },
              );
            }

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SheetHeader(
                    title: 'Pindai Panel Display',
                    subtitle: 'Pilih panel di sekitar untuk dihubungkan.',
                    trailing: prov.isScanning
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            tooltip: 'Pindai ulang',
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: AppColors.primary,
                            ),
                            onPressed: prov.startBleScan,
                          ),
                  ),
                  Flexible(child: body),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectionProvider = context.watch<ConnectionProvider>();
    final isConnected = connectionProvider.isBleConnected;
    final color = isConnected ? AppColors.success : AppColors.danger;

    // Chip ringkas di header: status panel + tombol untuk memindai/menghubungkan.
    return Tooltip(
      message: isConnected ? 'Ganti panel' : 'Pindai dan hubungkan panel',
      child: Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _showBluetoothScanner(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isConnected
                      ? Icons.bluetooth_connected_rounded
                      : Icons.bluetooth_searching_rounded,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    isConnected
                        ? connectionProvider.connectionText
                        : 'Panel terputus',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Peringatan persisten saat panel sudah berubah tapi sinkron ke server gagal.
/// Tidak menampilkan apa pun selama tidak ada kegagalan.
class ApiSyncWarningBanner extends StatelessWidget {
  const ApiSyncWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final connectionProvider = context.watch<ConnectionProvider>();
    if (!connectionProvider.lastApiSyncFailed) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sync_problem_rounded,
            color: AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Panel sudah menerima data terbaru, tapi server belum '
              'tersinkron. Coba kirim ulang.',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          InkWell(
            onTap: connectionProvider.acknowledgeApiSyncFailure,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
