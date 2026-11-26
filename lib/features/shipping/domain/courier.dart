class Courier {
  const Courier({
    required this.name,
    required this.template,
    this.active = true,
  });

  final String name, template;
  final bool active;
  String get key => courierKey(name);
  Uri? trackingLink(String waybill) => trackingUri(template, waybill);
}

String courierKey(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String? normalizedWaybill(String value) {
  final clean = value.trim();
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9 ./_-]{0,119}$').hasMatch(clean)) {
    return null;
  }
  return clean.replaceAll(' ', '').toUpperCase();
}

String waybillDocumentId(String courier, String waybill) =>
    Uri.encodeComponent('${courierKey(courier)}/${normalizedWaybill(waybill)}');

Uri? trackingUri(String template, String waybill) {
  const placeholder = '{tracking}';
  const marker = 'trackingplaceholder123';
  final source = template.trim();
  if (normalizedWaybill(waybill) == null || !source.contains(placeholder)) {
    return null;
  }
  final base = Uri.tryParse(source.replaceAll(placeholder, marker));
  if (base == null ||
      base.scheme != 'https' ||
      base.host.isEmpty ||
      base.host.contains(marker) ||
      base.userInfo.isNotEmpty ||
      !(base.path.contains(marker) ||
          base.query.contains(marker) ||
          base.fragment.contains(marker))) {
    return null;
  }
  final result = Uri.tryParse(
    source.replaceAll(placeholder, Uri.encodeComponent(waybill.trim())),
  );
  return result?.authority == base.authority && result?.scheme == base.scheme
      ? result
      : null;
}

String parcelLabelCode(String orderId) => 'JBM:$orderId';

String? parcelLabelOrderId(String value) {
  final match = RegExp(
    r'^JBM:([A-Za-z0-9_-]{1,120})$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  return match?[1];
}

class ShippingFailure implements Exception {
  const ShippingFailure(this.message);
  final String message;
}
