import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';

class ActivationScreen extends StatefulWidget {
  final VoidCallback onActivated;
  const ActivationScreen({super.key, required this.onActivated});

  static const _code = 'haythemgroupBdf(16062002)';
  static const _prefKey = 'app_activated';

  static Future<bool> isActivated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  static Future<void> setActivated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

// ─── Two-step: Step 1 = QR scan, Step 2 = Password ───────────────────────────

class _ActivationScreenState extends State<ActivationScreen>
    with TickerProviderStateMixin {
  int _step = 0; // 0 = QR scan, 1 = Password
  String? _error;
  bool _scanning = true;
  bool _qrProcessing = false;

  // Password step
  final _passCtrl = TextEditingController();
  bool _passVisible = false;
  bool _passLoading = false;

  // Animation
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ─── QR Step ──────────────────────────────────────────────────────────────

  Future<void> _onQrDetected(String? rawValue) async {
    if (!_scanning || rawValue == null || _qrProcessing) return;
    setState(() { _scanning = false; _qrProcessing = true; _error = null; });

    await Future.delayed(const Duration(milliseconds: 600));

    if (rawValue.trim() == ActivationScreen._code) {
      // Valid QR → move to password step
      if (mounted) {
        await _fadeCtrl.reverse();
        setState(() {
          _step = 1;
          _error = null;
          _qrProcessing = false;
          _scanning = true;
        });
        _fadeCtrl.forward();
      }
    } else {
      if (mounted) {
        setState(() {
          _error = 'رمز QR غير صحيح. تأكد من استخدام رمز التفعيل الصحيح.';
          _qrProcessing = false;
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() { _scanning = true; _error = null; });
      }
    }
  }

  // ─── Password Step ────────────────────────────────────────────────────────

  Future<void> _validatePassword() async {
    final entered = _passCtrl.text.trim();
    if (entered.isEmpty) {
      setState(() => _error = 'الرجاء إدخال كلمة السر');
      return;
    }
    if (entered != ActivationScreen._code) {
      setState(() => _error = 'كلمة السر غير صحيحة. حاول مرة أخرى.');
      return;
    }
    setState(() { _passLoading = true; _error = null; });
    await ActivationScreen.setActivated();
    if (mounted) widget.onActivated();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(children: [
            _buildHeader(),
            _buildStepIndicator(),
            if (_error != null) _buildErrorBanner(),
            Expanded(
              child: _step == 0 ? _buildQrStep() : _buildPasswordStep(),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      child: Column(children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: const Icon(Icons.store_rounded, color: Colors.black, size: 40),
        ),
        const SizedBox(height: 12),
        const Text('ClowtheX', style: TextStyle(
          fontFamily: 'Cairo', fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.gold,
        )),
        const Text('تفعيل التطبيق', style: TextStyle(
          fontFamily: 'Cairo', fontSize: 13, color: AppColors.textSecondary,
        )),
      ]),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Row(children: [
        _stepDot(1, _step >= 0, _step > 0, 'QR كود'),
        Expanded(child: Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          color: _step > 0 ? AppColors.gold : AppColors.divider,
        )),
        _stepDot(2, _step >= 1, false, 'كلمة السر'),
      ]),
    );
  }

  Widget _stepDot(int num, bool active, bool done, String label) {
    return Column(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: active ? AppColors.gold : AppColors.surfaceVariant,
          shape: BoxShape.circle,
          border: Border.all(color: active ? AppColors.gold : AppColors.cardBorder, width: 2),
        ),
        child: Center(child: done
            ? const Icon(Icons.check, size: 18, color: Colors.black)
            : Text('$num', style: TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 14,
                color: active ? Colors.black : AppColors.textMuted,
              ))),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(
        fontFamily: 'Cairo', fontSize: 11,
        color: active ? AppColors.gold : AppColors.textMuted,
        fontWeight: active ? FontWeight.w700 : FontWeight.normal,
      )),
    ]);
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withOpacity(0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(_error!, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.error, fontSize: 12))),
      ]),
    );
  }

  // ─── Step 1: QR Scan ──────────────────────────────────────────────────────

  Widget _buildQrStep() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.qr_code, color: AppColors.gold, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('امسح رمز QR الخاص بالتفعيل',
              style: TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(alignment: Alignment.center, children: [
              MobileScanner(
                onDetect: (c) {
                  if (c.barcodes.isNotEmpty) _onQrDetected(c.barcodes.first.rawValue);
                },
              ),
              // Gold scan frame
              _buildScanFrame(),
              if (_qrProcessing)
                Container(
                  color: Colors.black54,
                  child: const Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.gold),
                      SizedBox(height: 12),
                      Text('جارٍ التحقق...', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                    ],
                  )),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(
              _scanning ? Icons.qr_code_scanner : Icons.hourglass_top,
              color: AppColors.gold, size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              _scanning ? 'الكاميرا جاهزة للمسح...' : 'جارٍ التحقق من الرمز...',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildScanFrame() {
    const gold = AppColors.gold;
    const s = 200.0;
    const corner = 28.0;
    const thick = 4.0;
    return SizedBox(width: s, height: s, child: CustomPaint(painter: _CornerPainter(gold, corner, thick)));
  }

  // ─── Step 2: Password ─────────────────────────────────────────────────────

  Widget _buildPasswordStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 20),
            const SizedBox(width: 10),
            const Expanded(child: Text('تم التحقق من رمز QR بنجاح ✓\nأدخل الآن كلمة سر التفعيل للمتابعة',
              style: TextStyle(fontFamily: 'Cairo', color: AppColors.success, fontSize: 13, height: 1.5))),
          ]),
        ),
        const SizedBox(height: 24),
        const Text('كلمة سر التفعيل', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: _passCtrl,
          obscureText: !_passVisible,
          textAlign: TextAlign.right,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, color: AppColors.textPrimary),
          onSubmitted: (_) => _validatePassword(),
          decoration: InputDecoration(
            hintText: '••••••••••••••',
            hintStyle: const TextStyle(color: AppColors.textMuted, letterSpacing: 4),
            filled: true,
            fillColor: AppColors.inputBackground,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.inputBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.inputBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.gold, width: 2)),
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.gold),
            suffixIcon: IconButton(
              icon: Icon(_passVisible ? Icons.visibility_off : Icons.visibility, color: AppColors.textMuted, size: 20),
              onPressed: () => setState(() => _passVisible = !_passVisible),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _passLoading ? null : _validatePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _passLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Text('تفعيل التطبيق', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () async {
            await _fadeCtrl.reverse();
            setState(() { _step = 0; _error = null; _passCtrl.clear(); _scanning = true; });
            _fadeCtrl.forward();
          },
          icon: const Icon(Icons.arrow_back, size: 16, color: AppColors.textMuted),
          label: const Text('العودة لمسح QR', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 13)),
        ),
        const SizedBox(height: 24),
        Center(child: Column(children: [
          const Icon(Icons.support_agent, color: AppColors.textMuted, size: 28),
          const SizedBox(height: 6),
          const Text('تواصل مع الموزع للحصول على بيانات التفعيل',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 12)),
        ])),
      ]),
    );
  }
}

// ─── Custom corner painter for QR frame ──────────────────────────────────────

class _CornerPainter extends CustomPainter {
  final Color color;
  final double cornerSize;
  final double thickness;

  const _CornerPainter(this.color, this.cornerSize, this.thickness);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final w = size.width;
    final h = size.height;
    final c = cornerSize;

    // Top-left
    canvas.drawLine(Offset(0, c), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(c, 0), paint);
    // Top-right
    canvas.drawLine(Offset(w - c, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, c), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, h - c), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(c, h), paint);
    // Bottom-right
    canvas.drawLine(Offset(w - c, h), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h - c), Offset(w, h), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
