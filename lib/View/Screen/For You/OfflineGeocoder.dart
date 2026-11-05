import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

class OfflineGeocoder {
  OfflineGeocoder._();

  static final OfflineGeocoder instance = OfflineGeocoder._();
  static const String _assetPath = 'assets/data/cities.csv';
  final List<_City> _cities = <_City>[];
  final Map<int, List<int>> _grid = <int, List<int>>{};
  Future<void>? _loading;

  Future<void> _ensureLoaded() {
    return _loading ??= _load();
  }

  Future<void> warmUp() => _ensureLoaded();

  Future<void> _load() async {
    try {
      final String raw = await rootBundle.loadString(_assetPath);

      final List<Object> parsed = await compute(_parseCities, raw);

      final List<String> names = List<String>.from(parsed[0] as List);
      final List<double> lats = List<double>.from(parsed[1] as List);
      final List<double> lons = List<double>.from(parsed[2] as List);

      for (int i = 0; i < names.length; i++) {
        _cities.add(_City(names[i], lats[i], lons[i]));

        _grid.putIfAbsent(_cellKey(lats[i], lons[i]), () => <int>[]).add(i);
      }

      debugPrint('OFFLINE GEOCODER READY = ${_cities.length} cities');
    } catch (e) {
      debugPrint('OFFLINE GEOCODER LOAD ERROR = $e');
      _loading = null; 
    }
  }

  static int _cellKey(double lat, double lon) {
    final int latCell = lat.floor().clamp(-90, 90).toInt();
    final int lonCell = lon.floor().clamp(-180, 180).toInt();
    return (latCell + 90) * 1000 + (lonCell + 180);
  }

  Future<String?> nearestPlaceName(
      double latitude,
      double longitude, {
        double maxKm = 60,
      }) async {
    await _ensureLoaded();

    if (_cities.isEmpty) return null;

    final int latCell = latitude.floor();
    final int lonCell = longitude.floor();

    final double cosLat = math.cos(latitude * math.pi / 180).abs();
    final int lonSpan = math.min(6, (1 / math.max(cosLat, 0.2)).ceil());

    String? bestName;
    double bestKm = double.infinity;

    for (int dLat = -1; dLat <= 1; dLat++) {
      for (int dLon = -lonSpan; dLon <= lonSpan; dLon++) {
        final int la = latCell + dLat;
        final int lo = lonCell + dLon;

        if (la < -90 || la > 90 || lo < -180 || lo > 180) continue;

        final List<int>? bucket = _grid[(la + 90) * 1000 + (lo + 180)];
        if (bucket == null) continue;

        for (final int i in bucket) {
          final _City c = _cities[i];
          final double d = distanceKm(latitude, longitude, c.lat, c.lon);
          if (d < bestKm) {
            bestKm = d;
            bestName = c.name;
          }
        }
      }
    }

    if (bestName == null || bestKm > maxKm) return null;

    return bestName;
  }

  /// Haversine distance in km.
  static double distanceKm(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const double r = 6371.0;

    final double dLat = (lat2 - lat1) * math.pi / 180;
    final double dLon = (lon2 - lon1) * math.pi / 180;

    final double sLat = math.sin(dLat / 2);
    final double sLon = math.sin(dLon / 2);

    final double a =
        sLat * sLat +
            math.cos(lat1 * math.pi / 180) *
                math.cos(lat2 * math.pi / 180) *
                sLon *
                sLon;

    return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
  }
}

class _City {
  final String name;
  final double lat;
  final double lon;

  const _City(this.name, this.lat, this.lon);
}

List<Object> _parseCities(String raw) {
  final List<String> names = <String>[];
  final List<double> lats = <double>[];
  final List<double> lons = <double>[];

  for (final String line in raw.split('\n')) {
    if (line.trim().isEmpty) continue;

    final List<String> p = line.split(',');
    if (p.length < 5) continue;

    final double? lat = double.tryParse(p[1]);
    final double? lon = double.tryParse(p[2]);
    if (lat == null || lon == null) continue;

    names.add(p[0].trim());
    lats.add(lat);
    lons.add(lon);
  }

  return <Object>[names, lats, lons];
}
