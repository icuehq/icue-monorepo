import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:mess_meals/src/models/voucher_purchase.dart';
import 'package:mess_meals/src/providers/meals_provider.dart';
import 'package:mess_meals/src/ui/widgets/payment_result_cards.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';

enum _Status { loading, success, failure }

/// Opens the payment gateway's checkout and shows the outcome.
class MealPaymentPage extends StatefulWidget {
  const MealPaymentPage({required this.session, super.key});

  final PaymentSession session;

  @override
  State<MealPaymentPage> createState() => _MealPaymentPageState();
}

class _MealPaymentPageState extends State<MealPaymentPage>
    with WidgetsBindingObserver {
  final _gateway = CFPaymentGatewayService();
  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(seconds: 1),
  );
  _Status _status = _Status.loading;
  String? _error;
  bool _launched = false;
  bool _handledReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gateway.setCallback(_onSuccess, _onError);
    SchedulerBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _confetti.dispose();
    super.dispose();
  }

  /// Coming back to the app with the checkout unanswered means the parent closed it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _launched &&
        !_handledReturn &&
        mounted &&
        _status == _Status.loading) {
      setState(() {
        _status = _Status.failure;
        _error = _friendly('cancelled');
        _handledReturn = true;
      });
    }
  }

  String _friendly(String? sdkMessage) {
    final l10n = ParentLocalizations.of(context);
    if (sdkMessage == null) return l10n.paymentUnknownError;
    final lower = sdkMessage.toLowerCase();
    return lower.contains('cancelled') || lower.contains('canceled')
        ? l10n.paymentCancelled
        : l10n.paymentCouldNotBeProcessed(sdkMessage);
  }

  void _onSuccess(String orderId) {
    CrashlyticsService.instance.log('meal_payment: success order=$orderId');
    if (!mounted) return;
    context.read<MealsProvider>().orderPaid(orderId);
    setState(() => _status = _Status.success);
    HapticFeedback.mediumImpact();
    _confetti.play();
  }

  void _onError(CFErrorResponse error, String orderId) {
    CrashlyticsService.instance.log(
      'meal_payment: error order=$orderId ${error.getMessage()}',
    );
    if (!mounted) return;
    setState(() {
      _status = _Status.failure;
      _error = _friendly(error.getMessage());
    });
    HapticFeedback.heavyImpact();
  }

  Future<void> _start() async {
    if (!mounted) return;
    setState(() => _status = _Status.loading);
    final l10n = ParentLocalizations.of(context);
    try {
      final isProd = ApiEnvironment.fromEnvironment().isProd;
      final session = CFSessionBuilder()
          .setEnvironment(
            isProd ? CFEnvironment.PRODUCTION : CFEnvironment.SANDBOX,
          )
          .setOrderId(widget.session.orderId)
          .setPaymentSessionId(widget.session.sessionId)
          .build();
      final payment = CFWebCheckoutPaymentBuilder().setSession(session).build();
      _launched = true;
      _handledReturn = false;
      CrashlyticsService.instance.log(
        'meal_payment: start order=${widget.session.orderId}',
      );
      _gateway.doPayment(payment);
    } on Object catch (e, stack) {
      unawaited(
        CrashlyticsService.instance.recordError(
          e,
          stack,
          reason: 'meal_payment.doPayment',
        ),
      );
      if (!mounted) return;
      setState(() {
        _status = _Status.failure;
        _error = l10n.paymentCouldNotStart;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final body = switch (_status) {
      _Status.loading => const PaymentLoadingCard(key: ValueKey('loading')),
      _Status.success => PaymentSuccessCard(
        key: const ValueKey('success'),
        orderId: widget.session.orderId,
        onClose: () => context.go('/'),
      ),
      _Status.failure => PaymentFailureCard(
        key: const ValueKey('failure'),
        message: _error,
        onRetry: _start,
        onClose: () => context.pop(false),
      ),
    };
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.primary,
        appBar: AppBar(
          title: Text(l10n.completePayment),
          automaticallyImplyLeading: false,
        ),
        body: IcueSheetBody(
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: body,
                ),
              ),
              ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
