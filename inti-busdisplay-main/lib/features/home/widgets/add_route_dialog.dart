import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/route_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_dialog.dart';

/// Form tambah rute: kode, kota asal, kota tujuan (bisa ditukar), dan
/// pratinjau teks panel untuk arah Pergi dan Pulang. Ditutup dengan
/// `OperationResult` sukses dari [RouteProvider.addRoute]; bila gagal, pesan
/// tampil di dalam dialog dan isian tetap ada.
class AddRouteDialog extends StatefulWidget {
  final RouteProvider provider;

  const AddRouteDialog({super.key, required this.provider});

  @override
  State<AddRouteDialog> createState() => _AddRouteDialogState();
}

class _AddRouteDialogState extends State<AddRouteDialog> {
  final _codeController = TextEditingController();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final c in [
      _codeController,
      _originController,
      _destinationController,
    ]) {
      c.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  void _swap() {
    final origin = _originController.text;
    _originController.text = _destinationController.text;
    _destinationController.text = origin;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  /// Teks seperti yang tampil di panel, mis. "B5 | BANDUNG → LEMBANG".
  String _panelText(String from, String to, String fromHint, String toHint) {
    final code = _codeController.text.trim();
    final c = code.isEmpty ? 'KODE' : code.toUpperCase();
    final a = from.trim().isEmpty ? fromHint : from.trim().toUpperCase();
    final b = to.trim().isEmpty ? toHint : to.trim().toUpperCase();
    return '$c | $a → $b';
  }

  @override
  Widget build(BuildContext context) {
    final origin = _originController.text;
    final destination = _destinationController.text;

    return AppFormDialog(
      icon: Icons.add_road_rounded,
      title: 'Tambah Rute Baru',
      subtitle: 'Rute disimpan di server dan muncul di semua HP.',
      submitLabel: 'Simpan',
      onSubmit: () => widget.provider.addRoute(
        code: _codeController.text,
        origin: _originController.text,
        destination: _destinationController.text,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const FieldLabel('Kode Rute'),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            maxLength: RouteProvider.maxCodeLength,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Cth: B5',
              counterText: '',
              prefixIcon: Icon(Icons.tag_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 14),
          const FieldLabel('Asal & Tujuan'),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    TextField(
                      controller: _originController,
                      textCapitalization: TextCapitalization.words,
                      maxLength: RouteProvider.maxCityLength,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'Kota asal (Cth: Bandung)',
                        counterText: '',
                        prefixIcon: Icon(
                          Icons.trip_origin_rounded,
                          size: 18,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _destinationController,
                      textCapitalization: TextCapitalization.words,
                      maxLength: RouteProvider.maxCityLength,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        hintText: 'Kota tujuan (Cth: Lembang)',
                        counterText: '',
                        prefixIcon: Icon(
                          Icons.location_on_rounded,
                          size: 20,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Tukar asal dan tujuan',
                child: Material(
                  color: AppColors.card,
                  shape: const CircleBorder(
                    side: BorderSide(color: AppColors.cardBorder),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _swap,
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.swap_vert_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const FieldLabel('Pratinjau di Panel'),
          _PanelPreviewLine(
            label: 'Pergi',
            text: _panelText(origin, destination, 'ASAL', 'TUJUAN'),
          ),
          const SizedBox(height: 6),
          _PanelPreviewLine(
            label: 'Pulang',
            text: _panelText(destination, origin, 'TUJUAN', 'ASAL'),
          ),
        ],
      ),
    );
  }
}

/// Satu baris pratinjau teks panel LED (latar gelap, huruf kuning).
class _PanelPreviewLine extends StatelessWidget {
  final String label;
  final String text;

  const _PanelPreviewLine({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.ledBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: AppColors.ledText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
