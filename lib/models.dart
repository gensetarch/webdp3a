class Item {
  String id;
  String jenisBarang;
  String merekModel;
  String kodeBarang;
  String noRegister;
  String kondisiAset; // 'Baik', 'Kurang Baik', 'Rusak'
  String fotoUrl;
  String barcode;
  String tahunPerolehan;

  Item({
    required this.id,
    required this.jenisBarang,
    required this.merekModel,
    required this.kodeBarang,
    required this.noRegister,
    required this.kondisiAset,
    required this.fotoUrl,
    required this.barcode,
    this.tahunPerolehan = '',
  });

  // Convert an Item to a Map for JSON storage/mock state
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jenisBarang': jenisBarang,
      'merekModel': merekModel,
      'kodeBarang': kodeBarang,
      'noRegister': noRegister,
      'kondisiAset': kondisiAset,
      'fotoUrl': fotoUrl,
      'barcode': barcode,
      'tahunPerolehan': tahunPerolehan,
    };
  }

  // Create an Item from a Map
  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'] ?? '',
      jenisBarang: map['jenisBarang'] ?? map['jenis_barang'] ?? '',
      merekModel: map['merekModel'] ?? map['merek_model'] ?? '',
      kodeBarang: map['kodeBarang'] ?? map['kode_barang'] ?? '',
      noRegister: map['noRegister'] ?? map['no_register'] ?? map['namaPengguna'] ?? '',
      kondisiAset: map['kondisiAset'] ?? map['kondisi_aset'] ?? 'Baik',
      fotoUrl: map['fotoUrl'] ?? map['foto_url'] ?? '',
      barcode: map['barcode'] ?? '',
      tahunPerolehan: map['tahunPerolehan'] ?? map['tahun_perolehan'] ?? '',
    );
  }

  Item copyWith({
    String? id,
    String? jenisBarang,
    String? merekModel,
    String? kodeBarang,
    String? noRegister,
    String? kondisiAset,
    String? fotoUrl,
    String? barcode,
    String? tahunPerolehan,
  }) {
    return Item(
      id: id ?? this.id,
      jenisBarang: jenisBarang ?? this.jenisBarang,
      merekModel: merekModel ?? this.merekModel,
      kodeBarang: kodeBarang ?? this.kodeBarang,
      noRegister: noRegister ?? this.noRegister,
      kondisiAset: kondisiAset ?? this.kondisiAset,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      barcode: barcode ?? this.barcode,
      tahunPerolehan: tahunPerolehan ?? this.tahunPerolehan,
    );
  }
}

class Room {
  String id;
  String name;
  String year;
  String barcode;
  List<Item> items;

  Room({
    required this.id,
    required this.name,
    required this.year,
    required this.barcode,
    required this.items,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'year': year,
      'barcode': barcode,
      'items': items.map((x) => x.toMap()).toList(),
    };
  }

  factory Room.fromMap(Map<String, dynamic> map) {
    return Room(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      year: map['year'] ?? '',
      barcode: map['barcode'] ?? '',
      items: List<Item>.from((map['items'] as List<dynamic>?)?.map((x) => Item.fromMap(x as Map<String, dynamic>)) ?? const []),
    );
  }

  Room copyWith({
    String? id,
    String? name,
    String? year,
    String? barcode,
    List<Item>? items,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      year: year ?? this.year,
      barcode: barcode ?? this.barcode,
      items: items ?? this.items,
    );
  }
}

class Agency {
  String id;
  String name;
  String barcode;
  List<Room> rooms;

  Agency({
    required this.id,
    required this.name,
    required this.barcode,
    required this.rooms,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'rooms': rooms.map((x) => x.toMap()).toList(),
    };
  }

  factory Agency.fromMap(Map<String, dynamic> map) {
    return Agency(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      barcode: map['barcode'] ?? '',
      rooms: List<Room>.from(
        (map['rooms'] as List<dynamic>?)?.map((x) => Room.fromMap(x as Map<String, dynamic>)) ?? const [],
      ),
    );
  }

  Agency copyWith({
    String? id,
    String? name,
    String? barcode,
    List<Room>? rooms,
  }) {
    return Agency(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      rooms: rooms ?? this.rooms,
    );
  }
}
