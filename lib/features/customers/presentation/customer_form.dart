import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:flutter/material.dart';

import '../domain/customer.dart';

class CustomerFields extends StatefulWidget {
  const CustomerFields({
    super.key,
    required this.phone,
    this.customer,
    this.showRestrictions = false,
  });
  final String phone;
  final Customer? customer;
  final bool showRestrictions;

  @override
  State<CustomerFields> createState() => CustomerFieldsState();
}

class CustomerFieldsState extends State<CustomerFields> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.customer?.name);
  late final _address = TextEditingController(text: widget.customer?.address);
  late final _city = TextEditingController(text: widget.customer?.city);
  late final _notes = TextEditingController(text: widget.customer?.notes);
  late final _reason = TextEditingController(
    text: widget.customer?.restrictionReason,
  );
  late bool _watchlist = widget.customer?.watchlisted ?? false;
  late bool _blacklist = widget.customer?.blacklisted ?? false;

  Customer? read() {
    if (!_form.currentState!.validate()) return null;
    return Customer(
      phone: widget.phone,
      name: _name.text.trim(),
      address: _address.text.trim(),
      city: _city.text.trim(),
      notes: _notes.text.trim(),
      watchlisted: _watchlist,
      blacklisted: _blacklist,
      restrictionReason: _reason.text.trim(),
      stats: widget.customer?.stats ?? const CustomerStats(),
    );
  }

  @override
  void dispose() {
    for (final field in [_name, _address, _city, _notes, _reason]) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(_name, 'Customer name', required: true),
        _field(_address, 'Delivery address', required: true, max: 350),
        _field(_city, 'City or district', required: true),
        if (widget.showRestrictions) ...[
          _field(_notes, 'Private notes', max: 1000),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _watchlist,
            title: const Copy('Watchlist'),
            onChanged: (value) => setState(() => _watchlist = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _blacklist,
            title: const Copy('Blacklist'),
            onChanged: (value) => setState(() => _blacklist = value),
          ),
          if (_watchlist || _blacklist)
            _field(_reason, 'Restriction reason', required: true, max: 300),
        ],
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int max = 120,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      maxLength: max,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label, counterText: ''),
      validator: (value) =>
          required && (value?.trim() ?? '').isEmpty ? 'Required' : null,
    ),
  );
}
