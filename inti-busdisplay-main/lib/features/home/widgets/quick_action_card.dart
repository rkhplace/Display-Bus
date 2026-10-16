import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/display_settings_provider.dart';
import '../../../core/providers/preset_provider.dart';
import '../../../core/providers/route_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/display_payload_builder.dart';
import '../../../core/utils/feedback_extension.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_card.dart';

/// Payload dari pengaturan yang sedang tampil (rute, arah, animasi, slider).
Map<String, dynamic> buildCurrentPayload(BuildContext context) {
  final routeProvider = context.read<RouteProvider>();
  final settingsProvider = context.read<DisplaySettingsProvider>();
  return DisplayPayloadBuilder.build(
    route: routeProvider.selectedRoute,
    isPergi: routeProvider.isPergi,
    animMode: settingsProvider.animMode,
    speed: settingsProvider.speed,
    brightness: settingsProvider.brightness,
    fontSize: settingsProvider.fontSize,
  );
}

class QuickActionCard extends StatelessWidget {
  const QuickActionCard({super.key});

  void _showSavePresetDialog(BuildContext context) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        title: const Text(
          'Simpan Preset',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            hintText: 'Nama Preset (Cth: Pagi Hari)',
            filled: true,
            fillColor: AppColors.subtleFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;

              final payload = buildCurrentPayload(context);
              final result = await context
                  .read<PresetProvider>()
                  .saveCurrentPreset(nameController.text.trim(), payload);

              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                context.showResult(
                  result,
                  fallbackSuccessMessage: 'Preset berhasil disimpan!',
                );
              }
            },
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _applyPreset(
    BuildContext context,
    Map<String, dynamic> payload, {
    String? presetId,
    String? presetName,
  }) {
    try {
      final routeMatched = context.read<RouteProvider>().applyRouteFromPayload(
        payload,
      );
      context.read<DisplaySettingsProvider>().applyFromPayload(payload);
      context.read<PresetProvider>().markLoadedPreset(
        presetId: presetId,
        presetName: presetName,
      );

      if (!routeMatched) {
        context.showFeedback(
          message:
              'Preset "${presetName ?? ''}" diterapkan, tapi rute aslinya '
              'sudah tidak tersedia — menggunakan rute pertama sebagai gantinya.',
          color: AppColors.warning,
        );
        return;
      }

      context.showFeedback(
        message: presetName != null && presetName.isNotEmpty
            ? 'Preset "$presetName" berhasil diterapkan.'
            : 'Preset berhasil diterapkan.',
        color: AppColors.success,
      );
    } catch (e) {
      debugPrint('Gagal memuat preset: $e');
      context.showFeedback(
        message: 'Gagal menerapkan preset. Format data tidak valid.',
        color: AppColors.danger,
      );
    }
  }

  void _showLoadPresetSheet(BuildContext context) {
    final presetProvider = context.read<PresetProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Muat Preset Tersimpan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<dynamic>>(
              future: presetProvider.getSavedPresets(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('Belum ada preset tersimpan.')),
                  );
                }

                final presets = snapshot.data!;
                return Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: presets.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final preset = presets[index];
                      final payload = preset['payload'];
                      final String? presetId = preset['id'] as String?;
                      final String? presetName = preset['name'] as String?;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.display_settings_rounded,
                          color: AppColors.textSecondary,
                        ),
                        title: Text(
                          presetName ?? 'Preset',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${payload['route']} • ${payload['animation']}',
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            _applyPreset(
                              context,
                              payload,
                              presetId: presetId,
                              presetName: presetName,
                            );
                            Navigator.pop(ctx);
                          },
                          child: const Text(
                            'Pilih',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmOverwrite(BuildContext context, String presetName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Timpa Preset',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Timpa preset "$presetName" dengan pengaturan saat ini? '
          'Data lama pada preset ini akan diganti.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Batal',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final payload = buildCurrentPayload(context);
              final result = await context
                  .read<PresetProvider>()
                  .overwriteLoadedPreset(payload);
              if (context.mounted) context.showResult(result);
            },
            child: const Text(
              'Timpa',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetToDefault(BuildContext context) {
    context.read<RouteProvider>().resetSelection();
    context.read<DisplaySettingsProvider>().resetToDefault();
    context.read<PresetProvider>().clearLoadedPreset();

    context.showFeedback(
      message: 'Pengaturan berhasil direset ke default.',
      color: AppColors.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final presetProvider = context.watch<PresetProvider>();
    final bool hasLoadedPreset = presetProvider.hasLoadedPreset;

    return SectionCard(
      title: 'Preset',
      icon: Icons.bookmarks_rounded,
      trailing: TextButton.icon(
        onPressed: () => _resetToDefault(context),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.danger,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(Icons.restart_alt_rounded, size: 16),
        label: const Text(
          'Reset ke Default',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Simpan Preset',
                  icon: Icons.bookmark_add_rounded,
                  isOutline: true,
                  tintColor: AppColors.primary,
                  onTap: () => _showSavePresetDialog(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PrimaryButton(
                  label: 'Muat Preset',
                  icon: Icons.folder_open_rounded,
                  isOutline: true,
                  tintColor: AppColors.primary,
                  onTap: () => _showLoadPresetSheet(context),
                ),
              ),
            ],
          ),
          if (hasLoadedPreset) ...[
            const SizedBox(height: 8),
            PrimaryButton(
              label: 'Timpa Preset "${presetProvider.loadedPresetName ?? ''}"',
              icon: Icons.published_with_changes_rounded,
              isOutline: true,
              tintColor: AppColors.primary,
              onTap: () => _confirmOverwrite(
                context,
                presetProvider.loadedPresetName ?? 'Preset',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
