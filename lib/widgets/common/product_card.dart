import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddToCart;
  final String currency;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onAddToCart,
    this.currency = 'دج',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: product.isOutOfStock
                ? AppColors.error.withOpacity(0.5)
                : product.isLowStock
                    ? AppColors.warning.withOpacity(0.5)
                    : AppColors.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stock badge
            if (product.isOutOfStock || product.isLowStock)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: product.isOutOfStock ? AppColors.error : AppColors.warning,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  product.isOutOfStock ? 'نفذ المخزون' : 'مخزون منخفض',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontFamily: 'Cairo',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onEdit != null || onDelete != null)
                        PopupMenuButton<String>(
                          color: AppColors.surfaceVariant,
                          onSelected: (v) {
                            if (v == 'edit') onEdit?.call();
                            if (v == 'delete') onDelete?.call();
                          },
                          itemBuilder: (_) => [
                            if (onEdit != null)
                              const PopupMenuItem(value: 'edit', child: Row(children: [
                                Icon(Icons.edit_outlined, size: 18, color: AppColors.gold),
                                SizedBox(width: 8),
                                Text('تعديل', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary)),
                              ])),
                            if (onDelete != null)
                              const PopupMenuItem(value: 'delete', child: Row(children: [
                                Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                SizedBox(width: 8),
                                Text('حذف', style: TextStyle(fontFamily: 'Cairo', color: AppColors.error)),
                              ])),
                          ],
                          child: const Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
                        ),
                    ],
                  ),
                  if (product.brand != null) ...[
                    const SizedBox(height: 4),
                    Text(product.brand!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontFamily: 'Cairo')),
                  ],
                  if (product.categoryName != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(product.categoryName!,
                        style: const TextStyle(fontSize: 11, color: AppColors.gold, fontFamily: 'Cairo')),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${product.salePrice.toStringAsFixed(2)} $currency',
                          style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: AppColors.gold, fontFamily: 'Cairo')),
                        Text('الكمية: ${product.quantity}',
                          style: TextStyle(
                            fontSize: 12,
                            color: product.isOutOfStock ? AppColors.error : AppColors.textSecondary,
                            fontFamily: 'Cairo')),
                      ]),
                      if (onAddToCart != null)
                        ElevatedButton(
                          onPressed: product.isOutOfStock ? null : onAddToCart,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(40, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Icon(Icons.add_shopping_cart, size: 18),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
