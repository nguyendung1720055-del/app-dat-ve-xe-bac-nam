import 'dart:math';

/// Bến xe dọc QL1A theo thứ tự Bắc → Nam. Tọa độ và số km là dữ liệu mẫu
/// gần đúng cho bài thực hành, không phải số liệu đo đạc chính thức.
const stations = [
  ('Bến xe Nước Ngầm', 'Hà Nội', 20.9645, 105.8434, 0),
  ('Bến xe Phủ Lý', 'Hà Nam', 20.5417, 105.9136, 58),
  ('Bến xe Ninh Bình', 'Ninh Bình', 20.2540, 105.9750, 93),
  ('Bến xe phía Bắc Thanh Hóa', 'Thanh Hóa', 19.8270, 105.7790, 153),
  ('Bến xe Bắc Vinh', 'Nghệ An', 18.7006, 105.6800, 291),
  ('Bến xe Hà Tĩnh', 'Hà Tĩnh', 18.3400, 105.9050, 340),
  ('Bến xe Đồng Hới', 'Quảng Bình', 17.4700, 106.6000, 490),
  ('Bến xe Đông Hà', 'Quảng Trị', 16.8100, 107.1000, 590),
  ('Bến xe phía Nam Huế', 'Thừa Thiên Huế', 16.4500, 107.5950, 660),
  ('Bến xe Trung tâm Đà Nẵng', 'Đà Nẵng', 16.0573, 108.1755, 765),
  ('Bến xe Tam Kỳ', 'Quảng Nam', 15.5700, 108.4800, 830),
  ('Bến xe Quảng Ngãi', 'Quảng Ngãi', 15.1190, 108.7950, 890),
  ('Bến xe Quy Nhơn', 'Bình Định', 13.7650, 109.2120, 1065),
  ('Bến xe Tuy Hòa', 'Phú Yên', 13.0900, 109.3000, 1160),
  ('Bến xe phía Nam Nha Trang', 'Khánh Hòa', 12.2140, 109.1800, 1280),
  ('Bến xe Phan Rang', 'Ninh Thuận', 11.5700, 108.9900, 1385),
  ('Bến xe Phan Thiết', 'Bình Thuận', 10.9330, 108.1000, 1530),
  ('Bến xe Miền Đông mới', 'TP. Hồ Chí Minh', 10.8790, 106.8160, 1710),
];

Map<String, dynamic> stationJson(int i) => {
  'name': stations[i].$1,
  'province': stations[i].$2,
  'lat': stations[i].$3,
  'lng': stations[i].$4,
};

int departureOf(Map<String, dynamic> trip) =>
    DateTime.parse(
      '${trip['date']}T${trip['time']}:00+07:00',
    ).millisecondsSinceEpoch ~/
    1000;

int? durationSeconds(Map<String, dynamic> trip) {
  final h = int.tryParse(
    RegExp(r'\d+').firstMatch('${trip['arrival']}')?.group(0) ?? '',
  );
  return h == null ? null : h * 3600;
}

/// Các điểm dừng của chuyến theo chiều chạy, kèm km tính từ bến đầu và
/// giờ đến dự kiến. Rỗng nếu chuyến không nằm trên tuyến có dữ liệu.
List<Map<String, dynamic>> tripStops(Map<String, dynamic> trip) {
  final a = stations.indexWhere((s) => s.$1 == trip['pickup']);
  final b = stations.indexWhere((s) => s.$1 == trip['dropoff']);
  final duration = durationSeconds(trip);
  if (a < 0 || b < 0 || a == b || duration == null) return [];
  final order = a < b
      ? [for (var i = a; i <= b; i++) i]
      : [for (var i = a; i >= b; i--) i];
  final total = (stations[b].$5 - stations[a].$5).abs();
  final start = departureOf(trip);
  return [
    for (final i in order)
      {
        ...stationJson(i),
        'km': (stations[i].$5 - stations[a].$5).abs(),
        'eta':
            start +
            (duration * (stations[i].$5 - stations[a].$5).abs() / total)
                .round(),
      },
  ];
}

double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final h =
      pow(sin(dLat / 2), 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLng / 2), 2);
  return 2 * r * asin(sqrt(h));
}

/// Chiếu một tọa độ lên đường nối các điểm dừng, trả về số km đã đi.
double progressKm(List<Map<String, dynamic>> stops, double lat, double lng) {
  var best = double.infinity, km = 0.0;
  for (var i = 0; i + 1 < stops.length; i++) {
    final p = stops[i], q = stops[i + 1];
    // Mặt phẳng xấp xỉ quanh đoạn đang xét; đủ chính xác cho vài trăm km.
    final k = cos((p['lat'] as double) * pi / 180);
    final ax = (p['lng'] as double) * k, ay = p['lat'] as double;
    final bx = (q['lng'] as double) * k, by = q['lat'] as double;
    final px = lng * k, py = lat;
    final len2 = pow(bx - ax, 2) + pow(by - ay, 2);
    final t = len2 == 0
        ? 0.0
        : (((px - ax) * (bx - ax) + (py - ay) * (by - ay)) / len2).clamp(
            0.0,
            1.0,
          );
    final d = distanceKm(
      lat,
      lng,
      ay + t * (by - ay),
      (ax + t * (bx - ax)) / k,
    );
    if (d < best) {
      best = d;
      km = (p['km'] as int) + t * ((q['km'] as int) - (p['km'] as int));
    }
  }
  return km;
}

/// Vị trí ước tính theo lịch chạy khi chưa có GPS của xe.
({double lat, double lng, double km}) scheduledPosition(
  List<Map<String, dynamic>> stops,
  int now,
) {
  final start = stops.first['eta'] as int, end = stops.last['eta'] as int;
  final total = stops.last['km'] as int;
  final km = total * ((now - start) / (end - start)).clamp(0.0, 1.0);
  for (var i = 0; i + 1 < stops.length; i++) {
    final p = stops[i], q = stops[i + 1];
    if (km <= (q['km'] as int)) {
      final span = (q['km'] as int) - (p['km'] as int);
      final t = span == 0 ? 0.0 : (km - (p['km'] as int)) / span;
      return (
        lat:
            (p['lat'] as double) +
            t * ((q['lat'] as double) - (p['lat'] as double)),
        lng:
            (p['lng'] as double) +
            t * ((q['lng'] as double) - (p['lng'] as double)),
        km: km,
      );
    }
  }
  return (
    lat: stops.last['lat'] as double,
    lng: stops.last['lng'] as double,
    km: km,
  );
}
