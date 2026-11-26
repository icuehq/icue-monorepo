import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:mess_meals/src/providers/meals_provider.dart';
import 'package:mess_meals/src/ui/widgets/voucher_purchase_card.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';

/// Past voucher purchases, loaded 10 at a time while scrolling.
class MealVouchersHistoryPage extends StatefulWidget {
  const MealVouchersHistoryPage({super.key});

  @override
  State<MealVouchersHistoryPage> createState() =>
      _MealVouchersHistoryPageState();
}

class _MealVouchersHistoryPageState extends State<MealVouchersHistoryPage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        context.read<MealsProvider>().loadMoreHistory();
      }
    });
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => context.read<MealsProvider>().loadHistory(),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final meals = context.watch<MealsProvider>();
    final history = meals.history;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        title: Text(l10n.voucherPurchaseHistory),
        bottom: IcueContextBar(
          label: context.watch<ParentAuthProvider>().selectedStudent?.name,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: meals.loadHistory,
        child: IcueSheetBody(
          loading: meals.loading && history.isEmpty,
          hasData: history.isNotEmpty,
          emptyTitle: l10n.noHistoryFound,
          child: ListView.separated(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: history.length + (meals.historyHasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) => index == history.length
                ? const Center(child: CircularProgressIndicator())
                : VoucherPurchaseCard(purchase: history[index]),
          ),
        ),
      ),
    );
  }
}
