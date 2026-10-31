import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../ui.dart';

/// Tiện ích trên xe: mã do máy chủ trả về → biểu tượng và tên hiển thị.
const amenities = <String, (IconData, String)>{
  'wifi': (Icons.wifi, 'Wi-Fi miễn phí'),
  'usb': (Icons.usb, 'Cổng sạc USB'),
  'ac': (Icons.ac_unit, 'Điều hòa'),
  'water': (Icons.local_drink_outlined, 'Nước suối'),
  'blanket': (Icons.bed_outlined, 'Chăn gối'),
  'curtain': (Icons.curtains_outlined, 'Rèm riêng tư'),
  'tv': (Icons.tv, 'Màn hình giải trí'),
  'towel': (Icons.dry_outlined, 'Khăn lạnh'),
  'massage': (Icons.spa_outlined, 'Ghế massage'),
  'legroom': (Icons.airline_seat_legroom_extra, 'Chỗ để chân rộng'),
  'toilet': (Icons.wc, 'Nhà vệ sinh'),
};

/// Ảnh minh họa thật (Wikimedia Commons), ghi nguồn theo giấy phép CC BY-SA.
typedef BusPhoto = ({String asset, String caption, String credit, String page});
const _commons = 'https://commons.wikimedia.org/wiki/File:';
const busPhotos = <String, List<BusPhoto>>{
  'sleeper36': [
    (
      asset: 'assets/images/buses/sleeper36_ext.jpg',
      caption: 'Ngoại thất xe giường nằm',
      credit: 'calflier001 • CC BY-SA 2.0',
      page:
          '${_commons}HYUNDAI_AERODECK_SLEEPER_BUS_NEAR_DA_LAT_VIETNAM_JAN_2012_(6821943988).jpg',
    ),
    (
      asset: 'assets/images/buses/sleeper36_int.jpg',
      caption: 'Khoang giường nằm hai tầng',
      credit: 'Ilya Plekhanov • CC BY-SA 4.0',
      page: '${_commons}Thaco_Mobihome_sleeper_bus_interior.jpg',
    ),
  ],
  'limo30': [
    (
      asset: 'assets/images/buses/limo30_ext.jpg',
      caption: 'Ngoại thất xe cao cấp',
      credit: 'calflier001 • CC BY-SA 2.0',
      page:
          '${_commons}HYUNDAI_AERO_EXPRESS_HI_CLASS_COACH_MUNE_VIETNAM_JAN_2012_(6864376894).jpg',
    ),
    (
      asset: 'assets/images/buses/limo30_int.jpg',
      caption: 'Ghế da cao cấp',
      credit: 'Nanzig • CC BY-SA 4.0',
      page: '${_commons}Int._Temsa_Opalin.jpg',
    ),
  ],
  'seat45': [
    (
      asset: 'assets/images/buses/seat45_ext.jpg',
      caption: 'Ngoại thất xe ghế ngồi',
      credit: 'Ilya p • CC BY-SA 4.0',
      page: '${_commons}Thaco_Hyundai_115L_bus_in_Vietnam.JPG',
    ),
    (
      asset: 'assets/images/buses/seat45_int.jpg',
      caption: 'Dãy ghế ngồi 2–2',
      credit: 'Ilya p • CC BY-SA 4.0',
      page: '${_commons}Thaco_Hyundai_115L_bus_in_Vietnam_-_interior.jpg',
    ),
  ],
};

/// Ảnh vuốt ngang có chấm trang, chú thích và nguồn; chạm để xem toàn màn hình.
class BusGallery extends StatefulWidget {
  final String type;
  final double height;
  const BusGallery({super.key, required this.type, this.height = 220});
  @override
  State<BusGallery> createState() => _BusGalleryState();
}

class _BusGalleryState extends State<BusGallery> {
  int page = 0;
  @override
  Widget build(BuildContext context) {
    final photos = busPhotos[widget.type] ?? [];
    if (photos.isEmpty) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          gradient: brandGradient,
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(painter: JourneyPainter(style: widget.type)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: widget.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView(
                  onPageChanged: (v) => setState(() => page = v),
                  children: [
                    for (final (i, p) in photos.indexed)
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PhotoViewer(photos: photos, initial: i),
                          ),
                        ),
                        child: Image.asset(
                          p.asset,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            decoration: const BoxDecoration(
                              gradient: brandGradient,
                            ),
                            child: CustomPaint(
                              painter: JourneyPainter(style: widget.type),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                // Lớp tối phía dưới để chữ dễ đọc.
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 70,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black54],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  bottom: 12,
                  right: 70,
                  child: IgnorePointer(
                    child: Text(
                      photos[page].caption,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 16,
                  child: Row(
                    children: [
                      for (var i = 0; i < photos.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(left: 5),
                          width: i == page ? 18 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == page ? Colors.white : Colors.white54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Ảnh minh họa',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        gap(4),
        Text(
          'Ảnh: ${photos[page].credit} • Wikimedia Commons',
          textAlign: TextAlign.end,
          style: const TextStyle(fontSize: 10.5, color: Colors.black45),
        ),
      ],
    );
  }
}

/// Xem ảnh toàn màn hình, phóng to bằng hai ngón tay.
class PhotoViewer extends StatefulWidget {
  final List<BusPhoto> photos;
  final int initial;
  const PhotoViewer({super.key, required this.photos, this.initial = 0});
  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late int page = widget.initial;
  late final controller = PageController(initialPage: widget.initial);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.photos[page];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          p.caption,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: 'Trang nguồn ảnh',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => launchUrl(
              Uri.parse(p.page),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: controller,
              onPageChanged: (v) => setState(() => page = v),
              children: [
                for (final photo in widget.photos)
                  InteractiveViewer(
                    maxScale: 4,
                    child: Center(child: Image.asset(photo.asset)),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Ảnh minh họa: ${p.credit} • Wikimedia Commons',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData seatIcon(String? kind) => switch (kind) {
  'recline' => Icons.airline_seat_recline_extra,
  'seat' => Icons.event_seat,
  _ => Icons.airline_seat_flat,
};

IconData busIcon(String? type) => switch (type) {
  'limo30' => Icons.airport_shuttle,
  'seat45' => Icons.directions_bus,
  _ => Icons.bed,
};

/// Danh mục loại xe chỉ tải một lần cho mỗi phiên.
final _cache = <Session, Future<List<Json>>>{};
Future<List<Json>> busTypes(Session session) =>
    _cache.putIfAbsent(
      session,
      () => session.api
          .call('/bus-types')
          .then(
            (v) => [
              for (final e in v as List)
                if (e is Map &&
                    e['id'] is String &&
                    e['short'] is String &&
                    e['layout'] is List)
                  Json.from(e),
            ],
          ),
    )..catchError((_) {
      _cache.remove(session);
      return <Json>[];
    });

Widget amenityChip(String key, {bool compact = false}) {
  final (icon, label) = amenities[key] ?? (Icons.check, key);
  if (compact) {
    return Tooltip(
      message: label,
      child: Icon(icon, size: 16, color: Colors.black45),
    );
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F6F2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: forest),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

/// Dải "Đội xe" trên trang chủ.
class FleetStrip extends StatelessWidget {
  final Session session;

  /// Gọi với mã loại xe khi khách bấm "Tìm chuyến" trong trang giới thiệu.
  final ValueChanged<String>? onPick;
  const FleetStrip({super.key, required this.session, this.onPick});
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Json>>(
    future: busTypes(session),
    builder: (context, s) {
      final list = s.data ?? [];
      if (list.isEmpty) return const SizedBox.shrink();
      return SizedBox(
        height: 192,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            final b = list[i];
            return SizedBox(
              width: 250,
              child: Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () async {
                    final picked = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BusInfoScreen(
                          session: session,
                          bus: b,
                          pickable: onPick != null,
                        ),
                      ),
                    );
                    if (picked != null) onPick?.call(picked);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 100,
                        child: busPhotos[b['id']] == null
                            ? DecoratedBox(
                                decoration: const BoxDecoration(
                                  gradient: brandGradient,
                                ),
                                child: CustomPaint(
                                  painter: JourneyPainter(style: b['id']),
                                ),
                              )
                            : Image.asset(
                                busPhotos[b['id']]!.first.asset,
                                fit: BoxFit.cover,
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            gap(2),
                            Text(
                              b['suitable'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            gap(8),
                            Row(
                              children: [
                                for (final a in (b['amenities'] as List).take(
                                  6,
                                ))
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: amenityChip(a, compact: true),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

/// Trang giới thiệu một loại xe: hình minh họa, tiện ích, sơ đồ ghế thu nhỏ.
class BusInfoScreen extends StatelessWidget {
  final Session session;
  final Json bus;

  /// Khi có, hiện nút "Tìm chuyến loại xe này" và trả về mã loại xe.
  final bool pickable;
  const BusInfoScreen({
    super.key,
    required this.session,
    required this.bus,
    this.pickable = false,
  });

  Widget seatPreview() {
    final layout = (bus['layout'] as List).map((d) => Json.from(d)).toList();
    final icon = seatIcon(bus['seat_icon']);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, deck) in layout.indexed) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: line, width: 2),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                  bottom: Radius.circular(14),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    deck['name'],
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: forest,
                      letterSpacing: 1,
                    ),
                  ),
                  gap(8),
                  for (final row in deck['rows'] as List)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (final seat in row as List)
                            seat == null
                                ? const SizedBox(width: 14)
                                : Icon(
                                    icon,
                                    size: 18,
                                    color: const Color(0xFF7BA595),
                                  ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(bus['name'])),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        BusGallery(type: bus['id']),
        gap(16),
        Row(
          children: [
            for (final (icon, value, label) in [
              (Icons.event_seat_outlined, '${bus['capacity']}', 'chỗ'),
              (busIcon(bus['id']), '${(bus['layout'] as List).length}', 'tầng'),
              (
                Icons.sell_outlined,
                bus['price_factor'] == 1
                    ? 'Chuẩn'
                    : (bus['price_factor'] as num) < 1
                    ? 'Tiết kiệm'
                    : 'Cao cấp',
                'mức giá',
              ),
            ])
              Expanded(
                child: Column(
                  children: [
                    Icon(icon, color: orange),
                    gap(4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: forest,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        section('Giới thiệu'),
        Text(bus['description'], style: const TextStyle(height: 1.55)),
        gap(10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1E6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.thumb_up_alt_outlined,
                color: orangeDeep,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Phù hợp: ${bus['suitable']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        section('Tiện ích trên xe'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final a in bus['amenities'] as List) amenityChip(a)],
        ),
        section('Sơ đồ chỗ ngồi'),
        seatPreview(),
        gap(20),
        if (pickable)
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: orange),
            onPressed: () => Navigator.pop(context, bus['id']),
            icon: const Icon(Icons.search),
            label: Text('Tìm chuyến ${bus['short']}'),
          ),
      ],
    ),
  );
}
