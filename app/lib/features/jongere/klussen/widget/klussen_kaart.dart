import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../design/dichtheid_scope.dart';
import '../../../../design/lijn.dart';
import '../../../../l10n/teksten_klussen_nl.dart';
import '../../../../theme.dart';
import '../../../hulpvrager/domein/klustype_icoon.dart';
import '../domein/afstand.dart';
import '../domein/wanneer_tekst.dart';
import '../model/hh_klus.dart';

/// De kaart van J12: OpenStreetMap-tegels (flutter_map, geen sleutel) met
/// een marker per klus die coördinaten heeft. Tik op een marker opent J13.
/// De tegel-User-Agent is nl.heitjehulp.app (OSM-tegelbeleid).
class KlussenKaart extends StatelessWidget {
  const KlussenKaart({
    required this.klussen,
    required this.tegels,
    required this.onKlus,
    this.middelpunt,
    super.key,
  });

  /// Alleen klussen met coördinaten worden getekend.
  final List<HhKlus> klussen;
  final TileProvider tegels;
  final ValueChanged<HhKlus> onKlus;
  final HhPunt? middelpunt;

  static const tegelUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const tegelUserAgent = 'nl.heitjehulp.app';

  /// Verplicht volgens het tegelbeleid van OpenStreetMap.
  static const bronvermelding = '© OpenStreetMap-bijdragers';

  /// Tiel, tot de eerste klus met locatie het middelpunt bepaalt.
  static const standaardMiddelpunt = LatLng(51.886, 5.43);
  static const standaardZoom = 13.5;

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    final markerMaat = HhMaten.avatar(dichtheid);
    final centrum = middelpunt == null
        ? standaardMiddelpunt
        : LatLng(middelpunt!.lat, middelpunt!.lon);

    return Semantics(
      container: true,
      label: TekstenKlussenNl.j12KaartLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HhRadius.groot),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: centrum,
            initialZoom: standaardZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: tegelUrl,
              userAgentPackageName: tegelUserAgent,
              tileProvider: tegels,
            ),
            MarkerLayer(
              markers: [
                for (final klus in klussen)
                  if (klus.heeftCoordinaten)
                    Marker(
                      point: LatLng(klus.lat!, klus.lon!),
                      width: markerMaat,
                      height: markerMaat,
                      child: KlusMarker(
                        klus: klus,
                        maat: markerMaat,
                        onTik: () => onKlus(klus),
                      ),
                    ),
              ],
            ),
            const _Bronvermelding(),
          ],
        ),
      ),
    );
  }
}

/// Bronvermelding rechtsonder. Eigen widget in plaats van
/// SimpleAttributionWidget: die zet de tekst in een Row die bij 200 procent
/// uit de kaart loopt. Een losse Text wikkelt gewoon.
class _Bronvermelding extends StatelessWidget {
  const _Bronvermelding();

  @override
  Widget build(BuildContext context) {
    final dichtheid = HhDichtheidScope.van(context);
    return Align(
      alignment: Alignment.bottomRight,
      child: ColoredBox(
        color: HhKleuren.achtergrond,
        child: Padding(
          padding: EdgeInsets.all(HhRuimte.voor(HhRuimte.xs, dichtheid)),
          child: Text(
            KlussenKaart.bronvermelding,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ),
    );
  }
}

/// Een ronde marker met het icoon van de klussoort. Raakvlak is de
/// avatarmaat uit theme.dart (44 normaal).
class KlusMarker extends StatelessWidget {
  const KlusMarker({
    required this.klus,
    required this.maat,
    required this.onTik,
    super.key,
  });

  final HhKlus klus;
  final double maat;
  final VoidCallback onTik;

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: TekstenKlussenNl.j12Marker(metHoofdletter(klus.klustypeNaam)),
      onTap: onTik,
      excludeSemantics: true,
      child: Material(
        color: schema.primary,
        shape: CircleBorder(
          side: BorderSide(
            color: HhKleuren.opPrimair,
            width: HhLijn.dik(context),
          ),
        ),
        child: InkWell(
          onTap: onTik,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: maat,
            height: maat,
            child: Icon(
              KlustypeIcoon.voor(klus.klustypeIcoon),
              size: maat * 0.55,
              color: HhKleuren.opPrimair,
            ),
          ),
        ),
      ),
    );
  }
}
