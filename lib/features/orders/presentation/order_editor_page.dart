import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/premium_card.dart';
import '../../customers/domain/customer.dart';
import '../../customers/presentation/customer_form.dart';
import '../../customers/presentation/customer_providers.dart';
import '../../inventory/domain/inventory_product.dart';
import '../../inventory/presentation/inventory_format.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../../inventory/presentation/product_scanner.dart';
import '../domain/shop_order.dart';
import 'order_customer_review.dart';
import 'order_format.dart';
import 'order_providers.dart';

class OrderEditorPage extends ConsumerStatefulWidget {
  const OrderEditorPage({super.key, this.existing});
  final ShopOrder? existing;
  @override
  ConsumerState<OrderEditorPage> createState() => _OrderEditorPageState();
}

class _OrderEditorPageState extends ConsumerState<OrderEditorPage> {
  static const _steps = ['Customer', 'Products', 'Payment', 'Review'];
  final _phone = TextEditingController();
  final _search = TextEditingController();
  final _delivery = TextEditingController(text: '0');
  final _discount = TextEditingController(text: '0');
  final _advance = TextEditingController(text: '0');
  final _notes = TextEditingController();
  final _customerForm = GlobalKey<CustomerFieldsState>();
  final _paymentForm = GlobalKey<FormState>();
  final _quantities = <String, int>{};
  int _step = 0;
  Customer? _customer;
  CustomerReview _decision = CustomerReview.none;
  bool _override = false;
  bool _confirm = false;
  bool _busy = false;
  String? _error;
  OrderPayment _payment = OrderPayment.cod;
  StockTiming _timing = StockTiming.confirmed;
  String _source = 'WhatsApp';

  @override
  void initState() {
    super.initState();
    final order = widget.existing;
    if (order == null) return;
    _step = 1;
    _customer = order.customer;
    _phone.text = order.customer.phone;
    _delivery.text = (order.totals.delivery / 100).toStringAsFixed(2);
    _discount.text = (order.totals.discount / 100).toStringAsFixed(2);
    _advance.text = (order.advance / 100).toStringAsFixed(2);
    _notes.text = order.notes;
    _payment = order.payment;
    _timing = order.timing;
    _source = order.source;
    _quantities.addEntries(
      order.lines.map((line) => MapEntry(line.productId, line.quantity)),
    );
  }

  @override
  void dispose() {
    for (final field in [
      _phone,
      _search,
      _delivery,
      _discount,
      _advance,
      _notes,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  OrderTotals _totals(List<InventoryProduct> products) => OrderTotals(
    subtotal: products.fold(
      0,
      (sum, product) =>
          sum + product.details.price * (_quantities[product.id] ?? 0),
    ),
    delivery: toCents(_delivery.text) ?? 0,
    discount: toCents(_discount.text) ?? 0,
  );

  List<InventoryProduct> _chosen(List<InventoryProduct> products) =>
      products.where((product) => _quantities.containsKey(product.id)).toList();

  bool _hasStock(List<InventoryProduct> products) {
    final chosen = _chosen(products);
    return chosen.isNotEmpty &&
        chosen.length == _quantities.length &&
        chosen.every((product) => product.quantity >= _quantities[product.id]!);
  }

  String _addressKey(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Future<void> _next(
    List<Customer> customers,
    List<InventoryProduct> products,
  ) async {
    setState(() => _error = null);
    if (_step == 0) {
      final phone = normalizeSriLankanPhone(_phone.text);
      if (phone == null) {
        setState(() => _error = 'Enter a valid Sri Lankan phone number.');
        return;
      }
      final existing = customers
          .where((item) => item.phone == phone)
          .firstOrNull;
      final value = existing ?? _customerForm.currentState?.read();
      if (value == null) return;
      final related = customers
          .where(
            (item) =>
                item.phone != phone &&
                (similarPhone(phone, item.phone) ||
                    (existing == null &&
                        _addressKey(item.address) ==
                            _addressKey(value.address))),
          )
          .toList();
      final needsReview = value.needsReview || related.isNotEmpty;
      if (needsReview) {
        final choice = await reviewCustomer(context, value, related);
        if (!mounted || choice == null) return;
        _decision = choice.decision;
        _override = choice.overrideBlacklist;
      } else {
        _decision = CustomerReview.none;
        _override = false;
      }
      _customer = value;
    } else if (_step == 1 && !_hasStock(products)) {
      setState(
        () => _error = 'Select available products and check their quantities.',
      );
      return;
    } else if (_step == 2) {
      if (!_paymentForm.currentState!.validate()) return;
      try {
        final totals = _totals(products)..validate();
        if (toCents(_advance.text)! > totals.total) {
          throw const OrderFailure('Advance cannot exceed the order total.');
        }
      } catch (error) {
        setState(() => _error = orderError(error));
        return;
      }
    }
    setState(() => _step++);
  }

  Future<void> _save(List<InventoryProduct> products) async {
    if (_busy) return;
    if (!_hasStock(products)) {
      setState(
        () => _error =
            'Stock changed. Return to Products and review your quantities.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = ref.read(orderRepositoryProvider);
      final draft = OrderDraft(
        customer: _customer!,
        quantities: Map.of(_quantities),
        expectedPrices: {
          for (final product in _chosen(products))
            product.id: product.details.price,
        },
        delivery: toCents(_delivery.text)!,
        discount: toCents(_discount.text)!,
        advance: toCents(_advance.text)!,
        payment: _payment,
        timing: _timing,
        review: _decision,
        source: _source,
        notes: _notes.text,
        confirmImmediately: _confirm,
        overrideBlacklist: _override,
      );
      final previous = widget.existing;
      final number = previous == null
          ? await repository.create(draft)
          : await repository.updatePending(previous.id, draft);
      if (mounted) Navigator.pop(context, number);
    } catch (error) {
      if (mounted) setState(() => _error = orderError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _add(InventoryProduct product) {
    final quantity = _quantities[product.id] ?? 0;
    if (quantity >= product.quantity) return;
    if (quantity == 0 && _quantities.length >= 6) {
      setState(
        () => _error = 'An order can contain up to six different products.',
      );
      return;
    }
    setState(() {
      _quantities[product.id] = quantity + 1;
      _error = null;
    });
  }

  Future<void> _scan(List<InventoryProduct> products) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ProductScanner()),
    );
    if (!mounted || result == null) return;
    final product = products
        .where((item) => item.details.sku.toLowerCase() == result.toLowerCase())
        .firstOrNull;
    if (product == null) {
      setState(() => _error = 'No product matches that SKU.');
    } else if (product.quantity <= (_quantities[product.id] ?? 0)) {
      setState(
        () => _error = 'There are no more units available for this SKU.',
      );
    } else {
      _add(product);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    final products = ref.watch(productsProvider);
    final contacts = customers.asData?.value ?? [];
    final inventory = products.asData?.value ?? [];
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existing == null ? 'New order' : 'Edit pending order',
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (var index = 0; index < _steps.length; index++)
                      Chip(
                        label: Text(_steps[index]),
                        avatar: index < _step
                            ? const Icon(Icons.check, size: 17)
                            : null,
                        backgroundColor: index == _step
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                PremiumCard(
                  padding: const EdgeInsets.all(16),
                  child: switch (_step) {
                    0 => customers.when(
                      data: _customerStep,
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => TextButton(
                        onPressed: () => ref.invalidate(customersProvider),
                        child: Text('${orderError(error)} Retry'),
                      ),
                    ),
                    1 => products.when(
                      data: _productStep,
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => TextButton(
                        onPressed: () => ref.invalidate(productsProvider),
                        child: Text('${orderError(error)} Retry'),
                      ),
                    ),
                    2 => _paymentStep(inventory),
                    _ => _reviewStep(inventory),
                  },
                ),
                if (_error case final error?)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_step > (widget.existing == null ? 0 : 1))
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _step--;
                                _error = null;
                              }),
                        child: const Copy('Back'),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed:
                            _busy ||
                                (_step == 0 && !customers.hasValue) ||
                                (_step >= 1 && !products.hasValue)
                            ? null
                            : () => _step == 3
                                  ? _save(inventory)
                                  : _next(contacts, inventory),
                        child: Text(
                          _busy
                              ? 'Saving…'
                              : _step == 3
                              ? 'Save order'
                              : 'Continue',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _customerStep(List<Customer> customers) {
    final normalized = normalizeSriLankanPhone(_phone.text);
    final existing = customers
        .where((item) => item.phone == normalized)
        .firstOrNull;
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    final suggestions = existing == null && digits.length >= 3
        ? customers
              .where(
                (item) =>
                    item.phone.contains(digits) ||
                    (digits.startsWith('0') &&
                        item.phone.contains(digits.substring(1))),
              )
              .take(5)
              .toList()
        : <Customer>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            label: Copy('Customer phone'),
            hintText: '077 123 4567',
          ),
        ),
        for (final suggestion in suggestions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(suggestion.name),
            subtitle: Text(suggestion.phone),
            onTap: () => setState(() => _phone.text = suggestion.phone),
          ),
        const SizedBox(height: 12),
        if (existing != null) ...[
          Text(existing.name, style: Theme.of(context).textTheme.titleLarge),
          Text('${existing.address}, ${existing.city}'),
          AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            child: existing.needsReview
                ? Card(
                    key: ValueKey(existing.phone),
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber),
                      title: const Copy('Review this customer’s history'),
                      subtitle: Text(
                        '${existing.stats.cancelled} cancelled · ${existing.stats.returned} returned · ${existing.stats.failed} failed delivery',
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ] else if (normalized != null)
          CustomerFields(
            key: _customerForm,
            phone: normalized,
            customer: _customer?.phone == normalized ? _customer : null,
          ),
      ],
    );
  }

  Widget _productStep(List<InventoryProduct> products) {
    final query = _search.text.trim().toLowerCase();
    final available = products
        .where(
          (item) => '${item.details.name} ${item.details.sku}'
              .toLowerCase()
              .contains(query),
        )
        .take(35);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            label: Copy('Search product or SKU'),
            suffixIcon: IconButton(
              onPressed: () => _scan(products),
              tooltip: 'Scan SKU',
              icon: const Icon(Icons.qr_code_scanner),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_quantities.isNotEmpty)
          Text('Selected · ${_quantities.length} products'),
        for (final entry in _quantities.entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              products
                      .where((item) => item.id == entry.key)
                      .firstOrNull
                      ?.details
                      .name ??
                  'Unavailable product',
            ),
            subtitle: Text('Quantity ${entry.value}'),
            trailing: IconButton(
              tooltip: 'Remove one unit',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => setState(() {
                if (entry.value == 1) {
                  _quantities.remove(entry.key);
                } else {
                  _quantities[entry.key] = entry.value - 1;
                }
              }),
            ),
          ),
        if (_quantities.isNotEmpty) const Divider(),
        if (available.isEmpty)
          const Text('No products found. Add stock in Inventory first.'),
        for (final product in available)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(product.details.name),
            subtitle: Text(
              '${lkr(product.details.price)} · ${product.quantity} in stock',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Add one unit',
              onPressed: product.quantity <= (_quantities[product.id] ?? 0)
                  ? null
                  : () => _add(product),
            ),
          ),
      ],
    );
  }

  Widget _paymentStep(List<InventoryProduct> products) => Form(
    key: _paymentForm,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_decision == CustomerReview.advance)
          const Text(
            'Advance payment required. You can save pending until it is received.',
          ),
        for (final field in {
          'Delivery charge (LKR)': _delivery,
          'Discount (LKR)': _discount,
          'Advance received (LKR)': _advance,
        }.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: field.value,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: field.key),
              onChanged: (_) => setState(() {}),
              validator: (value) => toCents(value ?? '') == null
                  ? 'Enter a valid LKR amount.'
                  : null,
            ),
          ),
        DropdownButtonFormField<OrderPayment>(
          value: _payment,
          isExpanded: true,
          decoration: const InputDecoration(label: Copy('Payment method')),
          items: [
            for (final choice in OrderPayment.values)
              DropdownMenuItem(value: choice, child: Copy(choice.label)),
          ],
          onChanged: (value) => setState(() => _payment = value!),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _source,
          isExpanded: true,
          decoration: const InputDecoration(label: Copy('Order source')),
          items: [
            for (final source in [
              'WhatsApp',
              'Instagram',
              'Facebook',
              'TikTok',
              'Website',
              'Other',
            ])
              DropdownMenuItem(value: source, child: Text(source)),
          ],
          onChanged: (value) => setState(() => _source = value!),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<StockTiming>(
          value: _timing,
          isExpanded: true,
          decoration: const InputDecoration(label: Copy('Deduct stock')),
          items: [
            for (final timing in StockTiming.values)
              DropdownMenuItem(value: timing, child: Text(timing.label)),
          ],
          onChanged: (value) => setState(() => _timing = value!),
        ),
        const SizedBox(height: 12),
        Text(
          'Order total: ${lkr(_totals(products).total)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );

  Widget _reviewStep(List<InventoryProduct> products) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(_customer!.name, style: Theme.of(context).textTheme.titleLarge),
      Text('${_customer!.phone} · ${_customer!.city}'),
      const SizedBox(height: 10),
      for (final product in _chosen(products))
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(product.details.name),
          trailing: Text(
            '${_quantities[product.id]} × ${lkr(product.details.price)}',
          ),
        ),
      const Divider(),
      Text('Total ${lkr(_totals(products).total)} · ${_payment.label}'),
      Text('Deduct stock ${_timing.label.toLowerCase()}'),
      if (_override) const Text('Blacklist override will be recorded.'),
      const SizedBox(height: 12),
      TextField(
        controller: _notes,
        enabled: !_busy,
        maxLength: 1000,
        decoration: const InputDecoration(labelText: 'Order notes (optional)'),
      ),
      if (widget.existing != null)
        const Text(
          'Saving updates the items and totals using current catalogue prices.',
        ),
      if (widget.existing == null)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Copy('Confirm immediately'),
          value: _confirm,
          onChanged: _busy ? null : (value) => setState(() => _confirm = value),
        ),
    ],
  );
}
