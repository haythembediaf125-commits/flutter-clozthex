import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common/product_card.dart';
import 'add_product_screen.dart';
import '../../models/product.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchCtrl = TextEditingController();
  bool _gridView = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('المخزون'),
        actions: [
          IconButton(
            icon: Icon(_gridView ? Icons.list : Icons.grid_view),
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.loadAll(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search + Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: provider.search,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'ابحث بالاسم أو الباركود...',
                      hintStyle: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted),
                      prefixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppColors.textMuted),
                              onPressed: () {
                                _searchCtrl.clear();
                                provider.search('');
                              },
                            )
                          : const Icon(Icons.search, color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.inputBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.inputBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.gold),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Category chips
          if (provider.categories.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _categoryChip(context, null, 'الكل', provider),
                  ...provider.categories.map((c) => _categoryChip(context, c.id, c.name, provider)),
                ],
              ),
            ),

          // Product count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('${provider.products.length} منتج',
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontFamily: 'Cairo')),
              ],
            ),
          ),

          // Product list
          Expanded(
            child: provider.loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                : provider.products.isEmpty
                    ? Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textMuted),
                          const SizedBox(height: 16),
                          const Text('لا توجد منتجات', style: TextStyle(fontSize: 16, color: AppColors.textMuted, fontFamily: 'Cairo')),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _openAddProduct(context),
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة منتج'),
                          ),
                        ]),
                      )
                    : _gridView
                        ? GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: provider.products.length,
                            itemBuilder: (ctx, i) {
                              final p = provider.products[i];
                              return ProductCard(
                                product: p,
                                currency: settings.currency,
                                onEdit: () => _openEditProduct(context, p),
                                onDelete: () => _confirmDelete(context, p, provider),
                              );
                            },
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: provider.products.length,
                            itemBuilder: (ctx, i) {
                              final p = provider.products[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  tileColor: AppColors.card,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: const BorderSide(color: AppColors.cardBorder),
                                  ),
                                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
                                  subtitle: Text('${p.salePrice.toStringAsFixed(2)} ${settings.currency} | الكمية: ${p.quantity}',
                                    style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: p.isOutOfStock ? AppColors.error.withOpacity(0.15)
                                              : p.isLowStock ? AppColors.warning.withOpacity(0.15)
                                              : AppColors.success.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          p.isOutOfStock ? 'نفذ' : p.isLowStock ? 'منخفض' : 'متوفر',
                                          style: TextStyle(
                                            fontSize: 11, fontFamily: 'Cairo',
                                            color: p.isOutOfStock ? AppColors.error
                                                : p.isLowStock ? AppColors.warning
                                                : AppColors.success,
                                          ),
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        color: AppColors.surfaceVariant,
                                        onSelected: (v) {
                                          if (v == 'edit') _openEditProduct(context, p);
                                          if (v == 'delete') _confirmDelete(context, p, provider);
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(value: 'edit', child: Text('تعديل', style: TextStyle(fontFamily: 'Cairo'))),
                                          PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(fontFamily: 'Cairo', color: AppColors.error))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddProduct(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _categoryChip(BuildContext context, String? id, String name, ProductProvider provider) {
    final selected = provider.selectedCategory == id;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: FilterChip(
        label: Text(name),
        selected: selected,
        onSelected: (_) => provider.filterByCategory(id),
        selectedColor: AppColors.gold.withOpacity(0.2),
        checkmarkColor: AppColors.gold,
        labelStyle: TextStyle(
          fontFamily: 'Cairo',
          color: selected ? AppColors.gold : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
        ),
        backgroundColor: AppColors.surfaceVariant,
        side: BorderSide(color: selected ? AppColors.gold : AppColors.cardBorder),
      ),
    );
  }

  void _openAddProduct(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen()));
  }

  void _openEditProduct(BuildContext context, Product p) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AddProductScreen(product: p)));
  }

  void _confirmDelete(BuildContext context, Product p, ProductProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Cairo')),
        content: Text('هل تريد حذف "${p.name}"؟', style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              provider.deleteProduct(p.id);
              Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
