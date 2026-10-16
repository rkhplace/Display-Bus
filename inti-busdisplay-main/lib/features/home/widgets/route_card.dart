import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/models/route_model.dart';
import '../../../core/providers/route_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/feedback_extension.dart';
import '../../../core/widgets/section_card.dart';

class RouteCard extends StatelessWidget {
  const RouteCard({super.key});

  void _showAddRouteDialog(BuildContext context) {
    final codeController = TextEditingController();
    final originController = TextEditingController();
    final destinationController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        alignment: Alignment.topCenter,
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        titlePadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        title: Text(
          'Tambah Rute Baru',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RouteFormField(
              controller: codeController,
              hint: 'Kode Rute (Cth: B5)',
            ),
            const SizedBox(height: 10),
            _RouteFormField(
              controller: originController,
              hint: 'Kota Asal (Cth: Bandung)',
            ),
            const SizedBox(height: 10),
            _RouteFormField(
              controller: destinationController,
              hint: 'Kota Tujuan (Cth: Lembang)',
            ),
          ],
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
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () async {
              final result = await context.read<RouteProvider>().addRoute(
                code: codeController.text,
                origin: originController.text,
                destination: destinationController.text,
              );

              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                context.showResult(
                  result,
                  fallbackSuccessMessage: 'Rute berhasil ditambahkan.',
                );
              }
            },
            child: const Text(
              'Simpan',
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

  void _showDeleteRouteDialog(
    BuildContext context,
    RouteModel currentRoute,
    RouteProvider provider,
  ) {
    if (provider.routes.length <= 1) {
      context.showFeedback(
        message: 'Minimal harus ada 1 rute tersisa!',
        color: AppColors.warning,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Hapus Rute',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Text(
          'Hapus "${currentRoute.fullDisplayName}"? Tindakan ini tidak dapat dibatalkan.',
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
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () async {
              final result = await provider.deleteRoute(currentRoute);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) context.showResult(result);
            },
            child: const Text(
              'Hapus',
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

  @override
  Widget build(BuildContext context) {
    final routeProvider = context.watch<RouteProvider>();
    final selected = routeProvider.selectedRoute;

    return SectionCard(
      title: 'Rute',
      icon: Icons.route_rounded,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (routeProvider.isLoadingRoutes)
            const SizedBox(
              width: 36,
              child: Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            )
          else
            CardIconButton(
              icon: Icons.sync_rounded,
              tooltip: 'Muat ulang rute dari server',
              onTap: routeProvider.refreshRoutes,
              color: routeProvider.isUsingLocalFallback
                  ? AppColors.warning
                  : AppColors.textSecondary,
            ),
          CardIconButton(
            icon: Icons.add_rounded,
            tooltip: 'Tambah rute',
            color: AppColors.primary,
            onTap: () => _showAddRouteDialog(context),
          ),
          CardIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Hapus rute ini',
            color: AppColors.danger,
            onTap: () =>
                _showDeleteRouteDialog(context, selected, routeProvider),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                height: 44,
                constraints: const BoxConstraints(minWidth: 48),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  selected.code,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<RouteModel>(
                      value: selected,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(8),
                      icon: const Icon(
                        Icons.unfold_more_rounded,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                      selectedItemBuilder: (context) => routeProvider.routes
                          .map(
                            (e) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                e.apiRouteName,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                  fontSize: 13.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      items: routeProvider.routes
                          .map(
                            (e) => DropdownMenuItem<RouteModel>(
                              value: e,
                              child: Text(
                                e.fullDisplayName,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => routeProvider.setRoute(val!),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 40,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.subtleFill,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _DirectionTab(
                    label: 'Pergi',
                    hint: '${selected.origin} → ${selected.destination}',
                    active: routeProvider.isPergi,
                    onTap: () => routeProvider.setDirection(true),
                  ),
                ),
                Expanded(
                  child: _DirectionTab(
                    label: 'Pulang',
                    hint: '${selected.destination} → ${selected.origin}',
                    active: !routeProvider.isPergi,
                    onTap: () => routeProvider.setDirection(false),
                  ),
                ),
              ],
            ),
          ),
          if (routeProvider.isUsingLocalFallback &&
              !routeProvider.isLoadingRoutes) ...[
            const SizedBox(height: 8),
            const Text(
              'Rute belum tersinkron dengan server. Tekan ikon muat ulang.',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteFormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _RouteFormField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: AppColors.subtleFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}

class _DirectionTab extends StatelessWidget {
  final String label;
  final String hint;
  final bool active;
  final VoidCallback onTap;

  const _DirectionTab({
    required this.label,
    required this.hint,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: active ? Border.all(color: AppColors.cardBorder) : null,
        ),
        alignment: Alignment.center,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              TextSpan(
                text: '  $hint',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(fontSize: 12.5),
        ),
      ),
    );
  }
}
