import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/debt.dart';
import '../../models/expense.dart';
import '../../providers/debt_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common/stat_card.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DebtProvider>().loadAll();
      context.read<ExpenseProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final currency = settings.currency;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الديون والمصروفات'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'ديون لنا (للتحصيل)'),
            Tab(text: 'ديون علينا (للسداد)'),
            Tab(text: 'المصروفات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _DebtsOwedTab(currency: currency),
          _DebtsDueTab(currency: currency),
          _ExpensesTab(currency: currency),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        backgroundColor: AppColors.gold,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('إضافة', style: TextStyle(fontFamily: 'Cairo', color: Colors.black)),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddEntrySheet(
        tabIndex: _tab.index,
        currency: context.read<SettingsProvider>().currency,
      ),
    );
  }
}

// ── Tab 1: أموال المدينة ─────────────────────────────────────────────────────

class _DebtsOwedTab extends StatelessWidget {
  final String currency;
  const _DebtsOwedTab({required this.currency});

  @override
  Widget build(BuildContext context) {
    return Consumer<DebtProvider>(
      builder: (context, provider, _) {
        final unpaid = provider.unpaidDebtsOwed;
        final paid = provider.debtsOwed.where((d) => d.isPaid).toList();
        final total = unpaid.fold<double>(0, (sum, d) => sum + d.amount);

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(child: StatCard(
                    title: 'إجمالي ديون العملاء',
                    value: '$total $currency',
                    icon: Icons.arrow_downward,
                    color: AppColors.error,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: StatCard(
                    title: 'عدد الديون',
                    value: '${unpaid.length}',
                    icon: Icons.receipt_long,
                    color: AppColors.info,
                  )),
                ]),
              ),
            ),
            if (unpaid.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text('غير مدفوعة (${unpaid.length})',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 14,
                      fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _DebtCard(debt: unpaid[index], currency: currency, onMarkPaid: () {
                    context.read<DebtProvider>().markDebtOwedAsPaid(unpaid[index].id);
                  }),
                  childCount: unpaid.length,
                ),
              ),
            ],
            if (paid.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('مدفوعة (${paid.length})',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 14,
                      fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _DebtCard(debt: paid[index], currency: currency, isPaid: true),
                  childCount: paid.length,
                ),
              ),
            ],
            if (unpaid.isEmpty && paid.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_balance_wallet_outlined,
                        size: 64, color: AppColors.textMuted.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text('لا توجد ديون مستحقة للمحل حالياً',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 16,
                          color: AppColors.textMuted.withOpacity(0.5))),
                    ],
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        );
      },
    );
  }
}

// ── Tab 2: أموال المحل ───────────────────────────────────────────────────────

class _DebtsDueTab extends StatelessWidget {
  final String currency;
  const _DebtsDueTab({required this.currency});

  @override
  Widget build(BuildContext context) {
    return Consumer<DebtProvider>(
      builder: (context, provider, _) {
        final unpaid = provider.unpaidDebtsDue;
        final paid = provider.debtsDue.where((d) => d.isPaid).toList();
        final total = unpaid.fold<double>(0, (sum, d) => sum + d.amount);

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(child: StatCard(
                    title: 'إجمالي ديون الموردين',
                    value: '$total $currency',
                    icon: Icons.arrow_upward,
                    color: AppColors.warning,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: StatCard(
                    title: 'عدد الديون',
                    value: '${unpaid.length}',
                    icon: Icons.receipt_long,
                    color: AppColors.info,
                  )),
                ]),
              ),
            ),
            if (unpaid.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text('مستحقة الدفع (${unpaid.length})',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 14,
                      fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _DebtCard(debt: unpaid[index], currency: currency,
                    isOwed: false, onMarkPaid: () {
                    context.read<DebtProvider>().markDebtDueAsPaid(unpaid[index].id);
                  }),
                  childCount: unpaid.length,
                ),
              ),
            ],
            if (paid.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('مدفوعة (${paid.length})',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 14,
                      fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _DebtCard(debt: paid[index], currency: currency, isPaid: true),
                  childCount: paid.length,
                ),
              ),
            ],
            if (unpaid.isEmpty && paid.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_balance_outlined,
                        size: 64, color: AppColors.textMuted.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text('لا توجد ديون مستحقة على المحل حالياً',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 16,
                          color: AppColors.textMuted.withOpacity(0.5))),
                    ],
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        );
      },
    );
  }
}

// ── Tab 3: المصروفات ──────────────────────────────────────────────────────────

class _ExpensesTab extends StatelessWidget {
  final String currency;
  const _ExpensesTab({required this.currency});

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        if (provider.loading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.gold));
        }

        final expenses = provider.expenses;
        final byType = provider.byType;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: StatCard(
                      title: 'مصروفات اليوم',
                      value: '${provider.todayTotal.toStringAsFixed(2)} $currency',
                      icon: Icons.today,
                      color: AppColors.warning,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: StatCard(
                      title: 'مصروفات الشهر',
                      value: '${provider.monthTotal.toStringAsFixed(2)} $currency',
                      icon: Icons.calendar_month,
                      color: AppColors.error,
                    )),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: StatCard(
                      title: 'إجمالي المصروفات',
                      value: '${provider.allTimeTotal.toStringAsFixed(2)} $currency',
                      icon: Icons.account_balance_wallet,
                      color: AppColors.info,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: StatCard(
                      title: 'عدد المصروفات',
                      value: '${expenses.length}',
                      icon: Icons.receipt_long,
                      color: AppColors.gold,
                    )),
                  ]),
                ]),
              ),
            ),

            if (byType.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text('التصنيفات',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 14,
                      fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: byType.entries.map((e) {
                      final type = ExpenseType.values.firstWhere(
                        (t) => t.name == e.key,
                        orElse: () => ExpenseType.general,
                      );
                      return _ExpenseTypeRow(
                        type: type,
                        amount: e.value,
                        total: provider.monthTotal,
                        currency: currency,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],

            if (expenses.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('آخر المصروفات',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 14,
                      fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ExpenseCard(
                    expense: expenses[index],
                    currency: currency,
                    onDelete: () => context.read<ExpenseProvider>().deleteExpense(expenses[index].id),
                  ),
                  childCount: expenses.length,
                ),
              ),
            ],

            if (expenses.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.payments_outlined,
                        size: 64, color: AppColors.textMuted.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text('لا توجد مصروفات',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 16,
                          color: AppColors.textMuted.withOpacity(0.5))),
                    ],
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        );
      },
    );
  }
}

// ── Expense Type Row ──────────────────────────────────────────────────────────

class _ExpenseTypeRow extends StatelessWidget {
  final ExpenseType type;
  final double amount;
  final double total;
  final String currency;

  const _ExpenseTypeRow({
    required this.type,
    required this.amount,
    required this.total,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final percent = total > 0 ? (amount / total * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(type.typeIcon, style: const TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(type.typeText,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: percent / 100,
              backgroundColor: AppColors.surfaceVariant,
              color: AppColors.warning,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${amount.toStringAsFixed(2)} $currency',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700,
              color: AppColors.gold)),
          Text('${percent.toStringAsFixed(0)}%',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textMuted)),
        ]),
      ]),
    );
  }
}

// ── Expense Card ──────────────────────────────────────────────────────────────

class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  final String currency;
  final VoidCallback onDelete;

  const _ExpenseCard({
    required this.expense,
    required this.currency,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(expense.typeIcon, style: const TextStyle(fontSize: 20)),
          ),
        ),
        title: Text(expense.title,
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700,
            color: AppColors.textPrimary)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(expense.typeText,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted)),
          Text(DateFormat('yyyy/MM/dd').format(expense.date),
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textMuted)),
        ]),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${expense.amount.toStringAsFixed(2)} $currency',
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800,
                fontSize: 15, color: AppColors.error)),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
              onPressed: () => _showDeleteConfirm(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حذف المصروف', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary)),
        content: Text('هل تريد حذف "${expense.title}"؟',
          style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }
}

// ── Debt Card Widget ──────────────────────────────────────────────────────────

class _DebtCard extends StatelessWidget {
  final Debt debt;
  final String currency;
  final bool isPaid;
  final bool isOwed;
  final VoidCallback? onMarkPaid;

  const _DebtCard({
    required this.debt,
    required this.currency,
    this.isPaid = false,
    this.isOwed = true,
    this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isPaid ? AppColors.card.withOpacity(0.5) : AppColors.card;
    final borderColor = isPaid ? AppColors.textMuted.withOpacity(0.3) :
        (isOwed ? AppColors.error.withOpacity(0.3) : AppColors.warning.withOpacity(0.3));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: (isOwed ? AppColors.error : AppColors.warning).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isOwed ? Icons.arrow_downward : Icons.arrow_upward,
            color: isOwed ? AppColors.error : AppColors.warning,
          ),
        ),
        title: Text(debt.personName,
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700,
            color: isPaid ? AppColors.textMuted : AppColors.textPrimary)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (debt.description != null && debt.description!.isNotEmpty)
              Text(debt.description!,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
            if (debt.dueDate != null)
              Text('تاريخ الاستحقاق: ${DateFormat('yyyy/MM/dd').format(debt.dueDate!)}',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${debt.amount.toStringAsFixed(2)} $currency',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800,
                fontSize: 16, color: isPaid ? AppColors.textMuted : AppColors.gold)),
            if (isPaid)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('مدفوع',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.success)),
              )
            else if (onMarkPaid != null)
              TextButton(
                onPressed: onMarkPaid,
                child: const Text('تسديد',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.success)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Add Entry Sheet ────────────────────────────────────────────────────────────

class _AddEntrySheet extends StatefulWidget {
  final int tabIndex;
  final String currency;
  const _AddEntrySheet({required this.tabIndex, required this.currency});

  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<_AddEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _dueDate;
  bool _saving = false;
  ExpenseType _selectedType = ExpenseType.general;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(_getTitle(),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 18,
                  fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 20),

              if (widget.tabIndex < 2) ...[
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _inputDecoration('الاسم', Icons.person_outline),
                  validator: (v) => v == null || v.isEmpty ? 'أدخل الاسم' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: _inputDecoration('الهاتف (اختياري)', Icons.phone_outlined),
                  keyboardType: TextInputType.phone,
                ),
              ] else ...[
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _inputDecoration('عنوان المصروف', Icons.description_outlined),
                  validator: (v) => v == null || v.isEmpty ? 'أدخل العنوان' : null,
                ),
                const SizedBox(height: 12),
                _buildTypeSelector(),
              ],

              const SizedBox(height: 12),
              TextFormField(
                controller: _amountCtrl,
                decoration: _inputDecoration('المبلغ', Icons.attach_money),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'أدخل المبلغ';
                  if (double.tryParse(v) == null) return 'أدخل رقماً صحيحاً';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              if (widget.tabIndex < 2) ...[
                TextFormField(
                  controller: _descCtrl,
                  decoration: _inputDecoration('الوصف (اختياري)', Icons.description_outlined),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (date != null) setState(() => _dueDate = date);
                  },
                  child: InputDecorator(
                    decoration: _inputDecoration('تاريخ الاستحقاق (اختياري)', Icons.calendar_today),
                    child: Text(
                      _dueDate != null ? DateFormat('yyyy/MM/dd').format(_dueDate!) : 'اختر تاريخ',
                      style: TextStyle(fontFamily: 'Cairo',
                        color: _dueDate != null ? AppColors.textPrimary : AppColors.textMuted),
                    ),
                  ),
                ),
              ] else ...[
                TextFormField(
                  controller: _notesCtrl,
                  decoration: _inputDecoration('ملاحظات (اختياري)', Icons.note_outlined),
                  maxLines: 2,
                ),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 24, height: 24,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Text('حفظ',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 16,
                            fontWeight: FontWeight.w700, color: Colors.black)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('نوع المصروف',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ExpenseType.values.map((type) {
            final isSelected = _selectedType == type;
            return GestureDetector(
              onTap: () => setState(() => _selectedType = type),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.gold.withOpacity(0.2) : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSelected ? AppColors.gold : AppColors.cardBorder),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(type.typeIcon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(type.typeText,
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12,
                      color: isSelected ? AppColors.gold : AppColors.textSecondary)),
                ]),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  String _getTitle() {
    switch (widget.tabIndex) {
      case 0: return 'إضافة أموال مدينة';
      case 1: return 'إضافة أموال المحل';
      case 2: return 'إضافة مصروف';
      default: return 'إضافة';
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: AppColors.textMuted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gold),
      ),
      filled: true,
      fillColor: AppColors.inputBackground,
      labelStyle: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      if (widget.tabIndex == 0) {
        await context.read<DebtProvider>().addDebtOwed(
          personName: _nameCtrl.text,
          phone: _phoneCtrl.text.isEmpty ? null : _phoneCtrl.text,
          amount: double.parse(_amountCtrl.text),
          description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
          dueDate: _dueDate,
        );
      } else if (widget.tabIndex == 1) {
        await context.read<DebtProvider>().addDebtDue(
          personName: _nameCtrl.text,
          phone: _phoneCtrl.text.isEmpty ? null : _phoneCtrl.text,
          amount: double.parse(_amountCtrl.text),
          description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
          dueDate: _dueDate,
        );
      } else {
        await context.read<ExpenseProvider>().addExpense(
          title: _nameCtrl.text,
          amount: double.parse(_amountCtrl.text),
          type: _selectedType,
          notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحفظ بنجاح',
            style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e',
            style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.error),
        );
      }
    }
  }
}