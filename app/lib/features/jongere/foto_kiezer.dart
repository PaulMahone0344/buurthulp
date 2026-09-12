import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/hh_fout.dart';
import '../../core/result.dart';

enum HhFotoBron { camera, galerij }

/// Een gekozen foto, al ingelezen als bytes en al verkleind.
class HhFoto {
  const HhFoto({required this.bytes, required this.bestandsnaam});

  final Uint8List bytes;
  final String bestandsnaam;
}

/// Praat met camera en galerij. Nergens anders in de app staat
/// image_picker (zelfde regel als ObyCom's MediaPickerGateway). Geeft
/// Ok(null) als de gebruiker annuleert; Err als het toestel geen camera
/// heeft of de plugin faalt.
abstract interface class FotoKiezer {
  Future<Result<HhFoto?>> kies(HhFotoBron bron, {bool isSelfie = false});
}

class ImagePickerFotoKiezer implements FotoKiezer {
  ImagePickerFotoKiezer([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Uploadgrens uit de M3-opdracht: verkleinen tot max 1600 px lange zijde
  /// vóór het versturen. image_picker doet dat zelf via maxWidth/maxHeight
  /// en codeert opnieuw als jpeg, dus HEIC van iOS komt ook goed aan.
  static const maxLangeZijde = 1600.0;
  static const kwaliteit = 85;

  @override
  Future<Result<HhFoto?>> kies(HhFotoBron bron, {bool isSelfie = false}) async {
    try {
      final bestand = await _picker.pickImage(
        source: switch (bron) {
          HhFotoBron.camera => ImageSource.camera,
          HhFotoBron.galerij => ImageSource.gallery,
        },
        maxWidth: maxLangeZijde,
        maxHeight: maxLangeZijde,
        imageQuality: kwaliteit,
        preferredCameraDevice: isSelfie
            ? CameraDevice.front
            : CameraDevice.rear,
        requestFullMetadata: false,
      );
      if (bestand == null) return Result.ok(null);
      return Result.ok(
        HhFoto(bytes: await bestand.readAsBytes(), bestandsnaam: bestand.name),
      );
    } on PlatformException catch (e) {
      return Result.err(HhFout(HhFoutSoort.onbekend, detail: e.code));
    }
  }
}

/// Fake voor tests: geeft [volgende] terug (of null = geannuleerd) en
/// onthoudt waarmee hij is aangeroepen.
class FakeFotoKiezer implements FotoKiezer {
  FakeFotoKiezer({this.volgende});

  HhFoto? volgende;
  HhFout? volgendeFout;
  final List<({HhFotoBron bron, bool isSelfie})> aanroepen = [];

  @override
  Future<Result<HhFoto?>> kies(HhFotoBron bron, {bool isSelfie = false}) async {
    aanroepen.add((bron: bron, isSelfie: isSelfie));
    final fout = volgendeFout;
    if (fout != null) {
      volgendeFout = null;
      return Result.err(fout);
    }
    return Result.ok(volgende);
  }
}

final fotoKiezerProvider = Provider<FotoKiezer>(
  (ref) => ImagePickerFotoKiezer(),
);
