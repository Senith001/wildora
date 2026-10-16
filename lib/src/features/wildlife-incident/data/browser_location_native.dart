import 'package:geolocator/geolocator.dart';

Future<Position> browserPosition({
  required bool highAccuracy,
  required Duration timeLimit,
}) => throw UnsupportedError('Browser location is only available on the web.');
