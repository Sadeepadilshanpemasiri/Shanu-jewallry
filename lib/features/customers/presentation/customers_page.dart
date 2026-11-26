import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/cursor_catalog.dart';
import '../../orders/presentation/order_details_page.dart';
import '../../orders/presentation/order_format.dart';
import '../../orders/presentation/order_providers.dart';
import '../domain/customer.dart';
import 'customer_form.dart';
import 'customer_providers.dart';

Future<void> openCustomerProfile(BuildContext context, Customer customer) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CustomerProfile(
          phone: customer.phone,
          initial: customer,
          onEdit: (profile) => showModalBottomSheet<bool>(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            showDragHandle: true,
            constraints: const BoxConstraints(maxWidth: 600),
            builder: (_) => _CustomerEditor(customer: profile),
          ),
        ),
      ),
    );

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  String _query = '';
  int _revision = 0;

  Future<void> _edit([Customer? customer]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (_) => _CustomerEditor(customer: customer),
    );
    if (mounted && saved == true) {
      setState(() => _revision++);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Customer saved.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Copy('Customers'),
      leading: BackButton(onPressed: () => context.go('/')),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _edit,
      icon: const Icon(Icons.person_add_alt),
      label: const Copy('Add customer'),
    ),
    body: CursorCatalog<Customer>(
      revision: _revision,
      recordId: (customer) => customer.phone,
      first: () => ref.read(customerRepositoryProvider).readCustomers(),
      full: _query.trim().isEmpty ? null : ref.watch(customersProvider),
      refreshFull: () => ref.invalidate(customersProvider),
      errorText: orderError,
      builder: (all, footer, refresh) {
        final query = _query.trim().toLowerCase();
        final contact = normalizeSriLankanPhone(query) ?? query;
        final matches = all
            .where(
              (customer) =>
                  '${customer.name} ${customer.city} ${customer.address}'
                      .toLowerCase()
                      .contains(query) ||
                  customer.phone.contains(contact),
            )
            .toList();
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    onChanged: (text) => setState(() => _query = text),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Search by name, phone or address',
                    ),
                  ),
                ),
                if (matches.isEmpty && footer == null)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      all.isEmpty
                          ? 'Add a customer here or when creating an order.'
                          : 'No matching customers.',
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: refresh,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: matches.length + (footer == null ? 0 : 1),
                      itemBuilder: (context, index) {
                        if (index == matches.length) return footer!;
                        final customer = matches[index];
                        return Card(
                          child: ListTile(
                            title: Text(customer.name),
                            subtitle: Text(
                              '${customer.phone} · ${customer.stats.total} orders',
                            ),
                            trailing: CustomerRiskBadge(customer),
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => CustomerProfile(
                                  phone: customer.phone,
                                  initial: customer,
                                  onEdit: _edit,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class CustomerRiskBadge extends StatelessWidget {
  const CustomerRiskBadge(this.customer, {super.key});
  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (text, background, foreground) = customer.blacklisted
        ? ('Blacklisted', colors.errorContainer, colors.onErrorContainer)
        : customer.watchlisted
        ? ('Watchlist', colors.tertiaryContainer, colors.onTertiaryContainer)
        : switch (customer.stats.risk) {
            CustomerRisk.low => (
              'Low risk',
              const Color(0xffdcefe2),
              const Color(0xff173927),
            ),
            CustomerRisk.medium => (
              'Review',
              const Color(0xffffe8a3),
              const Color(0xff493405),
            ),
            CustomerRisk.high => (
              'High risk',
              colors.errorContainer,
              colors.onErrorContainer,
            ),
          };
    return Chip(
      label: Text(text, style: TextStyle(color: foreground)),
      backgroundColor: background,
    );
  }
}

class CustomerProfile extends ConsumerWidget {
  const CustomerProfile({
    super.key,
    required this.phone,
    required this.initial,
    required this.onEdit,
  });
  final String phone;
  final Customer initial;
  final Future<void> Function(Customer) onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer =
        ref
            .watch(customersProvider)
            .asData
            ?.value
            .where((record) => record.phone == phone)
            .firstOrNull ??
        initial;
    final stats = customer.stats;
    final orders = ref.watch(ordersProvider(phone: phone));
    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          IconButton(
            onPressed: () => onEdit(customer),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit customer',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SelectableText(phone),
          Text('${customer.address}, ${customer.city}'),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: CustomerRiskBadge(customer),
          ),
          if (customer.restrictionReason.isNotEmpty)
            Text(customer.restrictionReason),
          if (customer.notes.isNotEmpty) Text(customer.notes),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final metric in {
                'Orders': stats.total,
                'Delivered': stats.delivered,
                'Cancelled': stats.cancelled,
                'Cancelled after shipping': stats.cancelledAfterShipping,
                'Returned': stats.returned,
                'Failed deliveries': stats.failed,
              }.entries)
                Chip(label: Text('${metric.key} ${metric.value}')),
            ],
          ),
          const SizedBox(height: 16),
          Copy('Order history', style: Theme.of(context).textTheme.titleLarge),
          orders.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text(orderError(error)),
            data: (items) => items.isEmpty
                ? const Copy('No orders yet.')
                : Column(
                    children: [
                      for (final order in items)
                        ListTile(
                          title: Text(order.number),
                          subtitle: Text(
                            '${order.status.label} · ${orderDate(order.createdAt)}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => openOrderDetails(context, order),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CustomerEditor extends ConsumerStatefulWidget {
  const _CustomerEditor({this.customer});
  final Customer? customer;
  @override
  ConsumerState<_CustomerEditor> createState() => _CustomerEditorState();
}

class _CustomerEditorState extends ConsumerState<_CustomerEditor> {
  late final _phone = TextEditingController(text: widget.customer?.phone);
  final _fields = GlobalKey<CustomerFieldsState>();
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_busy) return;
    final phone = normalizeSriLankanPhone(_phone.text);
    final value = _fields.currentState!.read();
    if (phone == null || value == null) {
      setState(
        () => _error = phone == null
            ? 'Enter a valid Sri Lankan phone number.'
            : null,
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final customer = Customer(
        phone: phone,
        name: value.name,
        address: value.address,
        city: value.city,
        notes: value.notes,
        watchlisted: value.watchlisted,
        blacklisted: value.blacklisted,
        restrictionReason: value.restrictionReason,
      );
      await ref
          .read(customerRepositoryProvider)
          .saveCustomer(customer, editing: widget.customer != null);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = orderError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .92,
    child: ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      children: [
        Text(
          widget.customer == null ? 'Add customer' : 'Edit customer',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          enabled: widget.customer == null && !_busy,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            label: Copy('Sri Lankan phone number'),
          ),
        ),
        const SizedBox(height: 12),
        AbsorbPointer(
          absorbing: _busy,
          child: CustomerFields(
            key: _fields,
            phone: '',
            customer: widget.customer,
            showRestrictions: true,
          ),
        ),
        if (_error case final message?)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(message),
          ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : 'Save customer'),
        ),
      ],
    ),
  );
}
