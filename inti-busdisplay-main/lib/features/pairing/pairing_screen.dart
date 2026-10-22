import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/faded_bus_photo.dart';
import '../../core/widgets/primary_button.dart';
import '../main_navigation/main_navigation.dart';

class PairingScreen extends StatefulWidget {
  final ApiService? apiService;

  const PairingScreen({super.key, this.apiService});

  /// Panjang kode dari `npm run pair:generate` di backend.
  static const int codeLength = 8;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final TextEditingController _codeController = TextEditingController();
  late final ApiService _apiService;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService.instance;
  }

  Future<void> _submit() async {
    if (_codeController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Masukkan kode pairing terlebih dahulu.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _apiService.pairDevice(_codeController.text);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    } else {
      setState(() => _errorMessage = result.message);
    }
  }

  void _showHelp() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.card,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: appSheetShape,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(
              title: 'Cara Memasangkan',
              subtitle: 'Hubungkan HP ini ke server Smart Bus Display.',
            ),
            const _HelpStep(
              number: 1,
              text:
                  'Minta admin menjalankan "npm run pair:generate" di '
                  'server backend.',
            ),
            const _HelpStep(
              number: 2,
              text:
                  'Masukkan kode 8 karakter yang muncul. Kode hanya bisa '
                  'dipakai sekali dan berlaku 15 menit.',
            ),
            const _HelpStep(
              number: 3,
              text:
                  'Pastikan HP terhubung ke jaringan yang sama dengan server.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.dns_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Server: ${ApiService.baseUrl}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashBackground,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.softBackgroundGradient,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth > constraints.maxHeight
              ? _buildLandscape()
              : _buildPortrait(constraints),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Image.asset(
          'assets/images/logo.png',
          height: 48,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.directions_bus_rounded,
            color: AppColors.primary,
            size: 36,
          ),
        ),
        const Spacer(),
        _RoundIconButton(
          icon: Icons.help_outline_rounded,
          tooltip: 'Bantuan',
          onTap: _showHelp,
        ),
      ],
    );
  }

  Widget _welcome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Selamat Datang',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.splashTitle,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Hubungkan HP ini ke panel bus Anda.',
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Portrait: logo, sapaan, kartu, lalu foto bus selebar layar di bawah
  /// (disembunyikan saat keyboard muncul supaya tidak menimpa kartu).
  Widget _buildPortrait(BoxConstraints constraints) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final h = constraints.maxHeight;
    final photoHeight = h * (h < 700 ? 0.3 : 0.4);

    // expand: Stack setinggi layar, supaya foto menempel ke dasar layar dan
    // bukan ke dasar isi yang bisa digulir.
    return Stack(
      fit: StackFit.expand,
      children: [
        if (!keyboardOpen)
          Positioned(
            left: 0,
            right: 0,
            // Seperlima bawah foto berupa latar putih (lengkungan biru);
            // didorong keluar layar supaya bus menempel ke dasar layar.
            bottom: -photoHeight * 0.22,
            height: photoHeight * 1.22,
            child: const FadedBusPhoto(
              fadeFrom: Alignment.topCenter,
              fadeOppositeEdge: false,
              alignment: Alignment(-0.1, 0),
            ),
          ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(),
                    SizedBox(height: constraints.maxHeight * 0.07),
                    _welcome(),
                    const SizedBox(height: 20),
                    _buildCard(),
                    if (!keyboardOpen) SizedBox(height: photoHeight * 0.75),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Landscape: form di kiri, foto bus di kanan.
  Widget _buildLandscape() {
    return Row(
      children: [
        Expanded(
          flex: 11,
          child: SafeArea(
            right: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(),
                      const SizedBox(height: 12),
                      _buildCard(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const Expanded(
          flex: 9,
          child: FadedBusPhoto(
            fadeFrom: Alignment.centerLeft,
            fadeOppositeEdge: false,
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.phonelink_lock_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pasangkan Device',
                  style: GoogleFonts.poppins(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: AppColors.splashTitle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Minta admin menjalankan perintah pairing di server, '
            'lalu masukkan kode yang muncul di sini.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            maxLength: PairingScreen.codeLength,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.go,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
              _UpperCaseFormatter(),
            ],
            onChanged: (_) {
              if (_errorMessage != null) setState(() => _errorMessage = null);
            },
            onSubmitted: (_) => _submit(),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 20,
              letterSpacing: 6,
              color: AppColors.splashTitle,
            ),
            decoration: InputDecoration(
              hintText: 'KODE PAIRING',
              hintStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                letterSpacing: 5,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
              ),
              counterText: '',
              filled: true,
              fillColor: AppColors.inputFill,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryLight,
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: _errorMessage != null
                    ? const BorderSide(color: AppColors.danger)
                    : BorderSide.none,
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: _isLoading ? 'Memasangkan...' : 'Pasangkan',
              icon: Icons.link_rounded,
              gradient: AppColors.heroButtonGradient,
              isLoading: _isLoading,
              minHeight: 52,
              radius: 12,
              onTap: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.card,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Icon(icon, color: AppColors.splashTitle, size: 22),
          ),
        ),
      ),
    );
  }
}

class _HelpStep extends StatelessWidget {
  final int number;
  final String text;

  const _HelpStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
