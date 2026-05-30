import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/product_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common/stat_card.dart';
import '../inventory/inventory_screen.dart';
import '../pos/pos_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../backup/backup_screen.dart';
import '../debts/debts_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _pages = const [
    _DashboardPage(),
    InventoryScreen(),
    PosScreen(),
    ReportsScreen(),
    DebtsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final products = context.read<ProductProvider>();
    final sales = context.read<SaleProvider>();
    await Future.wait([products.loadAll(), sales.loadSales()]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          backgroundColor: AppColors.sidebar,
          indicatorColor: AppColors.gold.withOpacity(0.2),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'المخزون'),
            NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: 'البيع'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'التقارير'),
            NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'الديون'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
          ],
        ),
      ),
    );
  }
}

class _DashboardPage extends StatefulWidget {
  const _DashboardPage();

  @override
  State<_DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<_DashboardPage> {
  Map<String, dynamic> _todayStats = {};
  Map<String, dynamic> _inventoryStats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final sale = context.read<SaleProvider>();
      final product = context.read<ProductProvider>();
      final [t, i] = await Future.wait([sale.getTodayStats(), product.getInventoryStats()]);
      _todayStats = t;
      _inventoryStats = i;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final products = context.watch<ProductProvider>();
    final currency = settings.currency;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(settings.storeName),
        actions: [
          IconButton(
            icon: const Icon(Icons.backup_outlined),
            onPressed: () {
              if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen()));
            },
            tooltip: 'النسخ الاحتياطي',
          ),
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _loadStats),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : RefreshIndicator(
              color: AppColors.gold,
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Today's Stats
                    const Text('مبيعات اليوم',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Cairo')),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        StatCard(
                          title: 'إجمالي المبيعات',
                          value: '${(_todayStats['total_revenue'] as num? ?? 0).toStringAsFixed(2)} $currency',
                          icon: Icons.monetization_on_outlined,
                          color: AppColors.gold,
                        ),
                        StatCard(
                          title: 'عدد الفواتير',
                          value: '${_todayStats['total_sales'] ?? 0}',
                          icon: Icons.receipt_outlined,
                          color: AppColors.info,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Inventory Stats
                    const Text('المخزون',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Cairo')),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        StatCard(
                          title: 'إجمالي المنتجات',
                          value: '${_inventoryStats['total_products'] ?? 0}',
                          icon: Icons.inventory_2_outlined,
                          color: AppColors.info,
                        ),
                        StatCard(
                          title: 'قيمة المخزون',
                          value: '${(_inventoryStats['total_cost_value'] as num? ?? 0).toStringAsFixed(0)} $currency',
                          icon: Icons.account_balance_wallet_outlined,
                          color: AppColors.success,
                        ),
                        StatCard(
                          title: 'مخزون منخفض',
                          value: '${_inventoryStats['low_stock'] ?? 0}',
                          icon: Icons.warning_amber_outlined,
                          color: AppColors.warning,
                        ),
                        StatCard(
                          title: 'نفذ المخزون',
                          value: '${_inventoryStats['out_of_stock'] ?? 0}',
                          icon: Icons.remove_shopping_cart_outlined,
                          color: AppColors.error,
                        ),
                      ],
                    ),

                    // Low stock alert
                    if (products.lowStockProducts.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text('تنبيهات المخزون',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Cairo')),
                      const SizedBox(height: 12),
                      ...products.lowStockProducts.take(5).map((p) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: p.isOutOfStock ? AppColors.error.withOpacity(0.5) : AppColors.warning.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            Icon(p.isOutOfStock ? Icons.remove_shopping_cart : Icons.warning_amber,
                              color: p.isOutOfStock ? AppColors.error : AppColors.warning, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(p.name, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary))),
                            Text('${p.quantity} قطعة',
                              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                                color: p.isOutOfStock ? AppColors.error : AppColors.warning)),
                          ],
                        ),
                      )),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }
}
