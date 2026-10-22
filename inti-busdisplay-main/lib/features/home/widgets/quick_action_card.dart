import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/models/operation_result.dart';
import '../../../core/providers/display_settings_provider.dart';
import '../../../core/providers/preset_provider.dart';
import '../../../core/providers/route_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/display_payload_builder.dart';
import '../../../core/utils/feedback_extension.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_sheet.dart';
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

  Future<void> _showSavePresetDialog(BuildContext context) async {
    final presetProvider = context.read<PresetProvider>();
    final payload = buildCurrentPayload(context);
    final nameController = TextEditingController();

    final result = await showDialog<OperationResult>(
      context: context,
      builder: (ctx) => AppFormDialog(
        icon: Icons.bookmark_add_rounded,
        title: 'Simpan Preset',
        subtitle: 'Simpan rute dan pengaturan tampilan saat ini.',
        submitLabel: 'Simpan',
        onSubmit: () async {
          final name = nameController.text.trim();
          if (name.isEmpty) {
            return OperationResult.failure('Nama preset wajib diisi.');
          }
          return presetProvider.saveCurrentPreset(name, payload);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const FieldLabel('Nama Preset'),
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'Cth: Pagi Hari',
                prefixIcon: Icon(Icons.label_outline_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            _PresetSummary(payload: payload),
          ],
        ),
      ),
    );

    if (result != null && context.mounted) {
      context.showResult(
        result,
        fallbackSuccessMessage: 'Preset berhasil disimpan!',
      );
    }
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
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.card,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: appSheetShape,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(
              title: 'Muat Preset',
              subtitle: 'Pilih preset untuk diterapkan ke pengaturan.',
            ),
            Flexible(
              child: FutureBuilder<List<dynamic>>(
                future: presetProvider.getSavedPresets(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SheetMessage(
                      icon: Icons.bookmarks_outlined,
                      message: 'Belum ada preset tersimpan.',
                    );
                  }

                  final presets = snapshot.data!;
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: presets.length,
                    itemBuilder: (context, index) {
                      final preset = presets[index];
                      final payload = preset['payload'];
                      final String? presetId = preset['id'] as String?;
                      final String? presetName = preset['name'] as String?;

                      return SheetListTile(
                        icon: Icons.bookmark_rounded,
                        title: presetName ?? 'Preset',
                        subtitle:
                            '${payload['route']} • ${payload['animation']}',
                        action: SheetActionButton(
                          label: 'Pilih',
                          onPressed: () {
                            _applyPreset(
                              context,
                              payload,
                              presetId: presetId,
                              presetName: presetName,
                            );
                            Navigator.pop(ctx);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmOverwrite(
    BuildContext context,
    String presetName,
  ) async {
    final presetProvider = context.read<PresetProvider>();
    final payload = buildCurrentPayload(context);

    final result = await showDialog<OperationResult>(
      context: context,
      builder: (ctx) => AppFormDialog(
        icon: Icons.published_with_changes_rounded,
        title: 'Timpa Preset',
        subtitle: 'Data lama pada preset ini akan diganti.',
        submitLabel: 'Timpa',
        onSubmit: () => presetProvider.overwriteLoadedPreset(payload),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              TextSpan(
                text: 'Ganti isi preset ',
                children: [
                  TextSpan(
                    text: '"$presetName"',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const TextSpan(text: ' dengan pengaturan berikut?'),
                ],
              ),
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            _PresetSummary(payload: payload),
          ],
        ),
      ),
    );

    if (result != null && context.mounted) context.showResult(result);
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

/// Ringkasan isi preset (rute, arah, animasi, slider) di dialog simpan/timpa.
class _PresetSummary extends StatelessWidget {
  final Map<String, dynamic> payload;

  const _PresetSummary({required this.payload});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.subtleFill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'YANG DISIMPAN',
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            icon: Icons.route_rounded,
            text: '${payload['route']} (${payload['direction']})',
          ),
          _SummaryRow(
            icon: Icons.animation_rounded,
            text: '${payload['animation']}',
          ),
          _SummaryRow(
            icon: Icons.tune_rounded,
            text:
                'Kecepatan ${payload['speed']} • Kecerahan '
                '${payload['brightness']} • Ukuran ${payload['fontSize']}',
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SummaryRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
