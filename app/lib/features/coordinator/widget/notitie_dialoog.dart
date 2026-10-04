import 'package:flutter/material.dart';

import '../../../l10n/teksten_meldkamer_nl.dart';

/// B11: vraagt een notitie of reden in een dialoog. Geeft de (getrimde)
/// tekst terug, of null bij Annuleren. [isVerplicht] + [minLengte] bepalen
/// wanneer de bevestigknop werkt; de knop staat uit tot de tekst klopt.
Future<String?> vraagNotitie(
  BuildContext context, {
  required String titel,
  required String bevestig,
  required String label,
  String? uitleg,
  String beginTekst = '',
  bool isVerplicht = false,
  int minLengte = 1,
  int maxLengte = 500,
  bool isGevaar = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _NotitieDialoog(
      titel: titel,
      bevestig: bevestig,
      label: label,
      uitleg: uitleg,
      beginTekst: beginTekst,
      isVerplicht: isVerplicht,
      minLengte: minLengte,
      maxLengte: maxLengte,
      isGevaar: isGevaar,
    ),
  );
}

/// Ja/nee-vraag zonder invoer. Geeft true bij bevestigen.
Future<bool> vraagBevestiging(
  BuildContext context, {
  required String titel,
  required String uitleg,
  required String bevestig,
}) async {
  final ja = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titel),
      content: Text(uitleg),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(TekstenMeldkamerNl.annuleren),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(bevestig),
        ),
      ],
    ),
  );
  return ja == true;
}

class _NotitieDialoog extends StatefulWidget {
  const _NotitieDialoog({
    required this.titel,
    required this.bevestig,
    required this.label,
    required this.uitleg,
    required this.beginTekst,
    required this.isVerplicht,
    required this.minLengte,
    required this.maxLengte,
    required this.isGevaar,
  });

  final String titel;
  final String bevestig;
  final String label;
  final String? uitleg;
  final String beginTekst;
  final bool isVerplicht;
  final int minLengte;
  final int maxLengte;
  final bool isGevaar;

  @override
  State<_NotitieDialoog> createState() => _NotitieDialoogState();
}

class _NotitieDialoogState extends State<_NotitieDialoog> {
  late final TextEditingController _tekst = TextEditingController(
    text: widget.beginTekst,
  );

  @override
  void dispose() {
    _tekst.dispose();
    super.dispose();
  }

  bool get _klopt {
    final t = _tekst.text.trim();
    if (t.length > widget.maxLengte) return false;
    return !widget.isVerplicht || t.length >= widget.minLengte;
  }

  @override
  Widget build(BuildContext context) {
    final kleuren = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.titel),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.uitleg != null) ...[
              Text(widget.uitleg!),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _tekst,
              maxLines: 3,
              maxLength: widget.maxLengte,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: widget.label,
                helperText: TekstenMeldkamerNl.notitieHulp,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(TekstenMeldkamerNl.annuleren),
        ),
        TextButton(
          style: widget.isGevaar
              ? TextButton.styleFrom(foregroundColor: kleuren.error)
              : null,
          onPressed: _klopt
              ? () => Navigator.of(context).pop(_tekst.text.trim())
              : null,
          child: Text(widget.bevestig),
        ),
      ],
    );
  }
}
