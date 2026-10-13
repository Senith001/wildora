import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Deterministic tiles keep widget tests independent of internet and disk cache.
class MapTestTiles extends TileProvider {
  MapTestTiles({this.fail = false});
  bool fail;
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(
        fail
            ? Uint8List(0)
            : base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGOYeWbmfwAG/gL+8h1avgAAAABJRU5ErkJggg==',
              ),
      );
}
