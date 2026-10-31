import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../ui.dart';

/// Lấy vị trí hiện tại, xin quyền nếu cần. Lỗi được viết sẵn để hiện cho người dùng.
Future<Position> locate() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw ApiException('Hãy bật định vị (GPS) trên điện thoại.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw ApiException(
      'Ứng dụng chưa được cấp quyền vị trí. Mở Cài đặt để cho phép.',
    );
  }
  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
}

/// Di chuyển bản đồ, bỏ qua nếu bản đồ chưa kịp hiển thị.
void moveMap(MapController map, LatLng to, {double? zoom, double minZoom = 0}) {
  try {
    map.move(to, max(zoom ?? map.camera.zoom, minZoom));
  } catch (_) {}
}

double kmBetween(LatLng a, LatLng b) =>
    const Distance().as(LengthUnit.Meter, a, b) / 1000;

String kmLabel(double km) => km < 1
    ? '${(km * 1000).round()} m'
    : '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';

String clock(int epoch) =>
    DateFormat('HH:mm dd/MM')
        .format(DateTime.fromMillisecondsSinceEpoch(epoch * 1000));

Future<void> openDirections(
  BuildContext context,
  double lat,
  double lng,
) async {
  final ok = await launchUrl(
    Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) toast(context, 'Không mở được ứng dụng bản đồ.');
}

/// Bản đồ OpenStreetMap dùng chung, có ghi nguồn theo yêu cầu của OSM.
class BusMap extends StatelessWidget {
  final MapController? controller;
  final List<LatLng> fit;
  final List<Widget> layers;
  const BusMap({
    super.key,
    this.controller,
    required this.fit,
    this.layers = const [],
  });
  @override
  Widget build(BuildContext context) => FlutterMap(
    mapController: controller,
    options: MapOptions(
      initialCenter: fit.isEmpty ? const LatLng(16.0, 106.5) : fit.first,
      initialZoom: 5.5,
      initialCameraFit: fit.length < 2
          ? null
          : CameraFit.coordinates(
              coordinates: fit,
              padding: const EdgeInsets.all(48),
              maxZoom: 14,
            ),
    ),
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'vn.edu.hutech.bacnam',
      ),
      ...layers,
      const RichAttributionWidget(
        attributions: [TextSourceAttribution('OpenStreetMap contributors')],
      ),
    ],
  );
}

Widget pin(IconData icon, Color color, {double size = 34}) => Container(
  decoration: BoxDecoration(
    color: color,
    shape: BoxShape.circle,
    border: Border.all(color: Colors.white, width: 2.5),
    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
  ),
  child: Icon(icon, color: Colors.white, size: size * 0.55),
);

Widget myLocationDot() => Container(
  decoration: BoxDecoration(
    color: Colors.blue,
    shape: BoxShape.circle,
    border: Border.all(color: Colors.white, width: 3),
    boxShadow: [
      BoxShadow(
        color: Colors.blue.withValues(alpha: 0.35),
        blurRadius: 10,
        spreadRadius: 6,
      ),
    ],
  ),
);

class NearbyStations extends StatefulWidget {
  final Session session;
  const NearbyStations({super.key, required this.session});
  @override
  State<NearbyStations> createState() => _NearbyStationsState();
}

class _NearbyStationsState extends State<NearbyStations> {
  final map = MapController();
  List<Json>? stations;
  LatLng? me;
  String? error, locationError;
  bool locating = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final list = await widget.session.api.call('/stations') as List;
      if (mounted) {
        setState(() => stations = list.map((e) => Json.from(e)).toList());
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
    await findMe();
  }

  Future<void> findMe() async {
    setState(() {
      locating = true;
      locationError = null;
    });
    try {
      final p = await locate();
      if (!mounted) return;
      setState(() => me = LatLng(p.latitude, p.longitude));
      final near = sorted.take(2).map(point);
      try {
        map.fitCamera(
          CameraFit.coordinates(
            coordinates: [me!, ...near],
            padding: const EdgeInsets.all(56),
            maxZoom: 13,
          ),
        );
      } catch (_) {}
    } catch (e) {
      if (mounted) setState(() => locationError = e.toString());
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  LatLng point(Json s) => LatLng(s['lat'], s['lng']);

  List<Json> get sorted {
    final list = [...?stations];
    if (me != null) {
      list.sort(
        (a, b) => kmBetween(me!, point(a)).compareTo(kmBetween(me!, point(b))),
      );
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final list = sorted;
    return Scaffold(
      appBar: AppBar(title: const Text('Bến xe gần bạn')),
      body: stations == null
          ? (error != null
                ? errorPanel(error!, load)
                : const Center(child: CircularProgressIndicator()))
          : Column(
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.42,
                  child: Stack(
                    children: [
                      BusMap(
                        controller: map,
                        fit: list.map(point).toList(),
                        layers: [
                          MarkerLayer(
                            markers: [
                              for (final (i, s) in list.indexed)
                                Marker(
                                  point: point(s),
                                  width: 34,
                                  height: 34,
                                  child: GestureDetector(
                                    onTap: () =>
                                        moveMap(map, point(s), zoom: 13),
                                    child: pin(
                                      Icons.directions_bus,
                                      me != null && i == 0 ? orange : forest,
                                    ),
                                  ),
                                ),
                              if (me != null)
                                Marker(
                                  point: me!,
                                  width: 22,
                                  height: 22,
                                  child: myLocationDot(),
                                ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        right: 12,
                        bottom: 28,
                        child: FloatingActionButton.small(
                          heroTag: 'locate',
                          onPressed: locating ? null : findMe,
                          tooltip: 'Vị trí của tôi',
                          child: locating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location),
                        ),
                      ),
                    ],
                  ),
                ),
                if (locationError != null)
                  MaterialBanner(
                    content: Text(locationError!),
                    leading: const Icon(Icons.location_off, color: orange),
                    actions: [
                      TextButton(
                        onPressed: Geolocator.openAppSettings,
                        child: const Text('Cài đặt'),
                      ),
                      TextButton(
                        onPressed: findMe,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      Text(
                        me == null
                            ? 'Các bến xe trên tuyến Bắc – Nam'
                            : 'Sắp xếp theo khoảng cách từ vị trí của bạn',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      for (final (i, s) in list.indexed)
                        Card(
                          child: ListTile(
                            onTap: () => moveMap(map, point(s), zoom: 13),
                            leading: CircleAvatar(
                              backgroundColor: me != null && i == 0
                                  ? const Color(0xFFFFEEDF)
                                  : const Color(0xFFE2F1E8),
                              child: Icon(
                                Icons.directions_bus,
                                color: me != null && i == 0 ? orange : forest,
                              ),
                            ),
                            title: Text(
                              s['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              me == null
                                  ? s['province']
                                  : '${s['province']} • cách ${kmLabel(kmBetween(me!, point(s)))}${i == 0 ? ' • Gần nhất' : ''}',
                            ),
                            trailing: IconButton(
                              tooltip: 'Chỉ đường',
                              icon: const Icon(Icons.directions, color: forest),
                              onPressed: () =>
                                  openDirections(context, s['lat'], s['lng']),
                            ),
                          ),
                        ),
                      gap(8),
                      const Text(
                        'Tọa độ bến xe là dữ liệu mẫu gần đúng cho đề tài.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class TrackTrip extends StatefulWidget {
  final Session session;
  final String tripId;
  const TrackTrip({super.key, required this.session, required this.tripId});
  @override
  State<TrackTrip> createState() => _TrackTripState();
}

class _TrackTripState extends State<TrackTrip> {
  final map = MapController();
  Json? data;
  String? error;
  LatLng? me;
  StreamSubscription<Position>? myStream;
  Timer? poll;
  bool follow = true;
  @override
  void initState() {
    super.initState();
    load();
    poll = Timer.periodic(const Duration(seconds: 10), (_) => load());
  }

  @override
  void dispose() {
    poll?.cancel();
    myStream?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final value = Json.from(
        await widget.session.api.call('/trips/${widget.tripId}/track'),
      );
      if (!mounted) return;
      final shown = data != null;
      setState(() {
        data = value;
        error = null;
      });
      if (shown && follow && value['status'] == 'running') {
        moveMap(map, bus(value), minZoom: 9);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  LatLng bus(Json d) => LatLng(d['position']['lat'], d['position']['lng']);

  Future<void> toggleMe() async {
    if (myStream != null) {
      await myStream!.cancel();
      setState(() {
        myStream = null;
        me = null;
      });
      return;
    }
    try {
      final first = await locate();
      if (!mounted) return;
      setState(() => me = LatLng(first.latitude, first.longitude));
      myStream =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 20,
            ),
          ).listen((p) {
            if (mounted) setState(() => me = LatLng(p.latitude, p.longitude));
          });
      setState(() {});
    } catch (e) {
      if (mounted) toast(context, e);
    }
  }

  Widget statusCard(Json d, List<Json> stops) {
    final pos = d['position'];
    final total = d['total_km'] as int;
    final km = (pos['km'] as num).toDouble();
    final next = stops.where((s) => s['passed'] != true).firstOrNull;
    final booking = d['booking'] as Map?;
    final pickup = booking == null
        ? null
        : stops.where((s) => s['name'] == booking['pickup']).firstOrNull;
    final delay = (d['delay'] as int) ~/ 60;
    final (title, color) = switch (d['status']) {
      'not_started' => ('Xe chưa khởi hành', Colors.black54),
      'arrived' => ('Xe đã đến bến cuối', forest),
      _ => ('Xe đang di chuyển', orange),
    };
    return panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.directions_bus_filled, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: d['source'] == 'gps'
                      ? const Color(0xFFE2F1E8)
                      : const Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  d['source'] == 'gps' ? 'GPS trực tiếp' : 'Ước tính theo lịch',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          gap(12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : km / total,
              minHeight: 8,
              color: forest,
              backgroundColor: const Color(0xFFE2F1E8),
            ),
          ),
          gap(6),
          Text(
            'Đã đi ${km.round()} / $total km'
            '${pos['speed'] != null ? ' • ${((pos['speed'] as num) * 3.6).round()} km/h' : ''}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          if (next != null && d['status'] != 'arrived')
            pair(
              'Điểm kế tiếp',
              '${next['name']} • ${clock(next['predicted'])}',
            ),
          if (pickup != null)
            pair(
              'Điểm đón của bạn',
              pickup['passed'] == true
                  ? '${pickup['name']} • xe đã qua'
                  : '${pickup['name']} • dự kiến ${clock(pickup['predicted'])}',
            ),
          if (d['source'] == 'gps' && delay.abs() >= 5)
            pair(
              'So với lịch',
              delay > 0 ? 'Trễ $delay phút' : 'Sớm ${-delay} phút',
            ),
          if (me != null && pickup != null)
            pair(
              'Bạn cách điểm đón',
              kmLabel(kmBetween(me!, LatLng(pickup['lat'], pickup['lng']))),
            ),
          if (pos['updated'] != null)
            Text(
              'Cập nhật GPS lúc ${clock(pos['updated'])}',
              style: const TextStyle(fontSize: 12, color: Colors.black45),
            ),
          if (d['source'] != 'gps')
            const Text(
              'Chưa nhận GPS từ xe trong 10 phút qua, vị trí được ước tính theo lịch chạy.',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final stops = d == null
        ? <Json>[]
        : (d['stops'] as List).map((e) => Json.from(e)).toList();
    final booking = d?['booking'] as Map?;
    final route = stops.map((s) => LatLng(s['lat'], s['lng'])).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          d == null
              ? 'Theo dõi chuyến xe'
              : '${d['trip']['origin']} → ${d['trip']['destination']}',
        ),
        actions: [
          IconButton(
            tooltip: myStream == null
                ? 'Hiện vị trí của tôi'
                : 'Tắt vị trí của tôi',
            onPressed: toggleMe,
            icon: Icon(
              myStream == null ? Icons.location_searching : Icons.my_location,
            ),
          ),
        ],
      ),
      body: d == null
          ? (error != null
                ? errorPanel(error!, load)
                : const Center(child: CircularProgressIndicator()))
          : Column(
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.42,
                  child: Stack(
                    children: [
                      BusMap(
                        controller: map,
                        fit: route,
                        layers: [
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: route,
                                color: forest,
                                strokeWidth: 5,
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              for (final s in stops)
                                Marker(
                                  point: LatLng(s['lat'], s['lng']),
                                  width: 18,
                                  height: 18,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: s['passed'] == true
                                          ? forest
                                          : Colors.white,
                                      border: Border.all(
                                        color: s['name'] == booking?['pickup']
                                            ? orange
                                            : forest,
                                        width: s['name'] == booking?['pickup']
                                            ? 4
                                            : 3,
                                      ),
                                    ),
                                  ),
                                ),
                              if (me != null)
                                Marker(
                                  point: me!,
                                  width: 22,
                                  height: 22,
                                  child: myLocationDot(),
                                ),
                              Marker(
                                point: bus(d),
                                width: 42,
                                height: 42,
                                child: pin(
                                  Icons.directions_bus,
                                  orange,
                                  size: 42,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        right: 12,
                        bottom: 28,
                        child: FloatingActionButton.small(
                          heroTag: 'follow',
                          tooltip: 'Về vị trí xe',
                          onPressed: () {
                            setState(() => follow = true);
                            moveMap(map, bus(d), minZoom: 9);
                          },
                          child: const Icon(Icons.directions_bus),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (error != null)
                          Text(
                            error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        statusCard(d, stops),
                        section('Lộ trình'),
                        for (final (i, s) in stops.indexed)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 54,
                                child: Text(
                                  DateFormat('HH:mm').format(
                                    DateTime.fromMillisecondsSinceEpoch(
                                      (s['predicted'] as int) * 1000,
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: s['passed'] == true
                                        ? Colors.black38
                                        : forest,
                                  ),
                                ),
                              ),
                              Column(
                                children: [
                                  Icon(
                                    s['passed'] == true
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    size: 18,
                                    color: s['passed'] == true
                                        ? forest
                                        : Colors.black38,
                                  ),
                                  if (i < stops.length - 1)
                                    Container(
                                      width: 2,
                                      height: 30,
                                      color: const Color(0xFFCBD9CE),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s['name'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: s['passed'] == true
                                            ? Colors.black45
                                            : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      [
                                        '${s['province']} • km ${s['km']}',
                                        if (s['name'] == booking?['pickup'])
                                          'Điểm đón',
                                        if (s['name'] == booking?['dropoff'])
                                          'Điểm trả',
                                      ].join(' • '),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Nhân viên trên xe bật màn này để gửi GPS điện thoại làm vị trí của xe.
class ShareBusLocation extends StatefulWidget {
  final Session session;
  final Json trip;
  const ShareBusLocation({
    super.key,
    required this.session,
    required this.trip,
  });
  @override
  State<ShareBusLocation> createState() => _ShareBusLocationState();
}

class _ShareBusLocationState extends State<ShareBusLocation> {
  final map = MapController();
  StreamSubscription<Position>? stream;
  Timer? heartbeat;
  Position? last;
  int sent = 0;
  int? sentAt;
  String? error;

  @override
  void dispose() {
    stream?.cancel();
    heartbeat?.cancel();
    super.dispose();
  }

  Future<void> send(Position p) async {
    try {
      final r = await widget.session.api.call(
        '/staff/trips/${widget.trip['id']}/position',
        method: 'POST',
        data: {'lat': p.latitude, 'lng': p.longitude, 'speed': p.speed},
      );
      if (mounted) {
        setState(() {
          sent++;
          sentAt = r['updated'];
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> start() async {
    try {
      final first = await locate();
      if (!mounted) return;
      setState(() => last = first);
      moveMap(map, LatLng(first.latitude, first.longitude), zoom: 15);
      await send(first);
      stream =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 50,
            ),
          ).listen((p) {
            if (!mounted) return;
            setState(() => last = p);
            moveMap(map, LatLng(p.latitude, p.longitude));
            send(p);
          });
      // Xe đứng yên vẫn gửi lại để khách biết GPS còn hoạt động.
      heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
        if (last != null) send(last!);
      });
      setState(() {});
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> stop() async {
    await stream?.cancel();
    heartbeat?.cancel();
    setState(() {
      stream = null;
      heartbeat = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final here = last == null ? null : LatLng(last!.latitude, last!.longitude);
    return Scaffold(
      appBar: AppBar(title: const Text('Chia sẻ vị trí xe')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${t['origin']} → ${t['destination']}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: forest,
            ),
          ),
          Text('${dateLabel(t['date'])} • ${t['time']} • ${t['plate']}'),
          gap(),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 260,
              child: BusMap(
                controller: map,
                fit: here == null ? [] : [here],
                layers: [
                  if (here != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: here,
                          width: 42,
                          height: 42,
                          child: pin(Icons.directions_bus, orange, size: 42),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          gap(),
          panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      stream == null ? Icons.gps_off : Icons.gps_fixed,
                      color: stream == null ? Colors.black45 : forest,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        stream == null
                            ? 'Chưa chia sẻ vị trí'
                            : 'Đang chia sẻ vị trí cho hành khách',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                pair('Số lần gửi', '$sent'),
                if (sentAt != null) pair('Gửi gần nhất', clock(sentAt!)),
                if (last != null)
                  pair('Tốc độ', '${(last!.speed * 3.6).round()} km/h'),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                gap(),
                stream == null
                    ? FilledButton.icon(
                        onPressed: start,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Bắt đầu chia sẻ'),
                      )
                    : OutlinedButton.icon(
                        onPressed: stop,
                        icon: const Icon(Icons.stop),
                        label: const Text('Dừng chia sẻ'),
                      ),
                gap(8),
                const Text(
                  'Giữ màn hình này mở trong suốt chuyến. Khi app bị tắt hoặc mất mạng quá 10 phút, khách sẽ thấy vị trí ước tính theo lịch.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
