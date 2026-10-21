import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/connection_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/feedback_extension.dart';

class StatusCard extends StatelessWidget {
  const StatusCard({super.key});

  void _showBluetoothScanner(BuildContext context) {
    final provider = context.read<ConnectionProvider>();
    provider.startBleScan();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer<ConnectionProvider>(
        builder: (context, prov, child) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pindai Panel Display',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (prov.isScanning)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: () => prov.startBleScan(),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (prov.scanResults.isEmpty && !prov.isScanning)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        prov.scanError ?? 'Tidak ada perangkat ditemukan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: prov.scanError != null
                              ? AppColors.danger
                              : null,
                        ),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: prov.scanResults.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final result = prov.scanResults[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.bluetooth_rounded,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            result.device.platformName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            result.device.remoteId.toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              final outcome = await prov.connectToDevice(
                                result.device,
                              );
                              if (!ctx.mounted) return;
                              // Tampilkan dulu, baru tutup: setelah pop, ctx
                              // sudah tidak terpasang.
                              ctx.showResult(outcome);
                              if (outcome.success) Navigator.pop(ctx);
                            },
                            child: const Text(
                              'Hubungkan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
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
