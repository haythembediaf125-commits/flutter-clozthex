import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/product_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _backup = BackupService();
  bool _loading = false;
  String? _lastMessage;
  bool? _lastSuccess;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('النسخ الاحتياطي والاستيراد/التصدير')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Status banner
          if (_lastMessage != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (_lastSuccess == true ? AppColors.success : AppColors.error).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_lastSuccess == true ? AppColors.success : AppColors.error).withOpacity(0.4)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(
                  _lastSuccess == true ? Icons.check_circle : Icons.error_outline,
                  color: _lastSuccess == true ? AppColors.success : AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  _lastMessage!,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: _lastSuccess == true ? AppColors.success : AppColors.error,
                    height: 1.5,
                  ),
                )),
                GestureDetector(
                  onTap: () => setState(() => _lastMessage = null),
                  child: Icon(Icons.close, size: 16,
                    color: _lastSuccess == true ? AppColors.success : AppColors.error),
                ),
              ]),
            ),

          // Loading indicator
          if (_loading)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withOpacity(0.3)),
              ),
              child: const Row(children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)),
                SizedBox(width: 12),
                Text('جارٍ المعالجة...', style: TextStyle(fontFamily: 'Cairo', color: AppColors.gold)),
              ]),
            ),

          // ── EXPORT ──────────────────────────────────────────────────────
          _sectionTitle('📤 تصدير البيانات'),
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'يتم الحفظ في مجلد التنزيلات:\nDownload/ClowtheX/',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          _actionCard(
            icon: Icons.backup_outlined,
            color: AppColors.gold,
            title: 'تصدير نسخة احتياطية كاملة (JSON)',
            subtitle: 'جميع البيانات: المنتجات، المبيعات، العملاء، الإعدادات',
            onTap: () => _run(() => _backup.exportFullBackup()),
          ),
          const SizedBox(height: 10),
          _actionCard(
            icon: Icons.table_chart_outlined,
            color: const Color(0xFF10B981),
            title: 'تصدير المنتجات إلى Excel',
            subtitle: 'ملف Excel بجميع المنتجات مع الأسعار والكميات',
            onTap: () => _run(() => _backup.exportProductsToExcel()),
          ),
          const SizedBox(height: 10),
          _actionCard(
            icon: Icons.receipt_long_outlined,
            color: const Color(0xFF3B82F6),
            title: 'تصدير المبيعات إلى Excel',
            subtitle: 'ملف Excel بجميع الفواتير والمبيعات',
            onTap: () => _run(() => _backup.exportSalesToExcel()),
          ),
          const SizedBox(height: 24),

          // ── IMPORT ──────────────────────────────────────────────────────
          _sectionTitle('📥 استيراد البيانات'),
          _actionCard(
            icon: Icons.restore_outlined,
            color: const Color(0xFFF59E0B),
            title: 'استيراد نسخة احتياطية (JSON)',
            subtitle: 'استعادة جميع البيانات من نسخة احتياطية سابقة\n⚠️ سيتم استبدال البيانات الحالية',
            onTap: () => _confirmImport(),
          ),
          const SizedBox(height: 10),
          _actionCard(
            icon: Icons.upload_file_outlined,
            color: const Color(0xFF10B981),
            title: 'استيراد منتجات من Excel',
            subtitle: 'استيراد قائمة المنتجات من ملف Excel',
            onTap: () => _confirmExcelImport(),
          ),
          const SizedBox(height: 24),

          // ── Excel template info ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.info_outline, color: AppColors.gold, size: 18),
                SizedBox(width: 8),
                Text('تنسيق ملف Excel للاستيراد',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ]),
              const SizedBox(height: 10),
              const Text('الصف الأول: رؤوس الأعمدة — الصفوف التالية: البيانات',
                style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              _templateRow('A', 'الاسم (مطلوب)'),
              _templateRow('B', 'الباركود'),
              _templateRow('C', 'الفئة'),
              _templateRow('D', 'المورد'),
              _templateRow('E', 'سعر الشراء'),
              _templateRow('F', 'سعر البيع'),
              _templateRow('G', 'الكمية'),
              _templateRow('H', 'الحد الأدنى'),
              _templateRow('I', 'المقاس'),
              _templateRow('J', 'اللون'),
              _templateRow('K', 'الماركة'),
            ]),
          ),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w700,
        color: AppColors.textPrimary, fontFamily: 'Cairo',
      )),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _loading ? null : onTap,
      child: Opacity(
        opacity: _loading ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                color: AppColors.textPrimary, fontSize: 14)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(
                fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 12, height: 1.4)),
            ])),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_left, size: 18, color: AppColors.textMuted),
          ]),
        ),
      ),
    );
  }

  Widget _templateRow(String col, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Container(
          width: 28, height: 20,
          decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
          child: Center(child: Text(col, style: const TextStyle(
            fontFamily: 'Cairo', color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w700))),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 12)),
      ]),
    );
  }

  // ─── Run Action ───────────────────────────────────────────────────────────

  Future<void> _run(Future<BackupResult> Function() action) async {
    setState(() { _loading = true; _lastMessage = null; _lastSuccess = null; });
    try {
      final result = await action();
      if (mounted) {
        setState(() {
          _lastMessage = result.message;
          _lastSuccess = result.success;
        });
        // Refresh all providers after successful import
        if (result.success && result.isImport) {
          _refreshAllProviders();
        }
      }
    } catch (e) {
      if (mounted) setState(() { _lastMessage = 'حدث خطأ غير متوقع: $e'; _lastSuccess = false; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _refreshAllProviders() {
    try {
      context.read<ProductProvider>().loadAll();
      context.read<SaleProvider>().loadSales();
      context.read<SettingsProvider>().load();
    } catch (_) {}
  }

  // ─── JSON Import — pick file FIRST, confirm SECOND ────────────────────────

  Future<void> _confirmImport() async {
    // Step 1: open file picker immediately
    setState(() => _loading = true);
    final file = await _backup.pickBackupFile();
    if (mounted) setState(() => _loading = false);

    if (file == null || !mounted) return; // user cancelled

    // Step 2: show confirmation AFTER file is selected
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 26),
          SizedBox(width: 10),
          Text('تأكيد الاستيراد', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'الملف المختار:\n${file.name}',
            style: const TextStyle(fontFamily: 'Cairo', color: AppColors.gold, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 10),
          const Text(
            'سيتم حذف جميع البيانات الحالية واستبدالها بالبيانات المستوردة.',
            style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 10),
          const Text(
            '⚠️ هذه العملية لا يمكن التراجع عنها.',
            style: TextStyle(fontFamily: 'Cairo', color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('نعم، استيراد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    // Step 3: import only if confirmed
    if (confirm == true && mounted) _run(() => _backup.importFromFile(file));
  }

  // ─── Excel Import — pick file FIRST, confirm SECOND ───────────────────────

  Future<void> _confirmExcelImport() async {
    // Step 1: open file picker immediately
    setState(() => _loading = true);
    final file = await _backup.pickExcelFile();
    if (mounted) setState(() => _loading = false);

    if (file == null || !mounted) return; // user cancelled

    // Step 2: confirm AFTER file is chosen
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.upload_file_outlined, color: Color(0xFF10B981), size: 26),
          SizedBox(width: 10),
          Text('استيراد من Excel', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'الملف المختار:\n${file.name}',
            style: const TextStyle(fontFamily: 'Cairo', color: Color(0xFF10B981), fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 10),
          const Text(
            'سيتم إضافة المنتجات من هذا الملف إلى قاعدة البيانات.\n\nملاحظة: المنتجات الموجودة لن تُحذف، فقط تُضاف المنتجات الجديدة.',
            style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, height: 1.5),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('استيراد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    // Step 3: import only if confirmed
    if (confirm == true && mounted) _run(() => _backup.importProductsFromExcelFile(file));
  }
}
