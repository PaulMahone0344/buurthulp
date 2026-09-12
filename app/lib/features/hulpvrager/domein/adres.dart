/// Straat, postcode en plaats als een regel voor hh_klussen.adres:
/// "Prins Bernhardlaan 12, 4003 AB Tiel". Lege delen worden overgeslagen,
/// dubbele spaties en randspaties verdwijnen.
String stelAdresSamen({
  required String adres,
  required String postcode,
  required String plaats,
}) {
  final straat = _schoon(adres);
  final achter = _schoon('${_schoon(postcode)} ${_schoon(plaats)}');
  return [straat, achter].where((deel) => deel.isNotEmpty).join(', ');
}

String _schoon(String tekst) => tekst.trim().replaceAll(RegExp(r'\s+'), ' ');
