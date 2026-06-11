import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/sale.dart';
import '../../providers/sale_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/pdf_service.dart';
import '../../services/backup_service.dart';
import '../../widgets/common/stat_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _dailyChart = [];
  List<Map<String, dynamic>> _topProducts = [];
  List<Sale> _sales = [];
  Map<String, dynamic> _profitSummary = {};
  List<Map<String, dynamic>> _profitChart = [];
  List<Map<String, dynamic>> _shopHealthChart = [];
  bool _loading = true;

  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final sale = context.read<SaleProvider>();
      final [chart, top, sales, profit, profitData, healthData] = await Future.wait([
        sale.getDailySalesChart(days: 30),
        sale.getTopProducts(limit: 10),
        sale.getSalesByDateRange(_from, _to),
        sale.getProfitSummary(),
        sale.getProfitByDay(days: 30),
        sale.getShopHealthChart(days: 30),
      ]);
      _dailyChart = chart as List<Map<String, dynamic>>;
      _topProducts = top as List<Map<String, dynamic>>;
      _sales = sales as List<Sale>;
      _profitSummary = profit as Map<String, dynamic>;
      _profitChart = profitData as List<Map<String, dynamic>>;
      _shopHealthChart = healthData as List<Map<String, dynamic>>;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final currency = settings.currency;

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'المبيعات'),
            Tab(text: 'الأرباح'),
            Tab(text: 'حالة المحل'),
            Tab(text: 'المنتجات'),
            Tab(text: 'المخزون'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            color: AppColors.surfaceVariant,
            onSelected: (v) async {
              final backup = BackupService();
              switch (v) {
                case 'print_sales':
                  await PdfService.printSalesReport(_sales, {}, currency: currency,
                    period: '${DateFormat('yyyy/MM/dd').format(_from)} - ${DateFormat('yyyy/MM/dd').format(_to)}');
                  break;
                case 'export_sales':
                  await backup.exportSalesToExcel(from: _from, to: _to);
                  break;
                case 'print_inventory':
                  final products = context.read<ProductProvider>().allProducts;
                  await PdfService.printInventoryReport(products, currency: currency);
                  break;
                case 'export_inventory':
                  await backup.exportProductsToExcel();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'print_sales', child: Row(children: [Icon(Icons.print, size: 18, color: AppColors.gold), SizedBox(width: 8), Text('طباعة تقرير المبيعات', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary))])),
              PopupMenuItem(value: 'export_sales', child: Row(children: [Icon(Icons.table_chart, size: 18, color: AppColors.success), SizedBox(width: 8), Text('تصدير المبيعات Excel', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary))])),
              PopupMenuDivider(),
              PopupMenuItem(value: 'print_inventory', child: Row(children: [Icon(Icons.print, size: 18, color: AppColors.gold), SizedBox(width: 8), Text('طباعة تقرير المخزون', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary))])),
              PopupMenuItem(value: 'export_inventory', child: Row(children: [Icon(Icons.table_chart, size: 18, color: AppColors.success), SizedBox(width: 8), Text('تصدير المخزون Excel', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary))])),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [Icon(Icons.download_outlined, color: AppColors.gold), Text(' تصدير', style: TextStyle(fontFamily: 'Cairo', color: AppColors.gold))]),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : TabBarView(
              controller: _tab,
              children: [
                _SalesTab(sales: _sales, dailyChart: _dailyChart, currency: currency, from: _from, to: _to,
                  onDateChanged: (f, t) => setState(() { _from = f; _to = t; _loadData(); })),
                _ProfitTab(profitSummary: _profitSummary, profitChart: _profitChart, currency: currency,
                  onRefresh: _loadData),
                _ShopHealthTab(healthChart: _shopHealthChart, currency: currency),
                _TopProductsTab(topProducts: _topProducts, currency: currency),
                _InventoryTab(currency: currency),
              ],
            ),
    );
  }
}

class _SalesTab extends StatelessWidget {
  final List<Sale> sales;
  final List<Map<String, dynamic>> dailyChart;
  final String currency;
  final DateTime from, to;
  final void Function(DateTime, DateTime) onDateChanged;

  const _SalesTab({required this.sales, required this.dailyChart, required this.currency, required this.from, required this.to, required this.onDateChanged});

  @override
  Widget build(BuildContext context) {
    final total = sales.fold<double>(0, (s, e) => s + e.total);
    final completed = sales.where((s) => s.status == SaleStatus.completed).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Date filter
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: DateTimeRange(start: from, end: to),
                builder: (ctx, child) => Theme(data: Theme.of(ctx), child: child!),
              );
              if (range != null) onDateChanged(range.start, range.end);
            },
            icon: const Icon(Icons.date_range, size: 16),
            label: Text('${DateFormat('yyyy/MM/dd').format(from)} - ${DateFormat('yyyy/MM/dd').format(to)}',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
          )),
        ]),
        const SizedBox(height: 16),

        // Stats
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.3,
          children: [
            StatCard(title: 'إجمالي المبيعات', value: '${total.toStringAsFixed(2)} $currency', icon: Icons.monetization_on_outlined, color: AppColors.gold),
            StatCard(title: 'عدد الفواتير', value: '$completed', icon: Icons.receipt_outlined, color: AppColors.info),
          ],
        ),
        const SizedBox(height: 20),

        // Chart
        if (dailyChart.isNotEmpty) ...[
          const Text('مبيعات آخر 30 يوم', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Cairo')),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: LineChart(LineChartData(
              backgroundColor: AppColors.card,
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: AppColors.divider, strokeWidth: 1)),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 48, getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textMuted)))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= dailyChart.length || i % 5 != 0) return const SizedBox();
                  return Text(dailyChart[i]['sale_date']?.toString().substring(5) ?? '', style: const TextStyle(fontFamily: 'Cairo', fontSize: 9, color: AppColors.textMuted));
                })),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [LineChartBarData(
                spots: dailyChart.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['revenue'] as num).toDouble())).toList(),
                isCurved: true,
                color: AppColors.gold,
                barWidth: 2.5,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: AppColors.gold.withOpacity(0.1)),
              )],
            )),
          ),
          const SizedBox(height: 20),
        ],

        // Sales list
        const Text('الفواتير', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Cairo')),
        const SizedBox(height: 8),
        ...sales.map((s) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.cardBorder)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.invoiceNumber, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text(DateFormat('yyyy/MM/dd HH:mm').format(s.createdAt), style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted)),
              if (s.customerName != null) Text(s.customerName!, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${s.total.toStringAsFixed(2)} $currency', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: AppColors.gold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: s.status == SaleStatus.completed ? AppColors.success.withOpacity(0.15) : AppColors.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(s.statusAr, style: TextStyle(fontFamily: 'Cairo', fontSize: 11,
                  color: s.status == SaleStatus.completed ? AppColors.success : AppColors.error)),
              ),
            ]),
          ]),
        )),
      ]),
    );
  }
}

// ── الأرباح Tab ────────────────────────────────────────────────────────────────

class _ProfitTab extends StatelessWidget {
  final Map<String, dynamic> profitSummary;
  final List<Map<String, dynamic>> profitChart;
  final String currency;
  final VoidCallback onRefresh;

  const _ProfitTab({
    required this.profitSummary,
    required this.profitChart,
    required this.currency,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final revenue = (profitSummary['total_revenue'] as num?)?.toDouble() ?? 0;
    final cost = (profitSummary['total_cost'] as num?)?.toDouble() ?? 0;
    final profit = (profitSummary['total_profit'] as num?)?.toDouble() ?? 0;
    final margin = (profitSummary['profit_margin'] as num?)?.toDouble() ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Summary stats
        Row(children: [
          Expanded(child: SizedBox(height: 100, child: StatCard(
            title: 'إجمالي الإيرادات',
            value: '${revenue.toStringAsFixed(2)} $currency',
            icon: Icons.trending_up,
            color: AppColors.success,
          ))),
          const SizedBox(width: 12),
          Expanded(child: SizedBox(height: 100, child: StatCard(
            title: 'إجمالي التكاليف',
            value: '${cost.toStringAsFixed(2)} $currency',
            icon: Icons.money_off,
            color: AppColors.error,
          ))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: SizedBox(height: 100, child: StatCard(
            title: 'صافي الربح',
            value: '${profit.toStringAsFixed(2)} $currency',
            icon: Icons.account_balance,
            color: profit >= 0 ? AppColors.gold : AppColors.error,
          ))),
          const SizedBox(width: 12),
          Expanded(child: SizedBox(height: 100, child: StatCard(
            title: 'نسبة الربح',
            value: '${margin.toStringAsFixed(1)}%',
            icon: Icons.percent,
            color: margin > 20 ? AppColors.success : (margin > 10 ? AppColors.warning : AppColors.error),
          ))),
        ]),
        const SizedBox(height: 24),

        // Chart
        if (profitChart.isNotEmpty) ...[
          const Text('منحنى الأرباح (30 يوم)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Cairo')),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: LineChart(LineChartData(
              backgroundColor: AppColors.card,
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: AppColors.divider, strokeWidth: 1)),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 52,
                  getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontFamily: 'Cairo', fontSize: 9, color: AppColors.textMuted)))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= profitChart.length || i % 7 != 0) return const SizedBox();
                  final date = profitChart[i]['sale_date']?.toString() ?? '';
                  return Text(date.isNotEmpty ? date.substring(5) : '', style: const TextStyle(fontFamily: 'Cairo', fontSize: 9, color: AppColors.textMuted));
                })),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                // Revenue line
                LineChartBarData(
                  spots: profitChart.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['revenue'] as num?)?.toDouble() ?? 0)).toList(),
                  isCurved: true, color: AppColors.success, barWidth: 2, dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: AppColors.success.withOpacity(0.1)),
                ),
                // Profit line
                LineChartBarData(
                  spots: profitChart.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['profit'] as num?)?.toDouble() ?? 0)).toList(),
                  isCurved: true, color: AppColors.gold, barWidth: 2, dotData: const FlDotData(show: false),
                ),
              ],
            )),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _LegendItem(color: AppColors.success, label: 'الإيرادات'),
            const SizedBox(width: 16),
            _LegendItem(color: AppColors.gold, label: 'صافي الربح'),
          ]),
          const SizedBox(height: 24),
        ],

        // Store status card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: profit >= 0
                  ? [AppColors.success.withOpacity(0.2), AppColors.info.withOpacity(0.1)]
                  : [AppColors.error.withOpacity(0.2), AppColors.warning.withOpacity(0.1)],
              begin: Alignment.topRight, end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: profit >= 0 ? AppColors.success.withOpacity(0.3) : AppColors.error.withOpacity(0.3)),
          ),
          child: Column(children: [
            Icon(profit >= 0 ? Icons.trending_up : Icons.trending_down,
              size: 48, color: profit >= 0 ? AppColors.success : AppColors.error),
            const SizedBox(height: 12),
            Text(
              profit >= 0 ? 'الحالة ممتازة' : 'يحتاج تحسين',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w800,
                color: profit >= 0 ? AppColors.success : AppColors.error),
            ),
            const SizedBox(height: 8),
            Text(
              profit >= 0
                  ? 'المحل يحقق أرباحاً جيدة. نسبة الربح ${margin.toStringAsFixed(1)}%'
                  : 'المحل يعمل بخسارة. راجع التكاليف والأسعار',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 12, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted)),
    ]);
  }
}

class _TopProductsTab extends StatelessWidget {
  final List<Map<String, dynamic>> topProducts;
  final String currency;
  const _TopProductsTab({required this.topProducts, required this.currency});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('أكثر المنتجات مبيعاً', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Cairo')),
        const SizedBox(height: 12),
        ...topProducts.asMap().entries.map((e) {
          final p = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.cardBorder)),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text('${e.key + 1}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: AppColors.gold))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['product_name'] as String, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text('${p['total_sold']} وحدة مباعة', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted)),
              ])),
              Text('${(p['total_revenue'] as num).toStringAsFixed(2)} $currency',
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.gold)),
            ]),
          );
        }),
      ],
    );
  }
}

class _InventoryTab extends StatelessWidget {
  final String currency;
  const _InventoryTab({required this.currency});

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>().allProducts;
    final totalValue = products.fold<double>(0, (s, p) => s + p.quantity * p.purchasePrice);
    final totalSaleValue = products.fold<double>(0, (s, p) => s + p.quantity * p.salePrice);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.3,
          children: [
            StatCard(title: 'قيمة المخزون (تكلفة)', value: '${totalValue.toStringAsFixed(2)} $currency', icon: Icons.account_balance_wallet_outlined, color: AppColors.info),
            StatCard(title: 'قيمة المخزون (بيع)', value: '${totalSaleValue.toStringAsFixed(2)} $currency', icon: Icons.trending_up, color: AppColors.success),
            StatCard(title: 'مخزون منخفض', value: '${products.where((p) => p.isLowStock && !p.isOutOfStock).length}', icon: Icons.warning_amber_outlined, color: AppColors.warning),
            StatCard(title: 'نفذ المخزون', value: '${products.where((p) => p.isOutOfStock).length}', icon: Icons.remove_shopping_cart_outlined, color: AppColors.error),
          ],
        ),
        const SizedBox(height: 20),
        const Text('المنتجات منخفضة المخزون', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Cairo')),
        const SizedBox(height: 12),
        ...products.where((p) => p.isLowStock).map((p) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.isOutOfStock ? AppColors.error.withOpacity(0.5) : AppColors.warning.withOpacity(0.5)),
          ),
          child: Row(children: [
            Icon(p.isOutOfStock ? Icons.remove_shopping_cart : Icons.warning_amber,
              color: p.isOutOfStock ? AppColors.error : AppColors.warning),
            const SizedBox(width: 12),
            Expanded(child: Text(p.name, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary))),
            Text('${p.quantity}/${p.minQuantity}',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                color: p.isOutOfStock ? AppColors.error : AppColors.warning)),
          ]),
        )),
      ]),
    );
  }
}

// ── حالة المحل Tab ──────────────────────────────────────────────────────────

class _ShopHealthTab extends StatelessWidget {
  final List<Map<String, dynamic>> healthChart;
  final String currency;

  const _ShopHealthTab({required this.healthChart, required this.currency});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('نظرة عامة على صحة المحل',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Cairo')),
        const SizedBox(height: 8),
        const Text('يوضح هذا المنحنى العلاقة بين المبيعات، المصروفات، والديون الصادرة لتقييم أداء المحل العام.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontFamily: 'Cairo')),
        const SizedBox(height: 24),

        if (healthChart.isNotEmpty) ...[
          SizedBox(
            height: 300,
            child: LineChart(LineChartData(
              backgroundColor: AppColors.card,
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: AppColors.divider, strokeWidth: 1)),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textMuted)))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= healthChart.length || i % 5 != 0) return const SizedBox();
                  return Text(healthChart[i]['date']?.toString().substring(5) ?? '', style: const TextStyle(fontFamily: 'Cairo', fontSize: 9, color: AppColors.textMuted));
                })),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                // مبيعات
                LineChartBarData(
                  spots: healthChart.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['revenue'] as num).toDouble())).toList(),
                  isCurved: true, color: AppColors.success, barWidth: 3, dotData: const FlDotData(show: false),
                ),
                // مصروفات
                LineChartBarData(
                  spots: healthChart.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['expenses'] as num).toDouble())).toList(),
                  isCurved: true, color: AppColors.error, barWidth: 3, dotData: const FlDotData(show: false),
                ),
                // ديون
                LineChartBarData(
                  spots: healthChart.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['debts'] as num).toDouble())).toList(),
                  isCurved: true, color: AppColors.warning, barWidth: 3, dotData: const FlDotData(show: false),
                ),
              ],
            )),
          ),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _LegendItem(color: AppColors.success, label: 'المبيعات'),
            const SizedBox(width: 16),
            _LegendItem(color: AppColors.error, label: 'المصروفات'),
            const SizedBox(width: 16),
            _LegendItem(color: AppColors.warning, label: 'الديون لنا'),
          ]),
        ] else
          const Center(child: Padding(
            padding: EdgeInsets.all(40),
            child: Text('لا توجد بيانات كافية لعرض الرسم البياني', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted)),
          )),
        
        const SizedBox(height: 32),
        const Text('بوابة حساب الفائدة والأرباح المتوقعة',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Cairo')),
        const SizedBox(height: 12),
        _ProfitCalculator(currency: currency),
      ]),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
    ]);
  }
}

class _ProfitCalculator extends StatefulWidget {
  final String currency;
  const _ProfitCalculator({required this.currency});
  @override
  State<_ProfitCalculator> createState() => _ProfitCalculatorState();
}

class _ProfitCalculatorState extends State<_ProfitCalculator> {
  final _amountController = TextEditingController();
  final _marginController = TextEditingController();
  double _result = 0;

  void _calculate() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final margin = double.tryParse(_marginController.text) ?? 0;
    setState(() {
      _result = amount * (margin / 100);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
      child: Column(children: [
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'المبلغ المستثمر / رأس المال', labelStyle: TextStyle(fontFamily: 'Cairo')),
          onChanged: (_) => _calculate(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _marginController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'نسبة الربح المتوقعة (%)', labelStyle: TextStyle(fontFamily: 'Cairo')),
          onChanged: (_) => _calculate(),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('الربح الصافي المتوقع:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            Text('${_result.toStringAsFixed(2)} ${widget.currency}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.gold, fontSize: 18)),
          ]),
        ),
      ]),
    );
  }
}
