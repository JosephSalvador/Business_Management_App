import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/network/app_exception.dart';
import '../../../capabilities/domain/capabilities.dart';
import '../../application/billing_providers.dart';
import '../../data/billing_providers.dart';
import '../../domain/billing.dart';

/// Attractive, high-converting Upsell & Upgrade Showcase Sheet.
///
/// Presented to tenant owners/managers when attempting to access a premium
/// or package module that is not included in their current subscription.
class ModuleUpgradeSheet extends ConsumerStatefulWidget {
  const ModuleUpgradeSheet({super.key, required this.module});

  final WorkspaceModule module;

  static Future<void> show(BuildContext context,
      {required WorkspaceModule module}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModuleUpgradeSheet(module: module),
    );
  }

  @override
  ConsumerState<ModuleUpgradeSheet> createState() => _ModuleUpgradeSheetState();
}

class _ModuleUpgradeSheetState extends ConsumerState<ModuleUpgradeSheet> {
  final _voucherController = TextEditingController();
  bool _isRedeeming = false;
  String? _errorMessage;

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  Future<void> _pasteVoucher() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text != null && text.isNotEmpty) {
        setState(() {
          _voucherController.text = VoucherCode.normalize(text);
          _errorMessage = null;
        });
      }
    } catch (_) {}
  }

  Future<void> _redeemVoucher() async {
    final code = VoucherCode.normalize(_voucherController.text);
    if (!VoucherCode.isValidFormat(code)) {
      setState(() => _errorMessage =
          'Muundo wa vocha si sahihi (tarajiwa k.m. JX-PRO-7K9M-X2PQ).');
      return;
    }

    setState(() {
      _isRedeeming = true;
      _errorMessage = null;
    });

    try {
      await ref.read(billingRepositoryProvider).redeemVoucher(code);
      if (!mounted) return;
      ref.read(subscriptionEntitlementControllerProvider.notifier).refresh();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vocha imewashwa kwa mafanikio! Moduli imefunguliwa.'),
          backgroundColor: Color(0xFF00C48C),
        ),
      );
    } on AppException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Hitilafu ya mtandao wakati wa kuwezesha.');
      }
    } finally {
      if (mounted) setState(() => _isRedeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _getModuleMarketingInfo(widget.module);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: const Color(0xFF00C48C).withValues(alpha: 0.3),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Emblem
            Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C48C), Color(0xFF38BDF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00C48C).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(info.icon, color: Colors.white, size: 34),
              ),
            ),
            const SizedBox(height: 16),

            // Title & Subtitle
            Text(
              info.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              info.tagline,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : Colors.grey[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // 3 Key Business Benefits
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.7)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                children: info.benefits.map((benefit) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          CupertinoIcons.checkmark_seal_fill,
                          color: Color(0xFF00C48C),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            benefit,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            // Quick Voucher Input or Go to Billing
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _voucherController,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Weka Vocha (k.m. JX-PRO...)',
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF061028)
                          : const Color(0xFFE2E8F0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste_rounded, size: 18),
                        tooltip: 'Bandika Vocha',
                        onPressed: _pasteVoucher,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _isRedeeming ? null : _redeemVoucher,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00C48C),
                    foregroundColor: const Color(0xFF061028),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isRedeeming
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF061028),
                          ),
                        )
                      : const Text(
                          'Washa',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 14),

            // Action: View Plans / Pay via Mobile Money
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.push(Routes.billing);
              },
              icon: const Icon(CupertinoIcons.creditcard, size: 18),
              label: const Text('Angalia Njia za Malipo & Vifurushi (M-Pesa / Tigo)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF38BDF8),
                side: const BorderSide(color: Color(0xFF38BDF8)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _MarketingInfo _getModuleMarketingInfo(WorkspaceModule module) {
    switch (module) {
      case WorkspaceModule.reports:
        return _MarketingInfo(
          icon: CupertinoIcons.chart_bar_alt_fill,
          title: 'Ripoti na Uchambuzi wa Kina',
          tagline:
              'Pata ufahamu kamili wa faida halisi, bidhaa zinazoongoza, na mwenendo wa kodi.',
          benefits: [
            'Fahamu faida halisi baada ya kutoa gharama zote za ununuzi na uendeshaji.',
            'Tambua bidhaa zinazotoka kwa kasi (Fast-Moving) na zile zinazokaa stoo bila sababu.',
            'Ripoti rasmi za TRA na muhtasari wa kodi unazoweza kupakua kwa PDF au Excel.',
          ],
        );
      case WorkspaceModule.crm:
        return _MarketingInfo(
          icon: CupertinoIcons.person_2_fill,
          title: 'Wateja na Udhibiti wa Madeni',
          tagline:
              'Jenga uaminifu na wateja wako na uweke kumbukumbu sahihi za madeni yote.',
          benefits: [
            'Orodha kamili ya wateja wenye madeni, kiasi wanachodaiwa, na tarehe za mwisho.',
            'Tuma vikumbusho vya madeni kwa SMS na WhatsApp kwa mguso mmoja.',
            'Historia ya manunuzi ya kila mteja kwa ajili ya ofa na uaminifu (Loyalty).',
          ],
        );
      case WorkspaceModule.invoicing:
        return _MarketingInfo(
          icon: CupertinoIcons.doc_text_fill,
          title: 'Ankara Rasmi (Invoice Manager)',
          tagline:
              'Toa ankara za kisasa zenye jina na nembo ya duka lako kwa wateja wa jumla na rejareja.',
          benefits: [
            'Tengeneza ankara za PDF zenye nembo yako na uzitume kwa WhatsApp au barua pepe.',
            'Fuatilia malipo ya awamu (Partial payments) na salio lililobaki kwa uhakika.',
            'Badilisha ankara kuwa mauzo rasmi mara tu mteja anapokamilisha malipo.',
          ],
        );
      case WorkspaceModule.purchasing:
        return _MarketingInfo(
          icon: CupertinoIcons.cart_fill,
          title: 'Wasambazaji na Manunuzi',
          tagline:
              'Kudhibiti ununuzi wa stock, ankara za wasambazaji, na gharama za kuingiza mzigo.',
          benefits: [
            'Kumbukumbu kamili ya wauzaji wa jumla na bei zao za kila bidhaa.',
            'Uhesabuji wa faida unaozingatia bei halisi uliyonunulia mzigo huo.',
            'Uthibitisho wa kuingiza mzigo stoo moja kwa moja kutoka kwenye ankara ya msambazaji.',
          ],
        );
      case WorkspaceModule.finance:
        return _MarketingInfo(
          icon: CupertinoIcons.money_dollar_circle_fill,
          title: 'Usimamizi wa Fedha na Matumizi',
          tagline:
              'Dhibiti kila shilingi inayoingia na kutoka kwenye akaunti za benki na simu.',
          benefits: [
            'Kugawa fedha kwenye droo ya keshia, M-Pesa Till, na akaunti za benki.',
            'Kurekodi matumizi ya kila siku (kodi, umeme, mishahara, chakula) ili kujua faida halisi.',
            'Kuzuia upotevu wa fedha kupitia ukaguzi wa kila mwisho wa siku (Cash reconciliation).',
          ],
        );
      default:
        return _MarketingInfo(
          icon: CupertinoIcons.cube_box_fill,
          title: 'Boresha Kifurushi cha Biashara',
          tagline: 'Fungua uwezo kamili wa mfumo ili kuongeza ufanisi wa duka lako.',
          benefits: [
            'Uwezo wa kuunganisha matawi mengi chini ya mfumo mmoja.',
            'Watumishi wengi wenye mgawanyo sahihi wa majukumu na ruhusa.',
            'Hifadhi ya data mtandaoni na usalama wa kiwango cha juu wa biashara yako.',
          ],
        );
    }
  }
}

class _MarketingInfo {
  const _MarketingInfo({
    required this.icon,
    required this.title,
    required this.tagline,
    required this.benefits,
  });

  final IconData icon;
  final String title;
  final String tagline;
  final List<String> benefits;
}
