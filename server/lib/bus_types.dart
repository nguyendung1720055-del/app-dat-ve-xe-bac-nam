/// Danh mục loại xe: sơ đồ ghế, tiện ích và hệ số giá so với giường nằm.
/// Sơ đồ là danh sách tầng; mỗi hàng là danh sách mã ghế, `null` là lối đi.
class BusType {
  final String id, name, short, description, suitable, seatIcon;
  final double priceFactor;
  final List<String> amenities;
  final List<({String name, List<List<String?>> rows})> decks;
  const BusType({
    required this.id,
    required this.name,
    required this.short,
    required this.description,
    required this.suitable,
    required this.seatIcon,
    required this.priceFactor,
    required this.amenities,
    required this.decks,
  });

  List<String> get seats => [
    for (final d in decks)
      for (final r in d.rows)
        for (final s in r)
          if (s != null) s,
  ];

  int get capacity => seats.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'short': short,
    'description': description,
    'suitable': suitable,
    'seat_icon': seatIcon,
    'price_factor': priceFactor,
    'capacity': capacity,
    'amenities': amenities,
    'layout': [
      for (final d in decks) {'name': d.name, 'rows': d.rows},
    ],
  };
}

String _code(String prefix, int n) => '$prefix${n.toString().padLeft(2, '0')}';

final busTypes = <String, BusType>{
  'sleeper36': BusType(
    id: 'sleeper36',
    name: 'Giường nằm 36 chỗ',
    short: 'Giường nằm',
    description:
        'Xe hai tầng, 3 dãy giường đơn có rèm che. Phù hợp hành trình đêm dài: nằm thẳng lưng, ngủ thoải mái suốt chặng.',
    suitable: 'Đi đêm, chặng dài trên 10 giờ',
    seatIcon: 'bed',
    priceFactor: 1.0,
    amenities: ['wifi', 'usb', 'ac', 'water', 'blanket', 'curtain', 'tv'],
    decks: [
      for (final f in ['A', 'B'])
        (
          name: f == 'A' ? 'TẦNG DƯỚI' : 'TẦNG TRÊN',
          rows: [
            for (var r = 0; r < 6; r++)
              [for (var c = 0; c < 3; c++) _code(f, r * 3 + c + 1)],
          ],
        ),
    ],
  ),
  'limo30': BusType(
    id: 'limo30',
    name: 'Limousine VIP 30 chỗ',
    short: 'Limousine',
    description:
        'Ghế da ngả 145°, sắp xếp 1–2 rộng rãi, có massage và tựa chân. Không gian yên tĩnh, phục vụ khăn lạnh và nước suối.',
    suitable: 'Công tác, gia đình, đi ngày cần thoải mái',
    seatIcon: 'recline',
    priceFactor: 1.25,
    amenities: [
      'wifi',
      'usb',
      'ac',
      'water',
      'towel',
      'massage',
      'legroom',
      'toilet',
    ],
    decks: [
      (
        name: 'KHOANG KHÁCH',
        rows: [
          for (var r = 0; r < 10; r++)
            [
              _code('L', r * 3 + 1),
              null,
              _code('L', r * 3 + 2),
              _code('L', r * 3 + 3),
            ],
        ],
      ),
    ],
  ),
  'seat45': BusType(
    id: 'seat45',
    name: 'Ghế ngồi 45 chỗ',
    short: 'Ghế ngồi',
    description:
        'Xe ghế ngồi tiêu chuẩn 2–2, ghế ngả nhẹ, giá tiết kiệm. Thích hợp chặng ngắn hoặc đi ban ngày, đoàn đông người.',
    suitable: 'Tiết kiệm, chặng ngắn, đi theo đoàn',
    seatIcon: 'seat',
    priceFactor: 0.7,
    amenities: ['ac', 'water', 'usb'],
    decks: [
      (
        name: 'KHOANG KHÁCH',
        rows: [
          for (var r = 0; r < 10; r++)
            [
              _code('S', r * 4 + 1),
              _code('S', r * 4 + 2),
              null,
              _code('S', r * 4 + 3),
              _code('S', r * 4 + 4),
            ],
          [for (var i = 41; i <= 45; i++) _code('S', i)],
        ],
      ),
    ],
  ),
};

BusType busTypeOf(Map<String, dynamic> trip) =>
    busTypes[trip['bus_type']] ?? busTypes['sleeper36']!;
