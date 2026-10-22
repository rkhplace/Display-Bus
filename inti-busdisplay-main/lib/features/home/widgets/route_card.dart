import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/models/operation_result.dart';
import '../../../core/models/route_model.dart';
import '../../../core/providers/route_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/feedback_extension.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/selection_sheet.dart';
import 'add_route_dialog.dart';

class RouteCard extends StatelessWidget {
  const RouteCard({super.key});

  Future<void> _showAddRouteDialog(BuildContext context) async {
    final provider = context.read<RouteProvider>();
    final result = await showDialog<OperationResult>(
      context: context,
      builder: (ctx) => AddRouteDialog(provider: provider),
    );
    if (result != null && context.mounted) {
      context.showResult(
        result,
        fallbackSuccessMessage: 'Rute berhasil ditambahkan.',
      );
    }
  }

  Future<void> _showDeleteRouteDialog(
    BuildContext context,
    RouteModel currentRoute,
    RouteProvider provider,
  ) async {
    if (provider.routes.length <= 1) {
      context.showFeedback(
        message: 'Minimal harus ada 1 rute tersisa!',
        color: AppColors.warning,
      );
      return;
    }

    final result = await showDialog<OperationResult>(
      context: context,
      builder: (ctx) => AppFormDialog(
        icon: Icons.delete_outline_rounded,
        title: 'Hapus Rute',
        subtitle: 'Tindakan ini tidak dapat dibatalkan.',
        submitLabel: 'Hapus',
        destructive: true,
        onSubmit: () => provider.deleteRoute(currentRoute),
        child: Text.rich(
          TextSpan(
            text: 'Rute ',
            children: [
              TextSpan(
                text: '"${currentRoute.fullDisplayName}"',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const TextSpan(
                text: ' akan dihapus dari server dan semua HP yang terhubung.',
              ),
            ],
          ),
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ),
    );
    if (result != null && context.mounted) context.showResult(result);
  }

  Future<void> _pickRoute(BuildContext context, RouteProvider provider) async {
    final picked = await showSelectionSheet<RouteModel>(
      context: context,
      title: 'Pilih Rute',
      selected: provider.selectedRoute,
      options: provider.routes
          .map(
            (r) => SelectionOption(
              value: r,
              badge: r.code,
              title: '${r.origin} → ${r.destination}',
            ),
          )
          .toList(),
    );
    if (picked != null) provider.setRoute(picked);
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
                child: SelectField(
                  label: '${selected.origin} → ${selected.destination}',
                  onTap: () => _pickRoute(context, routeProvider),
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
