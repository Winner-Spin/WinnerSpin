import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

const _assetPath =
    'assets/animations/Bomb_Animation_ORIGINAL_LOGIC_fuse_burn_spark_synced_tip_removed.json';

void main() {
  test('bomb asset preserves its timeline, fuse frames, and decode budget', () {
    final root =
        jsonDecode(File(_assetPath).readAsStringSync()) as Map<String, dynamic>;
    final assets = (root['assets'] as List).cast<Map<String, dynamic>>();
    final embedded = assets.where(_isEmbeddedImage).toList();
    final explosionFrames = embedded.where(_isExplosionFrame).toList();
    final allLayers = <Map<String, dynamic>>[
      ...(root['layers'] as List).cast<Map<String, dynamic>>(),
      for (final asset in assets)
        if (asset['layers'] case final List layers)
          ...layers.cast<Map<String, dynamic>>(),
    ];

    expect(root['w'], 360);
    expect(root['h'], 360);
    expect(root['fr'], 60);
    expect(root['ip'], 0);
    expect(root['op'], 85);
    expect(embedded, hasLength(48));
    expect(explosionFrames, hasLength(7));
    expect(assets.any((asset) => asset['id'] == 'image_11'), isFalse);

    final assetIds = assets.map((asset) => asset['id'] as String).toSet();
    for (final layer in allLayers) {
      if (layer['refId'] case final String reference) {
        expect(assetIds, contains(reference));
      }
    }

    final fuseAssets = embedded
        .where(
          (asset) => (asset['id'] as String).startsWith('image_fuse_burn_'),
        )
        .length;
    final fuseLayers = allLayers
        .where(
          (layer) =>
              (layer['refId'] as String?)?.startsWith('image_fuse_burn_') ??
              false,
        )
        .length;
    expect(fuseAssets, 36);
    expect(fuseLayers, 36);

    var decodedBytes = 0;
    var explosionDecodedBytes = 0;
    for (final asset in embedded) {
      final declaredWidth = asset['w'] as int;
      final declaredHeight = asset['h'] as int;
      final dataUri = asset['p'] as String;
      final bytes = base64Decode(dataUri.substring(dataUri.indexOf(',') + 1));

      expect(_hasPngSignature(bytes), isTrue, reason: asset['id'] as String);
      expect(_readUint32(bytes, 16), declaredWidth);
      expect(_readUint32(bytes, 20), declaredHeight);
      decodedBytes += declaredWidth * declaredHeight * 4;
      if (_isExplosionFrame(asset)) {
        expect(declaredWidth, lessThanOrEqualTo(512));
        expect(declaredHeight, lessThanOrEqualTo(512));
        explosionDecodedBytes += declaredWidth * declaredHeight * 4;
      }
    }

    final bombBody = embedded.singleWhere((asset) => asset['id'] == 'image_12');
    expect(bombBody['w'], 1000);
    expect(bombBody['h'], 1000);
    expect(explosionDecodedBytes, lessThan(6 * 1024 * 1024));
    expect(decodedBytes, lessThan(24 * 1024 * 1024));
  });
}

bool _isExplosionFrame(Map<String, dynamic> asset) {
  final id = asset['id'];
  if (id is! String || !id.startsWith('image_')) return false;
  final index = int.tryParse(id.substring('image_'.length));
  return index != null && index <= 6;
}

bool _isEmbeddedImage(Map<String, dynamic> asset) {
  final path = asset['p'];
  return path is String && path.startsWith('data:image/');
}

bool _hasPngSignature(Uint8List bytes) {
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < 24) return false;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return false;
  }
  return true;
}

int _readUint32(Uint8List bytes, int offset) {
  return bytes[offset] << 24 |
      bytes[offset + 1] << 16 |
      bytes[offset + 2] << 8 |
      bytes[offset + 3];
}
