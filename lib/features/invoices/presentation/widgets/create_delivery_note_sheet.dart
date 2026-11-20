import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../products/application/products_controller.dart';
import '../../../products/data/product_providers.dart';
import '../../../settings/data/organization_repository.dart';
import '../../application/delivery_notes_controller.dart';
import '../../data/invoice_providers.dart';
import '../../domain/document_template.dart';
import '../../domain/delivery_note.dart';
import '../../domain/invoice.dart';
import '../pages/invoice_preview_screen.dart';

Future<DeliveryNote?> showCreateDeliveryNoteSheet(
  BuildContext context, {
  required CustomerInvoice invoice,
  required Organization organization,
}) {
  return showModalBottomSheet<DeliveryNote?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.resolveCardBackground(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => CreateDeliveryNoteSheet(
      invoice: invoice,
      organization: organization,
    ),
  );
}

class CreateDeliveryNoteSheet extends ConsumerStatefulWidget {
  const CreateDeliveryNoteSheet({
    super.key,
    required this.invoice,
    required this.organization,
  });

  final CustomerInvoice invoice;
  final Organization organization;

  @override
  ConsumerState<CreateDeliveryNoteSheet> createState() =>
      _CreateDeliveryNoteSheetState();
}

class _CreateDeliveryNoteSheetState
    extends ConsumerState<CreateDeliveryNoteSheet> {
  static const _uuid = Uuid();

  late final TextEditingController _driverController;
  late final TextEditingController _driverPhoneController;
  late final TextEditingController _vehicleController;
  late final TextEditingController _destinationController;
  late final TextEditingController _notesController;

  late final Map<String, double> _quantities;
  late final Map<String, TextEditingController> _qtyControllers;

  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _driverController = TextEditingController()
      ..addListener(() => setState(() {}));
    _driverPhoneController = TextEditingController();
    _vehicleController = TextEditingController()
      ..addListener(() => setState(() {}));
    _destinationController = TextEditingController(
      text: widget.invoice.customerAddress ?? '',
    );
    _notesController = TextEditingController();

    _quantities = {};
    _qtyControllers = {};
    for (final line in widget.invoice.lines) {
      _quantities[line.id] = line.quantity;
      _qtyControllers[line.id] = TextEditingController(
        text: line.quantity % 1 == 0
            ? line.quantity.toInt().toString()
            : line.quantity.toString(),
      );
    }
  }

  @override
  void dispose() {
    _driverController.dispose();
    _driverPhoneController.dispose();
    _vehicleController.dispose();
    _destinationController.dispose();
    _notesController.dispose();
    for (final controller in _qtyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit({bool directDispatch = false}) async {
    final loc = context.loc;
    final isSwahili = context.isSwahili;
    final totalQty = _quantities.values.fold<double>(0, (sum, q) => sum + q);

    if (totalQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSwahili
                ? 'Tafadhali weka idadi ya bidhaa za kusafirisha.'
                : 'Please specify items to dispatch.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final productsState = ref.read(productsControllerProvider);
      final productMap = <String, dynamic>{};
      if (productsState is ProductsLoaded) {
        for (final p in productsState.items) {
          productMap[p.id] = p;
        }
      }

      final deliveryItems = <DeliveryNoteItem>[];
      for (final line in widget.invoice.lines) {
        final qty = _quantities[line.id] ?? 0;
        if (qty > 0) {
          final matchedProduct =
              line.productId != null ? productMap[line.productId] : null;
          final resolvedSku = line.sku ?? matchedProduct?.sku;
          deliveryItems.add(
            DeliveryNoteItem(
              id: _uuid.v4(),
              productId: line.productId,
              productName: line.description,
              sku: resolvedSku,
              quantityOrdered: line.quantity,
              quantityToDeliver: qty,
              unitOfMeasure: line.unitOfMeasure,
            ),
          );
        }
      }

      final repo = ref.read(deliveryNoteRepositoryProvider);
      final note = await repo.create(
        customerName: widget.invoice.customerLabel,
        items: deliveryItems,
        invoiceId: widget.invoice.id,
        invoiceNumber: widget.invoice.number,
        customerId: widget.invoice.customerId,
        customerPhone: widget.invoice.customerPhone,
        customerAddress: widget.invoice.customerAddress,
        deliveryAddress: _destinationController.text.trim().isNotEmpty
            ? _destinationController.text.trim()
            : widget.invoice.customerAddress,
        driverName: _driverController.text.trim().isNotEmpty
            ? _driverController.text.trim()
            : null,
        driverPhone: _driverPhoneController.text.trim().isNotEmpty
            ? _driverPhoneController.text.trim()
            : null,
        vehicleNumber: _vehicleController.text.trim().isNotEmpty
            ? _vehicleController.text.trim()
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        issueDate: DateTime.now(),
        directDispatch: directDispatch,
      );

      ref.read(deliveryNotesControllerProvider.notifier).load(silent: true);

      if (!mounted) return;

      Navigator.of(context).pop(note);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            directDispatch
                ? (isSwahili
                    ? 'Waraka wa mzigo #${note.number} umetengenezwa na kusafirishwa moja kwa moja!'
                    : 'Delivery note #${note.number} created and dispatched directly!')
                : loc.deliveryNoteSuccess,
          ),
          backgroundColor: AppColors.success,
        ),
      );

      // Navigate directly to live preview & print screen
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => InvoicePreviewScreen(
            documentId: note.id,
            documentNumber: note.number,
            documentType: DocumentType.deliveryNote,
            initialDeliveryNote: note,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isSwahili = context.isSwahili;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Sheet Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: Color(0xFF0284C7),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.invoiceGenerateDeliveryNote,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.resolveTextPrimary(context),
                          ),
                        ),
                        Text(
                          '${widget.invoice.invoiceNumber} • ${widget.invoice.customerLabel}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.resolveTextSecondary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Scrollable Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  // Section: Carrier / Logistics
                  Text(
                    isSwahili ? 'TAARIFA ZA USAFIRISHAJI' : 'DISPATCH & LOGISTICS',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.resolveTextSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Driver Name Field
                  TextField(
                    controller: _driverController,
                    decoration: InputDecoration(
                      labelText: loc.deliveryNoteDriver,
                      hintText: loc.deliveryNoteDriverHint,
                      prefixIcon: const Icon(Icons.person_pin_outlined, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Driver Phone Field
                  TextField(
                    controller: _driverPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: isSwahili
                          ? 'Namba ya Simu ya Dereva'
                          : 'Driver Phone Number',
                      hintText: isSwahili ? 'mf. 0712345678' : 'e.g. 0712345678',
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Vehicle Number Field
                  TextField(
                    controller: _vehicleController,
                    decoration: InputDecoration(
                      labelText: loc.deliveryNoteVehicle,
                      hintText: loc.deliveryNoteVehicleHint,
                      prefixIcon: const Icon(Icons.directions_car_outlined, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Destination Field
                  TextField(
                    controller: _destinationController,
                    decoration: InputDecoration(
                      labelText: loc.deliveryNoteDestination,
                      hintText: loc.deliveryNoteDestinationHint,
                      prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section: Items to Dispatch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        loc.deliveryNoteItemsToDeliver.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.resolveTextSecondary(context),
                        ),
                      ),
                      Text(
                        '${widget.invoice.lines.length} ${isSwahili ? "Aina" : "Items"}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.resolveTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Items List Container
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.invoice.lines.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                      itemBuilder: (context, index) {
                        final line = widget.invoice.lines[index];
                        final qty = _quantities[line.id] ?? line.quantity;
                        final qtyCtrl = _qtyControllers[line.id]!;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.description,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            AppColors.resolveTextPrimary(context),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${isSwahili ? "Imeagizwa" : "Ordered"}: ${line.quantity % 1 == 0 ? line.quantity.toInt() : line.quantity} ${line.unitOfMeasure}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color:
                                            AppColors.resolveTextSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Quantity Stepper / Input
                              Row(
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.remove_circle_outline,
                                        size: 22),
                                    color: qty > 0
                                        ? primaryColor
                                        : Colors.grey,
                                    onPressed: qty > 0
                                        ? () {
                                            setState(() {
                                              final next = (qty - 1).clamp(
                                                  0.0, line.quantity);
                                              _quantities[line.id] = next;
                                              qtyCtrl.text = next % 1 == 0
                                                  ? next.toInt().toString()
                                                  : next.toString();
                                            });
                                          }
                                        : null,
                                  ),
                                  SizedBox(
                                    width: 52,
                                    child: TextField(
                                      controller: qtyCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 8, horizontal: 4),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      onChanged: (val) {
                                        final parsed = double.tryParse(val) ?? 0;
                                        final clamped =
                                            parsed.clamp(0.0, line.quantity);
                                        setState(() {
                                          _quantities[line.id] = clamped;
                                        });
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.add_circle_outline,
                                        size: 22),
                                    color: qty < line.quantity
                                        ? primaryColor
                                        : Colors.grey,
                                    onPressed: qty < line.quantity
                                        ? () {
                                            setState(() {
                                              final next = (qty + 1).clamp(
                                                  0.0, line.quantity);
                                              _quantities[line.id] = next;
                                              qtyCtrl.text = next % 1 == 0
                                                  ? next.toInt().toString()
                                                  : next.toString();
                                            });
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Delivery Notes Field
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText:
                          isSwahili ? 'Maelekezo Maalum' : 'Special Notes',
                      hintText: isSwahili
                          ? 'mf. Mzigo unahitaji umakini, usiloweshwe maji'
                          : 'e.g. Fragile, keep dry during transit',
                      prefixIcon: const Icon(Icons.notes_outlined, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Action Section
                  Builder(
                    builder: (context) {
                      final hasTransport = _driverController.text.trim().isNotEmpty ||
                          _vehicleController.text.trim().isNotEmpty;

                      if (hasTransport) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: 50,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D9488),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _isCreating
                                    ? null
                                    : () => _submit(directDispatch: true),
                                icon: _isCreating
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.local_shipping_outlined),
                                label: Text(
                                  _isCreating
                                      ? (isSwahili ? 'Inasafirisha...' : 'Dispatching...')
                                      : (isSwahili
                                          ? 'Tengeneza na Safirisha Moja kwa Moja'
                                          : 'Create & Dispatch Directly'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: _isCreating
                                    ? null
                                    : () => _submit(directDispatch: false),
                                icon: const Icon(Icons.save_outlined, size: 18),
                                label: Text(
                                  isSwahili
                                      ? 'Hifadhi kama Rasimu (Draft)'
                                      : 'Save as Draft',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      return SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isCreating
                              ? null
                              : () => _submit(directDispatch: false),
                          icon: _isCreating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.print_outlined),
                          label: Text(
                            _isCreating
                                ? (isSwahili ? 'Inatengeneza...' : 'Generating...')
                                : loc.deliveryNoteConfirmCreate,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
