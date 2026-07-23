import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'genset_card.dart';
import 'barcode_widget.dart';
import 'scan_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'printer_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage_helper.dart';


// URL GitHub Pages resmi untuk deploy
const String kPublicBaseUrl = 'https://gensetarch.github.io/webdp3a';

// Supabase Configuration - REPLACE WITH YOUR CREDENTIALS
const String kSupabaseUrl = 'https://rxjixxgisdshfnkfyzaj.supabase.co';
const String kSupabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ4aml4eGdpc2RzaGZua2Z5emFqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMzODE0MDMsImV4cCI6MjA5ODk1NzQwM30.po46YqhN0kYgIvB9KRsbJdynMLBGcmoY8tRxNpz7k1o';

bool get isSupabaseConfigured {
  return kSupabaseUrl != 'YOUR_SUPABASE_URL' &&
      kSupabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY' &&
      kSupabaseUrl.isNotEmpty &&
      kSupabaseAnonKey.isNotEmpty;
}

String generateRoomUrl(String roomId) {
  return '$kPublicBaseUrl/?room=$roomId';
}

String generateAgencyUrl(String agencyId) {
  return '$kPublicBaseUrl/?agency=$agencyId';
}

String generateItemUrl(String itemId) {
  return '$kPublicBaseUrl/?item=$itemId';
}

/// Generate UUID v4 acak (tidak perlu package tambahan)
String generateUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    if (isSupabaseConfigured) {
      await Supabase.initialize(
        url: kSupabaseUrl,
        anonKey: kSupabaseAnonKey,
      );
    }
  } catch (e) {
    debugPrint('Supabase Init Error: $e');
  }

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GENSET - Gerakan Sayang Aset',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC9E12C),
          primary: const Color(0xFF111111),
          secondary: const Color(0xFFC9E12C),
          surface: Colors.white,
          background: const Color(0xFFF9F9FB),
        ),
      ),
      home: const MainAppController(),
    );
  }
}

class MainAppController extends StatefulWidget {
  const MainAppController({Key? key}) : super(key: key);

  @override
  State<MainAppController> createState() => _MainAppControllerState();
}

class _MainAppControllerState extends State<MainAppController> {
  bool _isLoading = false;
  bool _isAdminLoggedIn = false;
  String? _publicAgencyId;
  String? _publicRoomId;
  String? _publicItemId;
  String? _selectedItemId;
  List<Item>? _selectedGroupItems;


  // Simulated database of rooms & items
  List<Room> _rooms = [];
  List<Agency> _agencies = [];

  void setPublicAgencyId(String? agencyId) {
    setState(() {
      _publicAgencyId = agencyId;
    });
    if (agencyId != null) {
      saveToSession('public_agency_id', agencyId);
    } else {
      removeFromSession('public_agency_id');
    }
  }

  void setPublicRoomId(String? roomId) {
    setState(() {
      _publicRoomId = roomId;
    });
    // Gunakan sessionStorage agar direset saat tab ditutup / link dibuka ulang
    if (roomId != null) {
      saveToSession('public_room_id', roomId);
    } else {
      removeFromSession('public_room_id');
    }
  }

  void setPublicItemId(String? itemId) {
    setState(() {
      _publicItemId = itemId;
    });
    // Gunakan sessionStorage agar direset saat tab ditutup / link dibuka ulang
    if (itemId != null) {
      saveToSession('public_item_id', itemId);
    } else {
      removeFromSession('public_item_id');
    }
  }

  @override
  void initState() {
    super.initState();
    _initData();
    _checkUrlRouting();
  }

  Future<void> _initData() async {
    final bool isReload = isPageReload();

    // Jika BUKAN reload (misal user klik link webnya / baru buka URL),
    // hapus status session login admin agar selalu kembali ke Halaman Login.
    if (!isReload) {
      removeFromStorage('admin_logged_in');
      removeFromStorage('admin_current_room_id');
      removeFromSession('admin_logged_in');
      removeFromSession('admin_current_room_id');
    }

    final loggedIn = isReload && (
      getFromSession('admin_logged_in') == 'true' ||
      getFromStorage('admin_logged_in') == 'true'
    );

    setState(() {
      _isAdminLoggedIn = loggedIn;
    });

    if (isSupabaseConfigured) {
      await _fetchDataFromSupabase();
    } else {
      _loadSampleData();
    }

    // Baca dari sessionStorage (hanya berlaku selama tab ini terbuka)
    final savedPublicAgencyId = getFromSession('public_agency_id');
    final savedPublicRoomId = getFromSession('public_room_id');
    final savedPublicItemId = getFromSession('public_item_id');
    if (_publicAgencyId == null && savedPublicAgencyId != null) {
      setState(() {
        _publicAgencyId = savedPublicAgencyId;
      });
    }
    if (_publicRoomId == null && savedPublicRoomId != null) {
      setState(() {
        _publicRoomId = savedPublicRoomId;
      });
    }
    if (_publicItemId == null && savedPublicItemId != null) {
      setState(() {
        _publicItemId = savedPublicItemId;
      });
    }

    if (loggedIn && isReload) {
      final savedRoomId = getFromSession('admin_current_room_id') ?? getFromStorage('admin_current_room_id');
      if (savedRoomId != null) {
        final roomList = _rooms.where((r) => r.id == savedRoomId).toList();
        if (roomList.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RoomDetailsScreen(
                    room: roomList.first,
                    allRooms: _rooms,
                    onRoomsChanged: (updatedRooms) {
                      setState(() {
                        _rooms = updatedRooms;
                      });
                    },
                  ),
                ),
              ).then((_) {
                removeFromStorage('admin_current_room_id');
                removeFromSession('admin_current_room_id');
              });
            }
          });
        }
      }
    }
  }

  Future<void> _fetchDataFromSupabase() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final client = Supabase.instance.client;

      // Fetch rooms
      final roomsResponse = await client.from('rooms').select().order('name');
      
      // Fetch items
      final itemsResponse = await client.from('items').select();

      final List<Room> loadedRooms = [];
      for (var roomData in roomsResponse) {
        final roomId = roomData['id'] as String;
        final roomItemsData = (itemsResponse as List)
            .where((item) => item['room_id'] == roomId)
            .toList();
        
        final roomItems = roomItemsData.map((itemData) {
          final itemId = itemData['id'] ?? '';
          final kodeBarang = itemData['kode_barang'] ?? '';
          final rawBarcode = itemData['barcode'] ?? '';
          // Normalisasi: jika barcode lama = kode_barang (data lama),
          // pakai item id sebagai barcode agar scan selalu unik
          final effectiveBarcode = (rawBarcode.isEmpty || rawBarcode == kodeBarang)
              ? itemId
              : rawBarcode;
          return Item(
            id: itemId,
            jenisBarang: itemData['jenis_barang'] ?? '',
            merekModel: itemData['merek_model'] ?? '',
            kodeBarang: kodeBarang,
            noRegister: itemData['no_register'] ?? itemData['noRegister'] ?? '',
            kondisiAset: itemData['kondisi_aset'] ?? itemData['kondisiAset'] ?? 'Baik',
            fotoUrl: itemData['foto_url'] ?? '',
            barcode: effectiveBarcode,
            tahunPerolehan: itemData['tahun_perolehan'] ?? '',
          );
        }).toList()
          ..sort((a, b) => b.id.compareTo(a.id));

        loadedRooms.add(Room(
          id: roomId,
          name: roomData['name'] ?? '',
          year: roomData['year'] ?? '',
          barcode: roomData['barcode'] ?? '',
          items: roomItems,
        ));
      }

      setState(() {
        _rooms = loadedRooms;
        // Group all rooms under a default agency if no agencies table exists yet
        _agencies = [
          Agency(
            id: 'agency-default',
            name: 'DP3A',
            barcode: 'INS-DP3A',
            rooms: loadedRooms,
          ),
        ];
      });
    } catch (e) {
      debugPrint('Error fetching data from Supabase: $e');
      _loadSampleData();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  void _checkUrlRouting() {
    final queryParams = Uri.base.queryParameters;
    if (queryParams.containsKey('agency')) {
      final aId = queryParams['agency'];
      setPublicAgencyId(aId);
      setPublicRoomId(null);
      setPublicItemId(null);
    } else if (queryParams.containsKey('room')) {
      final rId = queryParams['room'];
      setPublicRoomId(rId);
      setPublicItemId(null);
      setPublicAgencyId(null);
    } else if (queryParams.containsKey('item')) {
      final rawId = queryParams['item'];
      // Cari item berdasarkan id — jika tidak ketemu, coba cari lewat barcode
      // lalu gunakan item.id agar routing selalu by ID unik
      String? resolvedId;
      for (var r in _rooms) {
        for (var i in r.items) {
          if (i.id == rawId || i.barcode == rawId) {
            resolvedId = i.id;
            break;
          }
        }
        if (resolvedId != null) break;
      }
      setPublicItemId(resolvedId ?? rawId);
      setPublicRoomId(null);
      setPublicAgencyId(null);
    }
  }

  void _handleScannedData(String scannedText) {
    // Coba parsing jika input berupa URL
    final uri = Uri.tryParse(scannedText);
    if (uri != null && uri.host.isNotEmpty) {
      final queryParams = uri.queryParameters;
      if (queryParams.containsKey('agency')) {
        setPublicAgencyId(queryParams['agency']);
        setPublicRoomId(null);
        setPublicItemId(null);
        return;
      } else if (queryParams.containsKey('room')) {
        setPublicRoomId(queryParams['room']);
        setPublicItemId(null);
        setPublicAgencyId(null);
        return;
      } else if (queryParams.containsKey('item')) {
        setPublicItemId(queryParams['item']);
        setPublicRoomId(null);
        setPublicAgencyId(null);
        return;
      }
    }

    final cleanedText = scannedText.trim();

    // 1. Cari item berdasarkan ID unik atau barcode
    bool hasItemMatch = false;
    String? matchedItemId;
    for (var r in _rooms) {
      for (var i in r.items) {
        if (i.id.trim() == cleanedText ||
            i.barcode.trim() == cleanedText) {
          hasItemMatch = true;
          matchedItemId = i.id;
          break;
        }
      }
      if (hasItemMatch) break;
    }

    if (hasItemMatch && matchedItemId != null) {
      setPublicItemId(matchedItemId);
      setPublicRoomId(null);
      setPublicAgencyId(null);
      setState(() {
        _selectedItemId = null;
      });
      return;
    }

    // 2. Cari ruangan berdasarkan barcode atau ID
    for (var r in _rooms) {
      if (r.barcode.trim().toUpperCase() == cleanedText.toUpperCase() ||
          r.id.trim() == cleanedText) {
        setPublicRoomId(r.id);
        setPublicItemId(null);
        setPublicAgencyId(null);
        return;
      }
    }

    // 3. Cari instansi berdasarkan barcode atau ID
    for (var a in _agencies) {
      if (a.barcode.trim().toUpperCase() == cleanedText.toUpperCase() ||
          a.id.trim() == cleanedText) {
        setPublicAgencyId(a.id);
        setPublicRoomId(null);
        setPublicItemId(null);
        return;
      }
    }

    // Not found dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aset / Ruangan Tidak Ditemukan'),
        content: Text('Kode "$cleanedText" tidak terdaftar dalam sistem GENSET.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _loadSampleData() {
    _rooms = [
      Room(
        id: 'room-1',
        name: 'Ruang Umum',
        year: '2024',
        barcode: 'RM-UMUM-2024',
        items: [
          Item(
            id: 'item-1',
            jenisBarang: 'Serial Printer',
            merekModel: 'Epson L5290',
            kodeBarang: '1.3.2.10.02.01.009',
            noRegister: '0001',
            kondisiAset: 'Baik',
            fotoUrl:
                'https://images.unsplash.com/photo-1612815154858-60aa4c59eaa6?q=80&w=400&auto=format&fit=crop',
            barcode: '1.3.2.10.02.01.009',
          ),
        ],
      ),
      Room(
        id: 'room-2',
        name: 'Ruang Kepala Dinas',
        year: '2024',
        barcode: 'RM-KADIN-2024',
        items: [
          Item(
            id: 'item-2',
            jenisBarang: 'Laptop Kerja',
            merekModel: 'MacBook Air M2',
            kodeBarang: '1.3.2.10.02.01.015',
            noRegister: '0002',
            kondisiAset: 'Kurang Baik',
            fotoUrl:
                'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?q=80&w=400&auto=format&fit=crop',
            barcode: '132100201015',
          ),
        ],
      ),
      Room(
        id: 'room-3',
        name: 'Ruang IT',
        year: '2024',
        barcode: 'RM-IT-2024',
        items: [
          Item(
            id: 'item-3',
            jenisBarang: 'PC All-in-One',
            merekModel: 'HP Pavilion 24',
            kodeBarang: '1.3.2.10.02.03.003',
            noRegister: '0003',
            kondisiAset: 'Baik',
            fotoUrl:
                'https://images.unsplash.com/photo-1547082299-de196ea013d6?q=80&w=400&auto=format&fit=crop',
            barcode: '1.3.2.10.02.03.003',
          ),
        ],
      ),
    ];
    _agencies = [
      Agency(
        id: 'agency-dp3a',
        name: 'DP3A',
        barcode: 'INS-DP3A',
        rooms: _rooms,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2A9D8F)),
          ),
        ),
      );
    }

    // 1. Check Public Item View Route — TAMPILKAN 1 BARANG SAJA YANG DI-SCAN
    if (_publicItemId != null) {
      Item? matchedItem;
      Room? matchedRoom;

      for (var r in _rooms) {
        for (var i in r.items) {
          if (i.id.trim() == _publicItemId!.trim() ||
              i.barcode.trim() == _publicItemId!.trim()) {
            matchedItem = i;
            matchedRoom = r;
            break;
          }
        }
        if (matchedItem != null) break;
      }

      if (matchedItem != null && matchedRoom != null) {
        return PublicItemScreen(
          item: matchedItem,
          room: matchedRoom,
          onBack: () {
            setPublicItemId(null);
            setState(() {
              _selectedItemId = null;
            });
          },
        );
      } else {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Barang Tidak Ditemukan',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    setPublicItemId(null);
                    setPublicRoomId(null);
                    setState(() {
                      _selectedItemId = null;
                    });
                  },
                  child: const Text('Ke Halaman Utama'),
                ),
              ],
            ),
          ),
        );
      }
    }

    // 2. Check Public Agency View Route
    if (_publicAgencyId != null) {
      if (_publicRoomId != null) {
        if (_selectedItemId != null) {
          Item? selectedItem;
          Room? selectedRoom;
          for (var r in _rooms) {
            for (var i in r.items) {
              if (i.id == _selectedItemId) {
                selectedItem = i;
                selectedRoom = r;
                break;
              }
            }
            if (selectedItem != null) break;
          }

          if (selectedItem != null && selectedRoom != null) {
            return PublicItemScreen(
              item: selectedItem,
              room: selectedRoom,
              onBack: () {
                setState(() {
                  _selectedItemId = null;
                });
              },
            );
          }
        }

        if (_selectedGroupItems != null && _selectedGroupItems!.isNotEmpty) {
          final parentRoom = _rooms.firstWhere(
            (r) => r.id == _publicRoomId,
            orElse: () => _rooms.first,
          );
          final List<MapEntry<Item, Room>> matchedGroupEntries =
              _selectedGroupItems!.map((item) => MapEntry(item, parentRoom)).toList();

          return PublicItemListScreen(
            scannedCode: '${_selectedGroupItems!.first.jenisBarang} (${_selectedGroupItems!.length} Unit)',
            matchedItems: matchedGroupEntries,
            onBack: () {
              setState(() {
                _selectedGroupItems = null;
              });
            },
            onViewItem: (item) {
              setState(() {
                _selectedItemId = item.id;
              });
            },
          );
        }

        return PublicRoomScreen(
          roomId: _publicRoomId!,
          rooms: _rooms,
          onBackToLogin: () {
            setPublicRoomId(null);
            setState(() {
              _selectedGroupItems = null;
              _selectedItemId = null;
            });
          },
          onViewItem: (item) {
            setState(() {
              _selectedItemId = item.id;
            });
          },
          onViewGroup: (groupItems) {
            if (groupItems.length == 1) {
              setState(() {
                _selectedItemId = groupItems.first.id;
              });
            } else {
              setState(() {
                _selectedGroupItems = groupItems;
              });
            }
          },
        );
      }

      return PublicAgencyScreen(
        agencyId: _publicAgencyId!,
        agencies: _agencies,
        onBackToLogin: () {
          setPublicAgencyId(null);
          setPublicRoomId(null);
          setPublicItemId(null);
          setState(() {
            _selectedGroupItems = null;
            _selectedItemId = null;
          });
        },
        onSelectRoom: (room) {
          setPublicRoomId(room.id);
        },
      );
    }

    // 3. Check Public Room View Route
    if (_publicRoomId != null) {
      // Jika user mengeklik 1 barang dari daftar kelompok
      if (_selectedItemId != null) {
        Item? selectedItem;
        Room? selectedRoom;
        for (var r in _rooms) {
          for (var i in r.items) {
            if (i.id == _selectedItemId) {
              selectedItem = i;
              selectedRoom = r;
              break;
            }
          }
          if (selectedItem != null) break;
        }

        if (selectedItem != null && selectedRoom != null) {
          return PublicItemScreen(
            item: selectedItem,
            room: selectedRoom,
            onBack: () {
              setState(() {
                _selectedItemId = null;
              });
            },
          );
        }
      }

      // Jika user mengeklik kelompok barang (misal 5 aset yang sama dalam 1 ruangan)
      if (_selectedGroupItems != null && _selectedGroupItems!.isNotEmpty) {
        final parentRoom = _rooms.firstWhere(
          (r) => r.id == _publicRoomId,
          orElse: () => _rooms.first,
        );
        final List<MapEntry<Item, Room>> matchedGroupEntries =
            _selectedGroupItems!.map((item) => MapEntry(item, parentRoom)).toList();

        return PublicItemListScreen(
          scannedCode: '${_selectedGroupItems!.first.jenisBarang} (${_selectedGroupItems!.length} Unit)',
          matchedItems: matchedGroupEntries,
          onBack: () {
            setState(() {
              _selectedGroupItems = null;
            });
          },
          onViewItem: (item) {
            setState(() {
              _selectedItemId = item.id;
            });
          },
        );
      }

      return PublicRoomScreen(
        roomId: _publicRoomId!,
        rooms: _rooms,
        onBackToLogin: () {
          setPublicRoomId(null);
          setPublicItemId(null);
          setState(() {
            _selectedGroupItems = null;
            _selectedItemId = null;
          });
        },
        onViewItem: (item) {
          setState(() {
            _selectedItemId = item.id;
          });
        },
        onViewGroup: (groupItems) {
          if (groupItems.length == 1) {
            setState(() {
              _selectedItemId = groupItems.first.id;
            });
          } else {
            setState(() {
              _selectedGroupItems = groupItems;
            });
          }
        },
      );
    }

    // 3. Admin view (Standard Flow)
    if (!_isAdminLoggedIn) {
      return LoginScreen(
        onLoginSuccess: () {
          saveToStorage('admin_logged_in', 'true');
          saveToSession('admin_logged_in', 'true');
          setState(() {
            _isAdminLoggedIn = true;
          });
        },
        onScanPressed: () async {
          final result = await Navigator.push<String>(
            context,
            MaterialPageRoute(builder: (_) => const ScanScreen()),
          );
          if (result != null) {
            _handleScannedData(result);
          }
        },
        onHostOverrideChanged: () {
          setState(() {});
        },
      );
    }

    return AgencyListScreen(
      agencies: _agencies,
      onLogout: () {
        removeFromStorage('admin_logged_in');
        removeFromStorage('admin_current_room_id');
        removeFromSession('admin_logged_in');
        removeFromSession('admin_current_room_id');
        setState(() {
          _isAdminLoggedIn = false;
        });
      },
      onAgenciesChanged: (updatedAgencies) {
        setState(() {
          _agencies = updatedAgencies;
          _rooms = updatedAgencies.expand((a) => a.rooms).toList();
        });
      },
      onScanPressed: () async {
        final result = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => const ScanScreen()),
        );
        if (result != null) {
          _handleScannedData(result);
        }
      },
      onHostOverrideChanged: () {
        setState(() {});
      },
    );
  }
}

// ----------------------------------------------------
// 1. LOGIN SCREEN — DP3A DALDUK KB Sulawesi Selatan
// ----------------------------------------------------
class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback onScanPressed;
  final VoidCallback onHostOverrideChanged;

  const LoginScreen({
    Key? key,
    required this.onLoginSuccess,
    required this.onScanPressed,
    required this.onHostOverrideChanged,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  String? _errorMessage;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Professional government-themed color palette
  static const Color _navy = Color(0xFF1A2F5A);
  static const Color _navyLight = Color(0xFF243870);
  static const Color _gold = Color(0xFFCFA836);
  static const Color _goldLight = Color(0xFFE8C155);
  static const Color _slate = Color(0xFF4A5568);
  static const Color _bgLight = Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text == 'admin') {
        widget.onLoginSuccess();
      } else {
        setState(() {
          _errorMessage = 'Password salah! Silakan coba lagi.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;

    return Scaffold(
      backgroundColor: _bgLight,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background: sama seperti dashboard ──
          Positioned.fill(
            child: Image.asset(
              'assets/bg_empowerment.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFF5F7FA).withOpacity(0.75),
                    const Color(0xFFEDF2FB).withOpacity(0.82),
                    const Color(0xFFEAEEF8).withOpacity(0.88),
                  ],
                ),
              ),
            ),
          ),

          // ── Konten ──
          isWide ? _buildWideLayout() : _buildNarrowScrollable(),
        ],
      ),
    );
  }

  // ── Wide layout: sidebar kiri navy + form kanan, RESPONSIF seperti dashboard ──
  Widget _buildWideLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Lebar sidebar proporsional: 30% layar, min 260, max 380
        final sidebarWidth =
            (constraints.maxWidth * 0.30).clamp(260.0, 380.0);
        final isCompact = constraints.maxWidth < 1100;

        return FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Panel Kiri: Informasi Dinas (sidebar) ──
                Container(
                  width: sidebarWidth,
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 28 : 40,
                    vertical: isCompact ? 40 : 60,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1A2F5A), Color(0xFF1E3A6E)],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo Sulsel
                      Container(
                        width: isCompact ? 64 : 80,
                        height: isCompact ? 64 : 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(isCompact ? 14 : 18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(isCompact ? 14 : 18),
                          child: Image.asset('assets/logo_sulsel_original.png',
                              fit: BoxFit.contain),
                        ),
                      ),
                      SizedBox(height: isCompact ? 24 : 36),
                      // Gold accent
                      Container(
                        height: 4,
                        width: 48,
                        decoration: BoxDecoration(
                          color: _gold,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(height: isCompact ? 14 : 20),
                      Text(
                        'Sistem Informasi\nManajemen Aset',
                        style: TextStyle(
                          fontSize: isCompact ? 22 : 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.25,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: isCompact ? 10 : 14),
                      Text(
                        'DP3A DALDUK KB',
                        style: TextStyle(
                          fontSize: isCompact ? 11.5 : 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.72),
                          height: 1.65,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Provinsi Sulawesi Selatan',
                        style: TextStyle(
                          fontSize: isCompact ? 11 : 12,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                      SizedBox(height: isCompact ? 28 : 48),
                      // GENSET Badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 12 : 14,
                          vertical: isCompact ? 10 : 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _gold.withOpacity(0.45),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                color: _goldLight, size: isCompact ? 16 : 18),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'GENSET',
                                  style: TextStyle(
                                    fontSize: isCompact ? 12 : 13,
                                    fontWeight: FontWeight.w800,
                                    color: _goldLight,
                                    letterSpacing: 1,
                                  ),
                                ),
                                Text(
                                  'Gerakan Sayang Aset',
                                  style: TextStyle(
                                    fontSize: isCompact ? 10 : 11,
                                    fontWeight: FontWeight.w400,
                                    color: _gold.withOpacity(0.85),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isCompact ? 14 : 20),
                      Text(
                        'Sistem pencatatan dan pengelolaan\naset inventaris kantor secara\ndigital, terintegrasi dan akuntabel.',
                        style: TextStyle(
                          fontSize: isCompact ? 11 : 12,
                          color: Colors.white.withOpacity(0.55),
                          height: 1.65,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '© ${DateTime.now().year} Sulawesi Selatan\nDP3A DALDUK KB',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.white.withOpacity(0.35),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Panel Kanan: Form Login terpusat ──
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 32 : 60,
                        vertical: 48,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: _buildLoginCard(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  // ── Narrow layout: scrollable, terpusat ──
  Widget _buildNarrowScrollable() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: _buildNarrowLayout(),
          ),
        ),
      ),
    );
  }

  // ── Narrow layout: stacked ──
  Widget _buildNarrowLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Welcome banner (compact — navy blue)
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A2F5A), Color(0xFF243870)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: _navy.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset('assets/logo_sulsel_original.png',
                      fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 3,
                      width: 32,
                      decoration: BoxDecoration(
                        color: _gold,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sistem Manajemen Aset',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'DP3A DALDUK KB — Prov. Sulawesi Selatan',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Login card
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          child: _buildLoginCard(),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    final year = DateTime.now().year;
    return Container(
      width: 420,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE8ECF4),
          width: 1,
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header section
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF3FC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.admin_panel_settings_outlined,
                      color: Color(0xFF1A2F5A), size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Akses Administrator',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2F5A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Panel pengelolaan aset GENSET',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),
            Container(height: 1, color: const Color(0xFFEEF2F8)),
            const SizedBox(height: 24),

            // Password label
            const Text(
              'Kata Sandi',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF344054),
              ),
            ),
            const SizedBox(height: 8),

            // Password Input — clean professional style
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: 'Masukkan kata sandi admin',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: Icon(Icons.lock_outline_rounded,
                    color: _slate, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFD0D8E8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFD0D8E8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _navy, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE53E3E)),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Silakan masukkan kata sandi admin';
                }
                return null;
              },
              onFieldSubmitted: (_) => _handleLogin(),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFEB2B2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFE53E3E), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFE53E3E),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Login Button — Navy Blue
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A2F5A), Color(0xFF2D4A8A)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: _navy.withOpacity(0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.login_rounded, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Masuk ke Panel Admin',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // QR Scan Button — gold outline
            OutlinedButton(
              onPressed: widget.onScanPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _gold, width: 1.5),
                foregroundColor: _navy,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner_rounded, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Pindai QR / Barcode Aset',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Container(height: 1, color: const Color(0xFFEEF2F8)),
            const SizedBox(height: 16),

            // Footer
            Text(
              '© $year DP3A DALDUK KB Provinsi Sulawesi Selatan',
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.grey[400],
                height: 1.5,
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// 1.5. AGENCY LIST SCREEN (INSTANSI)
// ----------------------------------------------------
class AgencyListScreen extends StatefulWidget {
  final List<Agency> agencies;
  final VoidCallback onLogout;
  final ValueChanged<List<Agency>> onAgenciesChanged;
  final VoidCallback onScanPressed;
  final VoidCallback onHostOverrideChanged;

  const AgencyListScreen({
    Key? key,
    required this.agencies,
    required this.onLogout,
    required this.onAgenciesChanged,
    required this.onScanPressed,
    required this.onHostOverrideChanged,
  }) : super(key: key);

  @override
  State<AgencyListScreen> createState() => _AgencyListScreenState();
}

class _AgencyListScreenState extends State<AgencyListScreen> {
  List<Agency> get agencies => widget.agencies;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Logout dialog ──────────────────────────────────────────────────────────
  void _showLogoutConfirmation() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2F5A).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.logout_rounded, color: Color(0xFF1A2F5A), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Keluar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A2F5A))),
                ],
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: const Color(0xFFEEF2F8)),
              const SizedBox(height: 12),
              const Text('Apakah anda yakin untuk keluar dari Panel Admin?',
                  style: TextStyle(fontSize: 13, color: Color(0xFF4A5568), height: 1.4)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFD0D8E8)),
                      foregroundColor: const Color(0xFF4A5568),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF1A2F5A), Color(0xFF2D4A8A)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Ya, Keluar', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm == true && mounted) {
      widget.onLogout();
    }
  }

  // ── Add Agency dialog ──────────────────────────────────────────────────────
  void _showAddAgencyDialog() {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    InputDecoration _navyInput(String label, String hint, IconData icon) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF4A5568), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF1A2F5A), size: 18),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD0D8E8))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD0D8E8))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1A2F5A), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF1A2F5A), Color(0xFF1E3A6E)]),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.domain_add_rounded, color: Color(0xFFE8C155), size: 22),
                      SizedBox(width: 10),
                      Text('Tambah Instansi Baru',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: _navyInput('Nama Instansi', 'Misal: DP3A', Icons.domain_rounded),
                          validator: (v) => (v == null || v.isEmpty) ? 'Nama instansi tidak boleh kosong' : null,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE53935),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                                onPressed: () async {
                                  if (formKey.currentState!.validate()) {
                                    final newAgency = Agency(
                                      id: 'agency-${DateTime.now().millisecondsSinceEpoch}',
                                      name: nameController.text.trim(),
                                      barcode: 'INS-${nameController.text.trim().toUpperCase().replaceAll(' ', '-')}',
                                      rooms: [],
                                    );
                                    if (isSupabaseConfigured) {
                                      try {
                                        await Supabase.instance.client.from('agencies').insert({
                                          'id': newAgency.id,
                                          'name': newAgency.name,
                                          'barcode': newAgency.barcode,
                                        });
                                      } catch (e) {
                                        debugPrint('Supabase Agency Insert Error: $e');
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Gagal simpan ke database: $e'), backgroundColor: const Color(0xFF1A2F5A), duration: const Duration(seconds: 6)),
                                          );
                                        }
                                      }
                                    }
                                    widget.onAgenciesChanged([newAgency, ...agencies]);
                                    if (context.mounted) Navigator.pop(context);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A2F5A),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.save_outlined, size: 16),
                                label: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Edit Agency dialog ─────────────────────────────────────────────────────
  void _showEditAgencyDialog(Agency agency) {
    final nameController = TextEditingController(text: agency.name);
    final formKey = GlobalKey<FormState>();
    bool _hasChanges = false;

    nameController.addListener(() {
      _hasChanges = nameController.text.trim() != agency.name;
    });

    InputDecoration _navyInput(String label, String hint, IconData icon) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF4A5568), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF1A2F5A), size: 18),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD0D8E8))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD0D8E8))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1A2F5A), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, dialogSetState) {
          nameController.addListener(() {
            dialogSetState(() {
              _hasChanges = nameController.text.trim() != agency.name;
            });
          });
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF1A2F5A), Color(0xFF1E3A6E)]),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.edit_outlined, color: Color(0xFFE8C155), size: 22),
                        SizedBox(width: 10),
                        Text('Edit Data Instansi',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: nameController,
                            decoration: _navyInput('Nama Instansi', 'Misal: DP3A', Icons.domain_rounded),
                            validator: (v) => (v == null || v.isEmpty) ? 'Nama instansi tidak boleh kosong' : null,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFE53935)),
                                  foregroundColor: const Color(0xFFE53935),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: _hasChanges ? () async {
                                  if (formKey.currentState!.validate()) {
                                    final newName = nameController.text.trim();
                                    final newBarcode = 'INS-${newName.toUpperCase().replaceAll(' ', '-')}';
                                    if (isSupabaseConfigured) {
                                      try {
                                        await Supabase.instance.client.from('agencies').update({
                                          'name': newName,
                                          'barcode': newBarcode,
                                        }).eq('id', agency.id);
                                      } catch (e) {
                                        debugPrint('Supabase Agency Update Error: $e');
                                      }
                                    }
                                    final updated = agencies.map((a) {
                                      if (a.id == agency.id) return a.copyWith(name: newName, barcode: newBarcode);
                                      return a;
                                    }).toList();
                                    widget.onAgenciesChanged(updated);
                                    if (context.mounted) Navigator.pop(context);
                                  }
                                } : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A2F5A),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.save_outlined, size: 16),
                                label: const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ── Delete Agency ──────────────────────────────────────────────────────────
  Future<void> _deleteAgency(Agency agency) async {
    if (isSupabaseConfigured) {
      try {
        await Supabase.instance.client.from('agencies').delete().eq('id', agency.id);
      } catch (e) {
        debugPrint('Supabase Agency Delete Error: $e');
      }
    }
    final updated = agencies.where((a) => a.id != agency.id).toList();
    widget.onAgenciesChanged(updated);
  }

  // ── QR Dialog ─────────────────────────────────────────────────────────────
  void _showQrDialog(Agency agency) {
    final qrData = 'INS:${agency.id}';
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF1A2F5A), Color(0xFF1E3A6E)]),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_2_rounded, color: Color(0xFFE8C155), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('QR Instansi: ${agency.name}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    QRCodeWidget(data: qrData, size: 200),
                    const SizedBox(height: 16),
                    Text(agency.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A2F5A))),
                    const SizedBox(height: 4),
                    Text(agency.barcode,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Tutup'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFD0D8E8)),
                            foregroundColor: const Color(0xFF4A5568),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF1A2F5A), Color(0xFF2D4A8A)]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () async => await printAgencyLabelImpl(agency),
                            icon: const Icon(Icons.print, size: 16),
                            label: const Text('Cetak QR', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
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
  }

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final filteredAgencies = _searchQuery.isEmpty
        ? agencies
        : agencies.where((a) => a.name.toLowerCase().contains(_searchQuery)).toList();

    // ── Single unified layout (AppBar + Drawer, works on all screen sizes) ─────
    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: Drawer(
        backgroundColor: const Color(0xFF1A2F5A),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8C155).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.domain_rounded, color: Color(0xFFE8C155), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Panel Admin',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('DP3A DALDUK KB\nSulawesi Selatan',
                      style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11, height: 1.4)),
                ),
              ),
              const SizedBox(height: 20),
              Divider(color: Colors.white.withOpacity(0.08), indent: 20, endIndent: 20),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8C155).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE8C155).withOpacity(0.3)),
                  ),
                  child: const ListTile(
                    dense: true,
                    leading: Icon(Icons.domain_rounded, color: Color(0xFFE8C155), size: 20),
                    title: Text('Daftar Instansi', style: TextStyle(color: Color(0xFFE8C155), fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ),
              const Spacer(),
              Divider(color: Colors.white.withOpacity(0.08), indent: 20, endIndent: 20),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('© $year DP3A DALDUK KB\nProvinsi Sulawesi Selatan',
                    style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10, height: 1.5),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showLogoutConfirmation();
                    },
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.25)),
                      foregroundColor: Colors.white.withOpacity(0.8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A2F5A), Color(0xFF1E3A6E)],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8C155).withOpacity(0.22),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.domain_rounded, color: Color(0xFFE8C155), size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Panel Admin',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: widget.onScanPressed,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan QR',
          ),
          IconButton(
            onPressed: _showLogoutConfirmation,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset('assets/bg_empowerment.png', fit: BoxFit.cover),
          ),
          // Gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFF5F7FA).withOpacity(0.60),
                    const Color(0xFFEDF2FB).withOpacity(0.72),
                    const Color(0xFFEAEEF8).withOpacity(0.80),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Main content
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1200),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.6)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _StatCard(icon: Icons.domain_rounded, label: 'Total Instansi', value: '${agencies.length}', color: const Color(0xFF1A2F5A)),
                        _StatCard(icon: Icons.meeting_room_rounded, label: 'Total Ruangan', value: '${agencies.fold<int>(0, (s, a) => s + a.rooms.length)}', color: const Color(0xFF2D7D46)),
                        _StatCard(icon: Icons.inventory_2_rounded, label: 'Total Aset', value: '${agencies.fold<int>(0, (s, a) => a.rooms.fold<int>(s, (rs, r) => rs + r.items.length))}', color: const Color(0xFFC08000)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search + Add button row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFD0D8E8)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Cari instansi...',
                              hintStyle: const TextStyle(color: Color(0xFF9EB0C8), fontSize: 14),
                              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF1A2F5A), size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close_rounded, color: Color(0xFF1A2F5A), size: 18),
                                      onPressed: () => _searchController.clear(),
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _showAddAgencyDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Tambah Instansi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A2F5A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Agency grid / list
                  Expanded(
                    child: agencies.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.domain_disabled_rounded, size: 72,
                                    color: const Color(0xFF1A2F5A).withOpacity(0.15)),
                                const SizedBox(height: 16),
                                const Text('Belum ada instansi',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF4A5568))),
                                const SizedBox(height: 8),
                                const Text('Klik "Tambah Instansi" untuk membuat instansi baru',
                                    style: TextStyle(fontSize: 13, color: Color(0xFF9EB0C8))),
                              ],
                            ),
                          )
                        : filteredAgencies.isEmpty
                            ? Center(
                                child: Text('Instansi "${_searchController.text}" tidak ditemukan',
                                    style: const TextStyle(color: Color(0xFF4A5568), fontSize: 14)),
                              )
                            : GridView.builder(
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 380,
                                  mainAxisExtent: 230,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount: filteredAgencies.length,
                                itemBuilder: (context, index) {
                                  final agency = filteredAgencies[index];
                                  final roomCount = agency.rooms.length;
                                  final assetCount = agency.rooms.fold<int>(0, (s, r) => s + r.items.length);
                                  return Card(
                                    elevation: 0,
                                    color: Colors.white.withOpacity(0.95),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(color: Colors.grey[200]!),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(18.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1A2F5A).withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: const Icon(Icons.domain_rounded, color: Color(0xFF1A2F5A), size: 22),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(agency.name,
                                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111111)),
                                                        overflow: TextOverflow.ellipsis),
                                                    const SizedBox(height: 2),
                                                    Text(agency.barcode,
                                                        style: const TextStyle(fontSize: 11, color: Color(0xFF9EB0C8))),
                                                  ],
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () => _showQrDialog(agency),
                                                borderRadius: BorderRadius.circular(6),
                                                child: QRCodeWidget(
                                                  data: generateAgencyUrl(agency.id),
                                                  size: 55,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),
                                          Row(
                                            children: [
                                              _InfoChip(icon: Icons.meeting_room_outlined, label: '$roomCount Ruangan', color: const Color(0xFF1A2F5A)),
                                              const SizedBox(width: 8),
                                              _InfoChip(icon: Icons.inventory_2_outlined, label: '$assetCount Aset', color: const Color(0xFF2D7D46)),
                                            ],
                                          ),
                                          const Spacer(),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              IconButton(
                                                onPressed: () => _showEditAgencyDialog(agency),
                                                icon: const Icon(Icons.edit_outlined, color: Color(0xFF1A2F5A), size: 20),
                                                tooltip: 'Edit Instansi',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                              const SizedBox(width: 12),
                                              IconButton(
                                                onPressed: () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                      title: const Text('Hapus Instansi?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                                      content: Text('Yakin ingin menghapus instansi "${agency.name}"? Semua ruangan & aset di dalamnya juga akan terhapus.'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(ctx, false),
                                                          child: const Text('Batal', style: TextStyle(color: Color(0xFF4A5568))),
                                                        ),
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(ctx, true),
                                                          child: const Text('Hapus', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true) await _deleteAgency(agency);
                                                },
                                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                                tooltip: 'Hapus Instansi',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                              const Spacer(),
                                              ElevatedButton(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => DashboardScreen(
                                                        rooms: agency.rooms,
                                                        onLogout: widget.onLogout,
                                                        onRoomsChanged: (updatedRooms) {
                                                          final updatedAgency = agency.copyWith(rooms: updatedRooms);
                                                          final updatedAll = agencies.map((a) => a.id == agency.id ? updatedAgency : a).toList();
                                                          widget.onAgenciesChanged(updatedAll);
                                                        },
                                                        onScanPressed: widget.onScanPressed,
                                                        onHostOverrideChanged: widget.onHostOverrideChanged,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF1A2F5A),
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                                child: const Text('Buka', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
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


// ── Helper widgets ─────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEF2F8)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// 2. DASHBOARD / ROOMS LIST SCREEN
// ----------------------------------------------------
class DashboardScreen extends StatefulWidget {
  final List<Room> rooms;
  final VoidCallback onLogout;
  final ValueChanged<List<Room>> onRoomsChanged;
  final VoidCallback onScanPressed;
  final VoidCallback onHostOverrideChanged;

  const DashboardScreen({
    Key? key,
    required this.rooms,
    required this.onLogout,
    required this.onRoomsChanged,
    required this.onScanPressed,
    required this.onHostOverrideChanged,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Room> get rooms => widget.rooms;
  VoidCallback get onLogout => widget.onLogout;
  ValueChanged<List<Room>> get onRoomsChanged => widget.onRoomsChanged;
  VoidCallback get onScanPressed => widget.onScanPressed;
  VoidCallback get onHostOverrideChanged => widget.onHostOverrideChanged;

  final TextEditingController _roomSearchController = TextEditingController();
  String _roomSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _roomSearchController.addListener(() {
      setState(() => _roomSearchQuery = _roomSearchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _roomSearchController.dispose();
    super.dispose();
  }

  void _showLogoutConfirmation() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with navy icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2F5A).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.logout_rounded,
                        color: Color(0xFF1A2F5A), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Keluar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A2F5A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: const Color(0xFFEEF2F8)),
              const SizedBox(height: 12),
              const Text(
                'Apakah anda yakin untuk keluar dari Panel Admin?',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4A5568),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFD0D8E8)),
                      foregroundColor: const Color(0xFF4A5568),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text(
                      'Batal',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A2F5A), Color(0xFF2D4A8A)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        'Ya, Keluar',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm == true && mounted) {
      onLogout();
    }
  }

  void _showAddRoomDialog(BuildContext context) {
    final nameController = TextEditingController();
    final yearController = TextEditingController(text: DateTime.now().year.toString());
    final formKey = GlobalKey<FormState>();

    InputDecoration _navyInput(String label, String hint, IconData icon) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF4A5568), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF1A2F5A), size: 18),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD0D8E8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD0D8E8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1A2F5A), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header navy gradient
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1A2F5A), Color(0xFF1E3A6E)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add_business_rounded, color: Color(0xFFE8C155), size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Buat Ruangan Baru',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Form content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: _navyInput('Nama Ruangan', 'Misal: Ruang Rapat', Icons.meeting_room_outlined),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Nama ruangan tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: yearController,
                          decoration: _navyInput('Tahun', 'Misal: 2024', Icons.calendar_today_outlined),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Tahun tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE53935),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                                onPressed: () async {
                                  if (formKey.currentState!.validate()) {
                                    final newRoom = Room(
                                      id: 'room-${DateTime.now().millisecondsSinceEpoch}',
                                      name: nameController.text,
                                      year: yearController.text,
                                      barcode:
                                          'RM-${nameController.text.toUpperCase().replaceAll(' ', '-')}-${yearController.text}',
                                      items: [],
                                    );

                                    if (isSupabaseConfigured) {
                                      try {
                                        await Supabase.instance.client.from('rooms').insert({
                                          'id': newRoom.id,
                                          'name': newRoom.name,
                                          'year': newRoom.year,
                                          'barcode': newRoom.barcode,
                                        });
                                        debugPrint('Supabase: Room berhasil disimpan!');
                                      } catch (e) {
                                        debugPrint('Supabase Room Insert Error: $e');
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Gagal simpan ke database: $e'),
                                              backgroundColor: const Color(0xFF1A2F5A),
                                              duration: const Duration(seconds: 6),
                                            ),
                                          );
                                        }
                                      }
                                    }

                                    onRoomsChanged([newRoom, ...rooms]);
                                    Navigator.pop(context);
                                  }
                                },
                                icon: const Icon(Icons.save_outlined, size: 16),
                                label: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w700)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A2F5A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
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
          ),
        );
      },
    );
  }

  void _showEditRoomDialog(BuildContext context, Room room) {
    final nameController = TextEditingController(text: room.name);
    final yearController = TextEditingController(text: room.year);
    final formKey = GlobalKey<FormState>();

    InputDecoration _navyInput(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF4A5568), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF1A2F5A), size: 18),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD0D8E8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD0D8E8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1A2F5A), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            bool hasChanges() {
              return nameController.text != room.name || yearController.text != room.year;
            }

            return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header navy gradient
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1A2F5A), Color(0xFF1E3A6E)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: Color(0xFFE8C155), size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Edit Ruangan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Form content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          onChanged: (_) => dialogSetState(() {}),
                          decoration: _navyInput('Nama Ruangan', Icons.meeting_room_outlined),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Nama ruangan tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: yearController,
                          onChanged: (_) => dialogSetState(() {}),
                          decoration: _navyInput('Tahun', Icons.calendar_today_outlined),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Tahun tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.red.shade600,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                                onPressed: !hasChanges() ? null : () async {
                                  if (formKey.currentState!.validate()) {
                                    final editedBarcode = 'RM-${nameController.text.toUpperCase().replaceAll(' ', '-')}-${yearController.text}';

                                    if (isSupabaseConfigured) {
                                      try {
                                        await Supabase.instance.client
                                            .from('rooms')
                                            .update({
                                              'name': nameController.text,
                                              'year': yearController.text,
                                              'barcode': editedBarcode,
                                            })
                                            .eq('id', room.id);
                                      } catch (e) {
                                        debugPrint('Supabase Room Update Error: $e');
                                      }
                                    }

                                    final updatedRooms = rooms.map((r) {
                                      if (r.id == room.id) {
                                        return r.copyWith(
                                          name: nameController.text,
                                          year: yearController.text,
                                          barcode: editedBarcode,
                                        );
                                      }
                                      return r;
                                    }).toList();
                                    onRoomsChanged(updatedRooms);
                                    Navigator.pop(context);
                                  }
                                },
                                icon: const Icon(Icons.save_outlined, size: 16),
                                label: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w700)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A2F5A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
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
          ),
        );
          },
        );
      },
    );
  }

  void _deleteRoom(Room room) async {
    if (isSupabaseConfigured) {
      try {
        await Supabase.instance.client
            .from('rooms')
            .delete()
            .eq('id', room.id);
      } catch (e) {
        debugPrint('Supabase Room Delete Error: $e');
      }
    }
    final updated = rooms.where((r) => r.id != room.id).toList();
    onRoomsChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A2F5A), Color(0xFF1E3A6E)],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFCFA836).withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.inventory_2_outlined,
                  color: Color(0xFFE8C155), size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'GENSET Admin Dashboard',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: onScanPressed,
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Pindai Barcode Aset',
          ),
          IconButton(
            onPressed: _showLogoutConfirmation,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout Admin',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/bg_empowerment.png',
              fit: BoxFit.cover,
            ),
          ),
          // Gradient overlay konsisten dengan login (navy/gold)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFF5F7FA).withOpacity(0.6),
                    const Color(0xFFEDF2FB).withOpacity(0.72),
                    const Color(0xFFEAEEF8).withOpacity(0.80),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Main content with padding
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1200),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header banner / Stats (Responsive)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.6)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: MediaQuery.of(context).size.width > 600
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.door_sliding_outlined,
                                          color: Color(0xFF1A2F5A), size: 24),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Daftar Ruangan Terdaftar',
                                        style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF1A2F5A)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Total ruangan: ${rooms.length}',
                                    style: const TextStyle(
                                        color: Color(0xFF4A5568),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF1A2F5A), Color(0xFF2D4A8A)],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: () => _showAddRoomDialog(context),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Tambah Ruangan'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.door_sliding_outlined,
                                      color: Color(0xFF1A2F5A), size: 24),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Daftar Ruangan Terdaftar',
                                      style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF1A2F5A)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Total ruangan: ${rooms.length}',
                                style: const TextStyle(
                                    color: Color(0xFF4A5568),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF1A2F5A), Color(0xFF2D4A8A)],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: () => _showAddRoomDialog(context),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Tambah Ruangan'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Search bar untuk ruangan
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.6)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _roomSearchController,
                      decoration: InputDecoration(
                        hintText: 'Cari ruangan...',
                        hintStyle: const TextStyle(color: Color(0xFF9EB0C8), fontSize: 14),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF1A2F5A), size: 20),
                        suffixIcon: _roomSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, color: Color(0xFF1A2F5A), size: 18),
                                onPressed: () => _roomSearchController.clear(),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Grid of rooms
                  Expanded(
                    child: rooms.isEmpty
                        ? Center(
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              margin: const EdgeInsets.all(16),
                              constraints: const BoxConstraints(maxWidth: 400),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.6)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.door_sliding_outlined,
                                      size: 80,
                                      color: const Color(0xFF1A2F5A).withOpacity(0.25)),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Belum ada ruangan.',
                                    style: TextStyle(
                                        fontSize: 18,
                                        color: Color(0xFF1A2F5A),
                                        fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Buat ruangan baru untuk mulai menambahkan barang.',
                                    style: TextStyle(color: Color(0xFF4A5568)),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Builder(builder: (context) {
                            final filteredRooms = _roomSearchQuery.isEmpty
                                ? rooms
                                : rooms
                                    .where((r) => r.name.toLowerCase().contains(_roomSearchQuery))
                                    .toList();
                            if (filteredRooms.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.search_off_rounded, size: 60, color: const Color(0xFF1A2F5A).withOpacity(0.2)),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Ruangan "${_roomSearchController.text}" tidak ditemukan',
                                        style: const TextStyle(color: Color(0xFF4A5568), fontSize: 14),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 380,
                              mainAxisExtent: 220,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                            ),
                            itemCount: filteredRooms.length,
                            itemBuilder: (context, index) {
                              final room = filteredRooms[index];
                              return Card(
                                elevation: 0,
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey[200]!),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  room.name,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF111111),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  'Tahun ${room.year}',
                                                  style: const TextStyle(
                                                      color: Color(0xFF555555),
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500),
                                                ),
                                              ],
                                            ),
                                          ),
                                          QRCodeWidget(
                                              data: generateRoomUrl(room.id),
                                              size: 55),
                                        ],
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1A2F5A).withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Jumlah Aset: ${room.items.length} barang',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF1A2F5A)),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            onPressed: () => _showEditRoomDialog(
                                                context, room),
                                            icon: const Icon(Icons.edit_outlined,
                                                color: Color(0xFF1A2F5A)),
                                            tooltip: 'Edit Ruangan',
                                          ),
                                          IconButton(
                                            onPressed: () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => Dialog(
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(20)),
                                                  child: Container(
                                                    constraints: const BoxConstraints(maxWidth: 340),
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        // Header
                                                        Container(
                                                          width: double.infinity,
                                                          padding: const EdgeInsets.all(18),
                                                          decoration: const BoxDecoration(
                                                            gradient: LinearGradient(
                                                              colors: [Color(0xFF1A2F5A), Color(0xFF1E3A6E)],
                                                            ),
                                                            borderRadius: BorderRadius.only(
                                                              topLeft: Radius.circular(20),
                                                              topRight: Radius.circular(20),
                                                            ),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              Container(
                                                                padding: const EdgeInsets.all(6),
                                                                decoration: BoxDecoration(
                                                                  color: Colors.red.withOpacity(0.25),
                                                                  borderRadius: BorderRadius.circular(8),
                                                                ),
                                                                child: const Icon(Icons.delete_outline_rounded,
                                                                    color: Color(0xFFFF8A80), size: 18),
                                                              ),
                                                              const SizedBox(width: 10),
                                                              const Text(
                                                                'Hapus Ruangan?',
                                                                style: TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: Colors.white,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        // Content
                                                        Padding(
                                                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                'Ruangan "${room.name}" beserta seluruh aset di dalamnya akan dihapus permanen dari sistem. Yakin?',
                                                                style: const TextStyle(
                                                                  fontSize: 13,
                                                                  color: Color(0xFF4A5568),
                                                                  height: 1.4,
                                                                ),
                                                              ),
                                                              const SizedBox(height: 20),
                                                              Row(
                                                                mainAxisAlignment: MainAxisAlignment.end,
                                                                children: [
                                                                  OutlinedButton(
                                                                    onPressed: () => Navigator.pop(ctx, false),
                                                                    style: OutlinedButton.styleFrom(
                                                                      side: const BorderSide(color: Color(0xFFD0D8E8)),
                                                                      foregroundColor: const Color(0xFF4A5568),
                                                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                                    ),
                                                                    child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                                                                  ),
                                                                  const SizedBox(width: 10),
                                                                  ElevatedButton.icon(
                                                                    style: ElevatedButton.styleFrom(
                                                                      backgroundColor: const Color(0xFFC0392B),
                                                                      foregroundColor: Colors.white,
                                                                      elevation: 0,
                                                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                                    ),
                                                                    onPressed: () => Navigator.pop(ctx, true),
                                                                    icon: const Icon(Icons.delete_outline, size: 16),
                                                                    label: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
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
                                              if (confirm == true) _deleteRoom(room);
                                            },
                                            icon: const Icon(Icons.delete_outline,
                                                color: Color(0xFFC0392B)),
                                            tooltip: 'Hapus Ruangan',
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFF1A2F5A), Color(0xFF2D4A8A)],
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: ElevatedButton(
                                              onPressed: () {
                                                saveToStorage('admin_current_room_id', room.id);
                                                saveToSession('admin_current_room_id', room.id);
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        RoomDetailsScreen(
                                                      room: room,
                                                      allRooms: rooms,
                                                      onRoomsChanged: onRoomsChanged,
                                                    ),
                                                  ),
                                                ).then((_) {
                                                  removeFromStorage('admin_current_room_id');
                                                  removeFromSession('admin_current_room_id');
                                                });
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.transparent,
                                                foregroundColor: Colors.white,
                                                shadowColor: Colors.transparent,
                                                elevation: 0,
                                              ),
                                              child: const Text('Buka'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }), // end Builder
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

// ----------------------------------------------------
// 3. ROOM DETAILS SCREEN (LIST OF ASSETS & ROOM QR)
// ----------------------------------------------------
class RoomDetailsScreen extends StatefulWidget {
  final Room room;
  final ValueChanged<List<Room>> onRoomsChanged;
  final List<Room> allRooms;

  const RoomDetailsScreen({
    Key? key,
    required this.room,
    required this.onRoomsChanged,
    required this.allRooms,
  }) : super(key: key);

  @override
  State<RoomDetailsScreen> createState() => _RoomDetailsScreenState();
}

class _RoomDetailsScreenState extends State<RoomDetailsScreen> {
  late Room _room;
  late List<Room> _allRooms;

  final TextEditingController _itemSearchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _itemSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _allRooms = List.from(widget.allRooms);
    _itemSearchController.addListener(() {
      setState(() => _itemSearchQuery = _itemSearchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _itemSearchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RoomDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.room != oldWidget.room) {
      _room = widget.room;
    }
    if (widget.allRooms != oldWidget.allRooms) {
      _allRooms = List.from(widget.allRooms);
    }
  }

  /// Generate kode barang otomatis berdasarkan prefix standar + nomor urut
  String _generateNextKodeBarang() {
    const prefix = '1.3.2.10.02.01.';
    // Kumpulkan semua kode barang yang ada di seluruh ruangan
    final allKodes = _allRooms
        .expand((r) => r.items)
        .map((i) => i.kodeBarang)
        .toList();

    // Cari nomor urut tertinggi dari kode dengan prefix yang sama
    int maxNum = 0;
    for (final kode in allKodes) {
      if (kode.startsWith(prefix)) {
        final suffix = kode.substring(prefix.length);
        final num = int.tryParse(suffix);
        if (num != null && num > maxNum) maxNum = num;
      }
    }
    // Nomor urut berikutnya, format 3 digit
    return '$prefix${(maxNum + 1).toString().padLeft(3, '0')}';
  }

  void _showAddEditItemDialog({Item? itemToEdit}) {
    final isEditing = itemToEdit != null;
    final jenisController =
        TextEditingController(text: itemToEdit?.jenisBarang ?? '');
    final merekController =
        TextEditingController(text: itemToEdit?.merekModel ?? '');

    // Kode barang otomatis dinonaktifkan secara default
    // User dapat mengeklik switch/bundaran untuk mengaktifkan & menggenerate kode otomatis
    bool autoGenerateKode = false;
    final kodeController = TextEditingController(
        text: isEditing ? (itemToEdit?.kodeBarang ?? '') : '');

    final noRegisterController =
        TextEditingController(text: itemToEdit?.noRegister ?? '');
    String selectedKondisiAset = itemToEdit?.kondisiAset ?? 'Baik';
    final fotoController =
        TextEditingController(text: itemToEdit?.fotoUrl ?? '');
    final tahunPerolehanController =
        TextEditingController(text: itemToEdit?.tahunPerolehan ?? '');
    // barcode is auto-generated from kodeBarang — no separate controller needed
    final formKey = GlobalKey<FormState>();
    bool isUploadingFoto = false;
    bool isSaving = false;

    // Helper: cek apakah ada perubahan dari data asli (hanya relevan saat edit)
    bool hasChanges() {
      if (!isEditing) return true; // mode tambah selalu aktif
      return jenisController.text != (itemToEdit!.jenisBarang) ||
          merekController.text != (itemToEdit!.merekModel) ||
          kodeController.text != (itemToEdit!.kodeBarang) ||
          noRegisterController.text != (itemToEdit!.noRegister) ||
          selectedKondisiAset != (itemToEdit!.kondisiAset) ||
          fotoController.text != (itemToEdit!.fotoUrl) ||
          tahunPerolehanController.text != (itemToEdit!.tahunPerolehan);
    }

    // Variabel state lokal dialog untuk pencarian autofill
    Item? matchedItem;
    Room? matchedRoom;

    // Helper untuk mencari barang dengan semua data yang sama (kecuali foto)
    Item? findItemByAllData(String jenis, String merek, String noReg, String kondisi) {
      final j = jenis.trim().toLowerCase();
      final m = merek.trim().toLowerCase();
      final nr = noReg.trim().toLowerCase();
      final k = kondisi.trim().toLowerCase();
      if (j.isEmpty || m.isEmpty) return null;
      for (var r in _allRooms) {
        for (var i in r.items) {
          if (i.jenisBarang.trim().toLowerCase() == j &&
              i.merekModel.trim().toLowerCase() == m &&
              i.noRegister.trim().toLowerCase() == nr &&
              i.kondisiAset.trim().toLowerCase() == k &&
              i.id != itemToEdit?.id) {
            return i;
          }
        }
      }
      return null;
    }

    // Backward-compat: cari berdasarkan jenis+merek saja (untuk validator)
    Item? findItemByModel(String jenis, String merek) {
      final j = jenis.trim().toLowerCase();
      final m = merek.trim().toLowerCase();
      if (j.isEmpty || m.isEmpty) return null;
      for (var r in _allRooms) {
        for (var i in r.items) {
          if (i.jenisBarang.trim().toLowerCase() == j &&
              i.merekModel.trim().toLowerCase() == m &&
              i.id != itemToEdit?.id) {
            return i;
          }
        }
      }
      return null;
    }

    void updateKodeBarang() {
      if (!autoGenerateKode) return;
      final jenis = jenisController.text.trim();
      final merek = merekController.text.trim();
      final noReg = noRegisterController.text.trim();
      final kondisi = selectedKondisiAset.trim();

      // Cari barang dengan semua data yang sama (kecuali foto)
      final matched = findItemByAllData(jenis, merek, noReg, kondisi);
      if (matched != null) {
        // Gunakan kode barang yang sama dengan barang serupa
        kodeController.text = matched.kodeBarang;
      } else {
        // Tidak ada yang cocok — cek apakah data sama dengan original (saat edit)
        if (isEditing) {
          final sameJenis = jenis.toLowerCase() == itemToEdit.jenisBarang.trim().toLowerCase();
          final sameMerek = merek.toLowerCase() == itemToEdit.merekModel.trim().toLowerCase();
          final samaNoReg = noReg.toLowerCase() == itemToEdit.noRegister.trim().toLowerCase();
          final samaKondisi = kondisi.toLowerCase() == itemToEdit.kondisiAset.trim().toLowerCase();
          if (sameJenis && sameMerek && samaNoReg && samaKondisi) {
            // Data tidak berubah — pakai kode lama
            kodeController.text = itemToEdit.kodeBarang.isNotEmpty
                ? itemToEdit.kodeBarang
                : _generateNextKodeBarang();
            return;
          }
        }
        if (kodeController.text.trim().isEmpty) {
          kodeController.text = _generateNextKodeBarang();
        }
      }
    }

    void performAutofillLookup(String val, StateSetter dialogSetState) {
      if (val.trim().isEmpty) {
        dialogSetState(() {
          matchedItem = null;
          matchedRoom = null;
        });
        return;
      }
      Item? foundItem;
      Room? foundRoom;
      for (var r in _allRooms) {
        for (var i in r.items) {
          if (i.kodeBarang.trim() == val.trim() && i.id != itemToEdit?.id) {
            foundItem = i;
            foundRoom = r;
            break;
          }
        }
        if (foundItem != null) break;
      }

      dialogSetState(() {
        matchedItem = foundItem;
        matchedRoom = foundRoom;
      });

      if (foundItem != null) {
        jenisController.text = foundItem.jenisBarang;
        merekController.text = foundItem.merekModel;
        noRegisterController.text = foundItem.noRegister;
        selectedKondisiAset = foundItem.kondisiAset.isNotEmpty ? foundItem.kondisiAset : 'Baik';
        fotoController.text = foundItem.fotoUrl;
        tahunPerolehanController.text = foundItem.tahunPerolehan;
      }
    }

    InputDecoration themedInput(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF4A5568), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF1A2F5A), size: 18),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD0D8E8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD0D8E8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1A2F5A), width: 2),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: StatefulBuilder(
            builder: (context, dialogSetState) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 760;
                  final isCodeLocked = autoGenerateKode;

                  Widget livePreview = AnimatedBuilder(
                    animation: Listenable.merge([
                      jenisController,
                      merekController,
                      kodeController,
                      noRegisterController,
                      fotoController,
                      tahunPerolehanController,
                    ]),
                    builder: (context, _) {
                      final kode = kodeController.text.isNotEmpty
                          ? kodeController.text
                          : '1.3.2.10.02.01.009';
                      final previewItem = Item(
                        id: 'preview',
                        jenisBarang: jenisController.text.isNotEmpty
                            ? jenisController.text
                            : 'Jenis Barang',
                        merekModel: merekController.text.isNotEmpty
                            ? merekController.text
                            : 'Merek / Model',
                        kodeBarang: kode,
                        noRegister: noRegisterController.text.isNotEmpty
                            ? noRegisterController.text
                            : '0001',
                        kondisiAset: selectedKondisiAset,
                        fotoUrl: fotoController.text,
                        barcode: kode,
                        tahunPerolehan: tahunPerolehanController.text,
                      );
                      return GensetCard(room: _room, item: previewItem);
                    },
                  );

              Widget formContent = Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header gradient navy (konsisten dengan login)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1A2F5A), Color(0xFF1E3A6E)],
                        ),
                        borderRadius: isWide
                            ? const BorderRadius.only(
                                topLeft: Radius.circular(20))
                            : const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCFA836).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isEditing
                                  ? Icons.edit_note_rounded
                                  : Icons.add_box_rounded,
                              color: const Color(0xFFE8C155),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isEditing
                                  ? 'Edit Data Barang'
                                  : 'Tambah Barang Baru',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white70),
                            tooltip: 'Tutup',
                          ),
                        ],
                      ),
                    ),

                    // Area form yg bisa di-scroll, header di atas tetap
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel(
                                  'Informasi Barang',
                                  Icons.inventory_2_outlined,
                                  const Color(0xFF1A2F5A)),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: jenisController,
                                decoration: themedInput(
                                    'Jenis Barang (Contoh: Serial Printer)',
                                    Icons.category_outlined),
                                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                                onChanged: (val) {
                                  dialogSetState(() {
                                    updateKodeBarang();
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: merekController,
                                decoration: themedInput(
                                    'Merek / Model (Contoh: Epson L5290)',
                                    Icons.devices_outlined),
                                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                                onChanged: (val) {
                                  dialogSetState(() {
                                    updateKodeBarang();
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: tahunPerolehanController,
                                decoration: themedInput(
                                    'Tahun Perolehan (Contoh: 2026)',
                                    Icons.calendar_today_outlined),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                onChanged: (val) {
                                  dialogSetState(() {
                                    updateKodeBarang();
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              // ── Kode Barang dengan toggle auto/manual ──
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Toggle row
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF3FC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: const Color(0xFF1A2F5A)
                                              .withOpacity(0.25)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.auto_fix_high,
                                            size: 16,
                                            color: Color(0xFF1A2F5A)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            autoGenerateKode
                                                ? 'Kode dibuat otomatis'
                                                : 'Masukkan kode manual',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1A2F5A),
                                            ),
                                          ),
                                        ),
                                        Switch(
                                          value: autoGenerateKode,
                                          activeColor:
                                              const Color(0xFF1A2F5A),
                                          onChanged: (val) {
                                            dialogSetState(() {
                                              autoGenerateKode = val;
                                              if (val) {
                                                kodeController.text = (isEditing && itemToEdit != null && itemToEdit!.kodeBarang.isNotEmpty)
                                                    ? itemToEdit!.kodeBarang
                                                    : _generateNextKodeBarang();
                                                updateKodeBarang();
                                              } else {
                                                if (!isEditing) {
                                                  kodeController.clear();
                                                }
                                                matchedItem = null;
                                                matchedRoom = null;
                                              }
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: kodeController,
                                    readOnly: isCodeLocked,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                                    ],
                                    style: TextStyle(
                                      color: isCodeLocked
                                          ? const Color(0xFF555555)
                                          : const Color(0xFF111111),
                                    ),
                                    onChanged: (val) {
                                      performAutofillLookup(val, dialogSetState);
                                    },
                                    decoration: themedInput(
                                      'Kode Barang (Hanya angka & titik)',
                                      Icons.qr_code_outlined,
                                    ).copyWith(
                                      suffixIcon: isCodeLocked
                                          ? const Tooltip(
                                              message:
                                                  'Kode dikunci / dibuat otomatis oleh sistem',
                                              child: Icon(
                                                Icons.lock_outline,
                                                color: Color(0xFF1A2F5A),
                                                size: 18,
                                              ),
                                            )
                                          : null,
                                      filled: true,
                                      fillColor: isCodeLocked
                                          ? const Color(0xFFEFF3FC)
                                          : const Color(0xFFF8FAFC),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Kode barang wajib diisi';
                                      }

                                      final trimmedVal = v.trim();
                                      final currentJenis = jenisController.text.trim();

                                      // Cek apakah kode ini sudah digunakan oleh barang dengan jenis yang berbeda
                                      Item? sameCodeItem;
                                      for (var r in _allRooms) {
                                        for (var i in r.items) {
                                          if (i.kodeBarang.trim() == trimmedVal && i.id != itemToEdit?.id) {
                                            sameCodeItem = i;
                                            break;
                                          }
                                        }
                                        if (sameCodeItem != null) break;
                                      }

                                      if (sameCodeItem != null) {
                                        final sameJenis = sameCodeItem.jenisBarang.trim().toLowerCase() ==
                                            currentJenis.toLowerCase();
                                        // Hanya cek jenis barang — merek boleh berbeda
                                        if (!sameJenis) {
                                          return 'Kode ini milik jenis "${sameCodeItem.jenisBarang}". Jenis barang harus sama (merek boleh berbeda)!';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                  if (matchedRoom != null && matchedRoom!.id != _room.id) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF3CD),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFFFEBAA)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.info_outline, color: Color(0xFF856404), size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Kode aset ini juga terdaftar di "${matchedRoom!.name}". Menyimpan akan menambahkan aset baru di ruangan ini tanpa memindahkan aset dari "${matchedRoom!.name}".',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF856404),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),
                              _sectionLabel(
                                  'No. Register & Kondisi Aset',
                                  Icons.assignment_outlined,
                                  const Color(0xFFCFA836)),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: noRegisterController,
                                decoration: themedInput(
                                    'No. Register Aset', Icons.app_registration_rounded),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (_) => dialogSetState(() => updateKodeBarang()),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                value: ['Baik', 'Kurang Baik', 'Rusak'].contains(selectedKondisiAset)
                                    ? selectedKondisiAset
                                    : 'Baik',
                                decoration: themedInput('Kondisi Aset', Icons.verified_outlined),
                                dropdownColor: Colors.white,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Baik',
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32), size: 18),
                                        SizedBox(width: 8),
                                        Text('Baik', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Kurang Baik',
                                    child: Row(
                                      children: [
                                        Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 18),
                                        SizedBox(width: 8),
                                        Text('Kurang Baik', style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Rusak',
                                    child: Row(
                                      children: [
                                        Icon(Icons.cancel_outlined, color: Color(0xFFC62828), size: 18),
                                        SizedBox(width: 8),
                                        Text('Rusak', style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    dialogSetState(() {
                                      selectedKondisiAset = val;
                                      updateKodeBarang();
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 20),
                              _sectionLabel(
                                  'Foto Barang',
                                  Icons.photo_camera_outlined,
                                  const Color(0xFF1A2F5A)),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: fotoController,
                                      onChanged: (_) => dialogSetState(() {}),
                                      decoration: themedInput(
                                          'URL Foto / Path File Gambar',
                                          Icons.link_outlined),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: isUploadingFoto ? null : () async {
                                      final ImagePicker picker = ImagePicker();
                                      final XFile? image = await picker.pickImage(
                                        source: ImageSource.gallery,
                                        imageQuality: 85,
                                      );
                                      if (image == null) return;
                                      dialogSetState(() => isUploadingFoto = true);
                                      try {
                                        final bytes = await image.readAsBytes();
                                        final ext = image.name.contains('.')
                                            ? image.name.split('.').last.toLowerCase()
                                            : 'jpg';
                                        final fileName =
                                            'foto_${DateTime.now().millisecondsSinceEpoch}.$ext';
                                        await Supabase.instance.client.storage
                                            .from('foto_barang')
                                            .uploadBinary(
                                              fileName,
                                              bytes,
                                              fileOptions: FileOptions(
                                                contentType: 'image/$ext',
                                                upsert: true,
                                              ),
                                            );
                                        final publicUrl = Supabase
                                            .instance.client.storage
                                            .from('foto_barang')
                                            .getPublicUrl(fileName);
                                        fotoController.text = publicUrl;
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                            content: Text(
                                                'Gagal upload foto: $e'),
                                            backgroundColor: Colors.red,
                                          ));
                                        }
                                      } finally {
                                        dialogSetState(
                                            () => isUploadingFoto = false);
                                      }
                                    },
                                    icon: isUploadingFoto
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.photo_library_outlined,
                                            size: 16),
                                    label: Text(
                                        isUploadingFoto ? 'Uploading...' : 'Pilih'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1A2F5A),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 15),
                                    ),
                                  ),
                                  // Tombol hapus foto — muncul hanya jika ada URL
                                  if (fotoController.text.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        dialogSetState(() {
                                          fotoController.clear();
                                        });
                                      },
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      label: const Text('Hapus Foto'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade700,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 15),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                          if (!isWide) ...[
                            const SizedBox(height: 24),
                            _sectionLabel(
                                'Preview Kartu Aset',
                                Icons.preview_outlined,
                                const Color(0xFF1A2F5A)),
                            const SizedBox(height: 10),
                            livePreview,
                          ],
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: Colors.red.shade600,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10))),
                                child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 12),
                               ElevatedButton.icon(
                                onPressed: (isSaving || !hasChanges()) ? null : () async {
                                  if (isSaving) return;
                                  dialogSetState(() => isSaving = true);
                                  try {
                                  if (formKey.currentState!.validate()) {
                                     final newItemId = isEditing
                                         ? itemToEdit.id
                                         : generateUuid(); // UUID acak unik per barang
                                     final newItem = Item(
                                       id: newItemId,
                                       jenisBarang: jenisController.text,
                                       merekModel: merekController.text,
                                       barcode: newItemId, // barcode = ID unik
                                       kodeBarang: kodeController.text,
                                       noRegister: noRegisterController.text,
                                       kondisiAset: selectedKondisiAset,
                                       fotoUrl: fotoController.text,
                                       tahunPerolehan: tahunPerolehanController.text,
                                     );

                                     bool saveSuccess = true;
                                     String? dbError;

                                     if (isSupabaseConfigured) {
                                       try {
                                         if (isEditing) {
                                            await Supabase.instance.client
                                                .from('items')
                                                .update({
                                                  'room_id': _room.id,
                                                  'jenis_barang': newItem.jenisBarang,
                                                  'merek_model': newItem.merekModel,
                                                  'kode_barang': newItem.kodeBarang,
                                                  'no_register': newItem.noRegister,
                                                  'kondisi_aset': newItem.kondisiAset,
                                                  'foto_url': newItem.fotoUrl,
                                                  'barcode': newItem.barcode,
                                                  'tahun_perolehan': newItem.tahunPerolehan,
                                                })
                                                .eq('id', newItem.id);
                                          } else {
                                            await Supabase.instance.client
                                                .from('items')
                                                .insert({
                                                  'id': newItem.id,
                                                  'room_id': _room.id,
                                                  'jenis_barang': newItem.jenisBarang,
                                                  'merek_model': newItem.merekModel,
                                                  'kode_barang': newItem.kodeBarang,
                                                  'no_register': newItem.noRegister,
                                                  'kondisi_aset': newItem.kondisiAset,
                                                  'foto_url': newItem.fotoUrl,
                                                  'barcode': newItem.barcode,
                                                  'tahun_perolehan': newItem.tahunPerolehan,
                                                });
                                          }
                                       } catch (e) {
                                         saveSuccess = false;
                                         dbError = e.toString();
                                         debugPrint('Supabase Item Add/Edit Error: $e');
                                       }
                                     }

                                     if (saveSuccess) {
                                       setState(() {
                                         // Buat copy global dari list ruangan
                                         final List<Room> updatedRooms = _allRooms.map((r) {
                                           if (r.id == _room.id) {
                                             List<Item> newItemsList;
                                             if (isEditing) {
                                               // Hapus item lama, sisipkan hasil edit di posisi paling atas
                                               newItemsList = [newItem, ...r.items.where((i) => i.id != itemToEdit?.id)];
                                             } else {
                                               // Tambah barang baru di posisi paling atas
                                               newItemsList = [newItem, ...r.items];
                                             }
                                             return r.copyWith(items: newItemsList);
                                           }
                                           return r;
                                         }).toList();

                                        // Perbarui state lokal _room agar UI detail ruangan ini langsung update
                                        _allRooms = updatedRooms;
                                        _room = updatedRooms.firstWhere((r) => r.id == _room.id);
                                        
                                        // Beritahu parent dashboard agar state global sinkron
                                        widget.onRoomsChanged(updatedRooms);
                                      });

                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Gagal menyimpan barang ke database: $dbError'),
                                            backgroundColor: Colors.red,
                                            duration: const Duration(seconds: 5),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                  } finally {
                                     dialogSetState(() => isSaving = false);
                                  }
                                },
                                icon: isSaving
                                     ? const SizedBox(
                                         width: 16,
                                         height: 16,
                                         child: CircularProgressIndicator(
                                           strokeWidth: 2,
                                           color: Colors.white,
                                         ),
                                       )
                                     : Icon(isEditing
                                         ? Icons.save_outlined
                                         : Icons.check_circle_outline),
                                 label: Text(isSaving
                                     ? 'Menyimpan...'
                                     : (isEditing ? 'Simpan Perubahan' : 'Tambah Barang')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A2F5A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                  ],
                ),
              );

              if (isWide) {
                return SizedBox(
                  width: 980,
                  height: MediaQuery.of(context).size.height * 0.88,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 480,
                        child: formContent,
                      ),
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFEFF3FC),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.preview_outlined,
                                      color: Color(0xFF1A2F5A), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Preview Kartu Aset',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1A2F5A),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Tampilan real-time sesuai data yang diisi',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF4A5568)),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child:
                                    SingleChildScrollView(child: livePreview),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return SizedBox(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.9,
                child: formContent,
              );
            },
          );
        },
      ),
    );
  },
);
  }

  Widget _sectionLabel(String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  void _deleteItem(Item item) async {
    if (isSupabaseConfigured) {
      try {
        await Supabase.instance.client
            .from('items')
            .delete()
            .eq('id', item.id);
      } catch (e) {
        debugPrint('Supabase Item Delete Error: $e');
      }
    }
    setState(() {
      final updated = _room.items.where((i) => i.id != item.id).toList();
      _room = _room.copyWith(items: updated);
      
      // Sinkronkan ke seluruh ruangan
      final List<Room> updatedRooms = _allRooms.map((r) {
        if (r.id == _room.id) {
          return _room;
        }
        return r;
      }).toList();
      
      _allRooms = updatedRooms;
      widget.onRoomsChanged(updatedRooms);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth <= 900;

    // Sidebar Widget
    final sidebar = Container(
      width: isMobile ? double.infinity : 320,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2F5A).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.meeting_room_outlined,
                    color: Color(0xFF1A2F5A), size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _room.name,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A2F5A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tahun Registrasi: ${_room.year}',
            style: const TextStyle(
                color: Color(0xFF555555),
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
          const Divider(height: 32, thickness: 1),

          // Room QR card (navy/gold theme)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF3FC),
              border: Border.all(color: const Color(0xFF1A2F5A).withOpacity(0.2), width: 1.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2F5A).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'BARCODE RUANGAN',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: Color(0xFF1A2F5A)),
                  ),
                ),
                const SizedBox(height: 12),
                QRCodeWidget(data: generateRoomUrl(_room.id), size: 140),
                const SizedBox(height: 8),
                Text(
                  _room.barcode,
                  style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: Color(0xFF1A2F5A)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async => await printRoomLabelImpl(_room),
                  icon: const Icon(Icons.print, size: 14, color: Color(0xFFCFA836)),
                  label: const Text(
                    'Cetak Label Ruangan',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFCFA836),
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile) const Spacer(),
          if (isMobile) const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A2F5A), Color(0xFF2D4A8A)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A2F5A).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => _showAddEditItemDialog(),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Tambah Barang', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );

    // Right/Bottom Pane Content
    final filteredItems = _itemSearchQuery.isEmpty
        ? _room.items
        : _room.items
            .where((item) =>
                item.jenisBarang.toLowerCase().contains(_itemSearchQuery) ||
                item.merekModel.toLowerCase().contains(_itemSearchQuery) ||
                item.kodeBarang.toLowerCase().contains(_itemSearchQuery) ||
                item.noRegister.toLowerCase().contains(_itemSearchQuery) ||
                item.kondisiAset.toLowerCase().contains(_itemSearchQuery))
            .toList();

    final rightPaneContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined,
                            color: Color(0xFF1A2F5A), size: 24),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Daftar Barang',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1A2F5A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _itemSearchQuery.isEmpty
                          ? 'Menampilkan ${_room.items.length} barang terdaftar'
                          : 'Ditemukan ${filteredItems.length} dari ${_room.items.length} barang',
                      style: const TextStyle(
                          color: Color(0xFF4A5568),
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Search bar untuk barang
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _itemSearchController,
            decoration: InputDecoration(
              hintText: 'Cari barang (nama, kode, merek, pengguna)...',
              hintStyle: const TextStyle(color: Color(0xFF9EB0C8), fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF1A2F5A), size: 20),
              suffixIcon: _itemSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF1A2F5A), size: 18),
                      onPressed: () => _itemSearchController.clear(),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Inventory Items List
        _room.items.isEmpty
            ? Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 70,
                          color: const Color(0xFF1A2F5A).withOpacity(0.2)),
                      const SizedBox(height: 16),
                      const Text(
                        'Belum ada barang di ruangan ini',
                        style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF1A2F5A),
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1A2F5A), Color(0xFF2D4A8A)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddEditItemDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Tambahkan Barang Pertama'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : filteredItems.isEmpty && _itemSearchQuery.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 60, color: const Color(0xFF1A2F5A).withOpacity(0.2)),
                          const SizedBox(height: 12),
                          const Text(
                            'Barang tidak ditemukan',
                            style: TextStyle(color: Color(0xFF4A5568), fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];

                  // GensetCard fills available width automatically via LayoutBuilder
                  final cardWidget = GensetCard(room: _room, item: item);

                  final barcodePanel = Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF3FC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1A2F5A).withOpacity(0.18)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Hanya QR Code — ID unik tersembunyi di dalam QR, tidak ditampilkan ke kartu
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFCFA836).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'QR SCAN HP',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFCFA836),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                QRCodeWidget(
                                  data: generateItemUrl(item.id),
                                  size: 80,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Kode: ${item.kodeBarang}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF1A2F5A),
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: () async => await printItemLabelImpl(item, _room),
                          icon: const Icon(Icons.print, size: 14,
                              color: Color(0xFFCFA836)),
                          label: const Text(
                            'Cetak Label Barang',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFCFA836),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Title & Action bar of asset card container (navy theme)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1A2F5A), Color(0xFF1E3A6E)],
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline,
                                        color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.jenisBarang,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () => _showAddEditItemDialog(
                                        itemToEdit: item),
                                    icon: const Icon(Icons.edit,
                                        color: Colors.white, size: 18),
                                    tooltip: 'Edit Barang',
                                  ),
                                  IconButton(
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => Dialog(
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20)),
                                          child: Container(
                                            constraints: const BoxConstraints(maxWidth: 340),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Header
                                                Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(18),
                                                  decoration: const BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [Color(0xFF1A2F5A), Color(0xFF1E3A6E)],
                                                    ),
                                                    borderRadius: BorderRadius.only(
                                                      topLeft: Radius.circular(20),
                                                      topRight: Radius.circular(20),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.all(6),
                                                        decoration: BoxDecoration(
                                                          color: Colors.red.withOpacity(0.25),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: const Icon(Icons.delete_outline_rounded,
                                                            color: Color(0xFFFF8A80), size: 18),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      const Text(
                                                        'Hapus Barang?',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Content
                                                Padding(
                                                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Barang "${item.jenisBarang} - ${item.merekModel}" akan dihapus permanen dari sistem dan database. Yakin?',
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          color: Color(0xFF4A5568),
                                                          height: 1.4,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 20),
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.end,
                                                        children: [
                                                          OutlinedButton(
                                                            onPressed: () => Navigator.pop(ctx, false),
                                                            style: OutlinedButton.styleFrom(
                                                              side: const BorderSide(color: Color(0xFFD0D8E8)),
                                                              foregroundColor: const Color(0xFF4A5568),
                                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                            ),
                                                            child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                                                          ),
                                                          const SizedBox(width: 10),
                                                          ElevatedButton.icon(
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: const Color(0xFFC0392B),
                                                              foregroundColor: Colors.white,
                                                              elevation: 0,
                                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                            ),
                                                            onPressed: () => Navigator.pop(ctx, true),
                                                            icon: const Icon(Icons.delete_outline, size: 16),
                                                            label: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
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
                                      if (confirm == true) _deleteItem(item);
                                    },
                                    icon: const Icon(Icons.delete,
                                        color: Color(0xFFFF8A80), size: 18),
                                    tooltip: 'Hapus Barang',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Card Body (Responsive Layout)
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: isMobile
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    cardWidget,
                                    const SizedBox(height: 20),
                                    barcodePanel,
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 1. Beautiful card template rendered
                                    Expanded(flex: 3, child: cardWidget),
                                    const SizedBox(width: 24),
                                    // 2. Barcode info Panel
                                    Expanded(flex: 2, child: barcodePanel),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A2F5A), Color(0xFF1E3A6E)],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(
          'Detail Ruangan: ${_room.name}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/bg_empowerment.png',
              fit: BoxFit.cover,
            ),
          ),
          // Gradient overlay konsisten dengan login (navy)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFF5F7FA).withOpacity(0.6),
                    const Color(0xFFEDF2FB).withOpacity(0.72),
                    const Color(0xFFEAEEF8).withOpacity(0.80),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Main content with padding
          Positioned.fill(
            child: isMobile
                ? SingleChildScrollView(
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            sidebar,
                            const SizedBox(height: 24),
                            rightPaneContent,
                          ],
                        ),
                      ),
                    ),
                  )
                // Desktop: Single scroll view with smooth floating sticky sidebar
                : SingleChildScrollView(
                    controller: _scrollController,
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        padding: const EdgeInsets.all(24.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedBuilder(
                              animation: _scrollController,
                              builder: (context, child) {
                                double offset = 0.0;
                                if (_scrollController.hasClients) {
                                  offset = _scrollController.offset.clamp(0.0, double.infinity);
                                }
                                return Transform.translate(
                                  offset: Offset(0, offset),
                                  child: child,
                                );
                              },
                              child: sidebar,
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: rightPaneContent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// PUBLIC AGENCY VIEW SCREEN (READ ONLY)
// ----------------------------------------------------
class PublicAgencyScreen extends StatefulWidget {
  final String agencyId;
  final List<Agency> agencies;
  final VoidCallback onBackToLogin;
  final ValueChanged<Room> onSelectRoom;

  const PublicAgencyScreen({
    Key? key,
    required this.agencyId,
    required this.agencies,
    required this.onBackToLogin,
    required this.onSelectRoom,
  }) : super(key: key);

  @override
  State<PublicAgencyScreen> createState() => _PublicAgencyScreenState();
}

class _PublicAgencyScreenState extends State<PublicAgencyScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agency = widget.agencies.firstWhere(
      (a) => a.id == widget.agencyId || a.barcode.trim().toUpperCase() == widget.agencyId.trim().toUpperCase(),
      orElse: () => Agency(id: '', name: '', barcode: '', rooms: []),
    );

    if (agency.id.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Instansi Tidak Ditemukan',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: widget.onBackToLogin,
                child: const Text('Ke Halaman Utama'),
              ),
            ],
          ),
        ),
      );
    }

    final filteredRooms = _searchQuery.isEmpty
        ? agency.rooms
        : agency.rooms
            .where((r) => r.name.toLowerCase().contains(_searchQuery))
            .toList();

    final totalAssets = agency.rooms.fold<int>(0, (s, r) => s + r.items.length);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A2F5A), Color(0xFF1E3A6E)],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onBackToLogin,
          tooltip: 'Kembali',
        ),
        title: Text('GENSET Instansi: ${agency.name}'),
      ),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset('assets/bg_empowerment.png', fit: BoxFit.cover),
          ),
          // Gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFF5F7FA).withOpacity(0.60),
                    const Color(0xFFEDF2FB).withOpacity(0.75),
                    const Color(0xFFEAEEF8).withOpacity(0.85),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Agency Header Banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD0D8E8)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1A2F5A).withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A2F5A).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.domain_rounded,
                                  color: Color(0xFF1A2F5A), size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    agency.name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1A2F5A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Kode Instansi: ${agency.barcode}',
                                    style: const TextStyle(
                                      color: Color(0xFF4A5568),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _InfoChip(
                              icon: Icons.meeting_room_outlined,
                              label: '${agency.rooms.length} Ruangan Terdaftar',
                              color: const Color(0xFF1A2F5A),
                            ),
                            const SizedBox(width: 10),
                            _InfoChip(
                              icon: Icons.inventory_2_outlined,
                              label: '$totalAssets Total Aset',
                              color: const Color(0xFF2D7D46),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Search Bar
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD0D8E8)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari ruangan dalam instansi ini...',
                        hintStyle: const TextStyle(
                            color: Color(0xFF9EB0C8), fontSize: 14),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Color(0xFF1A2F5A), size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: Color(0xFF1A2F5A), size: 18),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section Title
                  const Text(
                    'Daftar Ruangan Terdaftar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A2F5A),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // List of Rooms (Read Only view)
                  Expanded(
                    child: filteredRooms.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.meeting_room_outlined,
                                    size: 64,
                                    color: const Color(0xFF1A2F5A)
                                        .withOpacity(0.2)),
                                const SizedBox(height: 12),
                                const Text(
                                  'Tidak ada ruangan ditemukan',
                                  style: TextStyle(
                                      color: Color(0xFF4A5568),
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredRooms.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final room = filteredRooms[index];
                              final itemCount = room.items.length;
                              return Card(
                                elevation: 0,
                                color: Colors.white.withOpacity(0.95),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: Colors.grey[200]!),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1A2F5A)
                                              .withOpacity(0.08),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                            Icons.meeting_room_rounded,
                                            color: Color(0xFF1A2F5A),
                                            size: 24),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              room.name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF111111),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  'Tahun: ${room.year}',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF4A5568)),
                                                ),
                                                const SizedBox(width: 12),
                                                _InfoChip(
                                                  icon: Icons
                                                      .inventory_2_outlined,
                                                  label: '$itemCount Aset',
                                                  color: const Color(0xFF2D7D46),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Read-only "Lihat Aset" button
                                      ElevatedButton.icon(
                                        onPressed: () => widget.onSelectRoom(room),
                                        icon: const Icon(Icons.visibility_outlined,
                                            size: 16),
                                        label: const Text('Lihat Aset',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF1A2F5A),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
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

// ----------------------------------------------------
// 4. PUBLIC ROOM VIEW SCREEN
// ----------------------------------------------------
class PublicRoomScreen extends StatelessWidget {
  final String roomId;
  final List<Room> rooms;
  final VoidCallback onBackToLogin;
  final ValueChanged<Item> onViewItem;
  final ValueChanged<List<Item>> onViewGroup;

  const PublicRoomScreen({
    Key? key,
    required this.roomId,
    required this.rooms,
    required this.onBackToLogin,
    required this.onViewItem,
    required this.onViewGroup,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final room = rooms.firstWhere(
      (r) => r.id == roomId,
      orElse: () => Room(id: '', name: '', year: '', barcode: '', items: []),
    );

    if (room.id.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Ruangan Tidak Ditemukan',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ElevatedButton(
                  onPressed: onBackToLogin,
                  child: const Text('Ke Halaman Utama')),
            ],
          ),
        ),
      );
    }

    // Group items by jenisBarang and merekModel (case-insensitive)
    final Map<String, List<Item>> groupedMap = {};
    for (final item in room.items) {
      final key = '${item.jenisBarang.trim().toLowerCase()}|${item.merekModel.trim().toLowerCase()}';
      groupedMap.putIfAbsent(key, () => []).add(item);
    }
    final groupedItems = groupedMap.values.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A2F5A), Color(0xFF1E3A6E)],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: onBackToLogin,
          tooltip: 'Kembali',
        ),
        title: Text('GENSET Ruangan: ${room.name}'),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD0D8E8)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A2F5A).withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.name,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1A2F5A)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tahun Registrasi Ruang: ${room.year}',
                            style: const TextStyle(
                                color: Color(0xFF4A5568),
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    QRCodeWidget(data: generateRoomUrl(room.id), size: 80),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Aset dalam Ruangan ini:',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A2F5A)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2F5A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${room.items.length} Barang',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A2F5A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: room.items.isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada barang terdaftar di ruangan ini.',
                          style: TextStyle(
                              color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                      )
                    : ListView.builder(
                        itemCount: groupedItems.length,
                        itemBuilder: (context, index) {
                          final group = groupedItems[index];
                          final item = group.first;
                          final count = group.length;
                          return Card(
                            color: Colors.white,
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Colors.grey[200]!),
                            ),
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC9E12C).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: item.fotoUrl.isNotEmpty
                                      ? (item.fotoUrl.startsWith('http') ||
                                              item.fotoUrl.startsWith('blob:') ||
                                              item.fotoUrl.startsWith('data:'))
                                          ? Image.network(
                                              item.fotoUrl,
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  const Icon(Icons.inventory_2,
                                                      color: Color(0xFF111111)),
                                            )
                                          : Image.asset(
                                              item.fotoUrl,
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  const Icon(Icons.inventory_2,
                                                      color: Color(0xFF111111)),
                                            )
                                      : const Icon(Icons.inventory_2,
                                          color: Color(0xFF111111)),
                                ),
                              ),
                              title: Text(
                                item.jenisBarang,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111111)),
                              ),
                              subtitle: Text(
                                count > 1
                                    ? '${item.merekModel} • ${item.kodeBarang} • Jumlah: $count'
                                    : '${item.merekModel} • ${item.kodeBarang}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(Icons.chevron_right,
                                  color: Colors.grey),
                              onTap: () => onViewGroup(group),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// 5. PUBLIC ITEM VIEW SCREEN
// ----------------------------------------------------
class PublicItemScreen extends StatelessWidget {
  final Item item;
  final Room room;
  final VoidCallback onBack;

  const PublicItemScreen({
    Key? key,
    required this.item,
    required this.room,
    required this.onBack,
  }) : super(key: key);

  Widget _buildZoomableCardDialog(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black.withOpacity(0.9),
      child: Stack(
        children: [
          // Interactive Zoom Area
          Center(
            child: InteractiveViewer(
              panEnabled: true,
              scaleEnabled: true,
              minScale: 1.0,
              maxScale: 5.0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: GensetCard(room: room, item: item),
                ),
              ),
            ),
          ),
          // Controls overlay
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.zoom_in, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Cubit untuk zoom / Seret untuk geser',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.6),
                    padding: const EdgeInsets.all(10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A2F5A), Color(0xFF1E3A6E)],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: const Text('Detail Registrasi Aset'),
      ),
      body: InteractiveViewer(
        panEnabled: true,
        scaleEnabled: true,
        minScale: 0.5,
        maxScale: 5.0,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    children: [
                      // Zoomable Template Card
                      FittedBox(
                        fit: BoxFit.contain,
                        child: Container(
                          width: 600, // Force internal rendering at full width
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: GensetCard(room: room, item: item),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Bottom info panel
                      Container(
                        width: 720,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Informasi Label QR & Barcode Fisik',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Kode Barang: ${item.kodeBarang}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF4A4A4A),
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Informasi di atas merupakan data resmi DP3A DALDUK KB Provinsi Sulawesi Selatan.',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF555555),
                                        height: 1.4,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            QRCodeWidget(data: generateItemUrl(item.id), size: 70),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// 6. PUBLIC ITEM LIST VIEW SCREEN (For Scanned Duplicates)
// ----------------------------------------------------
class PublicItemListScreen extends StatelessWidget {
  final String scannedCode;
  final List<MapEntry<Item, Room>> matchedItems;
  final VoidCallback onBack;
  final ValueChanged<Item> onViewItem;

  const PublicItemListScreen({
    Key? key,
    required this.scannedCode,
    required this.matchedItems,
    required this.onBack,
    required this.onViewItem,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A2F5A), Color(0xFF1E3A6E)],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Daftar Aset Terdeteksi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card showing scanned code info
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.grey[100]!),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC9E12C).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Color(0xFF111111),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hasil Pemindaian Kode',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF777777),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            scannedCode,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111111),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Aset untuk Dilihat:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111111),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2F5A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${matchedItems.length} Duplikat',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A2F5A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // List of items
              Expanded(
                child: ListView.builder(
                  itemCount: matchedItems.length,
                  itemBuilder: (context, index) {
                    final item = matchedItems[index].key;
                    final room = matchedItems[index].value;
                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[200]!),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onViewItem(item),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              // Image
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC9E12C).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: item.fotoUrl.isNotEmpty
                                      ? (item.fotoUrl.startsWith('http') ||
                                              item.fotoUrl.startsWith('blob:') ||
                                              item.fotoUrl.startsWith('data:'))
                                          ? Image.network(
                                              item.fotoUrl,
                                              width: 64,
                                              height: 64,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  const Icon(Icons.inventory_2,
                                                      color: Color(0xFF111111), size: 28),
                                            )
                                          : Image.asset(
                                              item.fotoUrl,
                                              width: 64,
                                              height: 64,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  const Icon(Icons.inventory_2,
                                                      color: Color(0xFF111111), size: 28),
                                            )
                                      : const Icon(Icons.inventory_2,
                                          color: Color(0xFF111111), size: 28),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.jenisBarang,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF111111),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Merek/Model: ${item.merekModel}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                       children: [
                                         const Icon(Icons.meeting_room_outlined,
                                             size: 14, color: Colors.grey),
                                         const SizedBox(width: 4),
                                         Expanded(
                                           child: Text(
                                             'Ruangan: ${room.name}',
                                             style: const TextStyle(
                                               fontSize: 12,
                                               color: Colors.grey,
                                             ),
                                             maxLines: 1,
                                             overflow: TextOverflow.ellipsis,
                                           ),
                                         ),
                                       ],
                                     ),
                                     const SizedBox(height: 4),
                                     Row(
                                       children: [
                                         if (item.noRegister.isNotEmpty) ...[
                                           Container(
                                             padding: const EdgeInsets.symmetric(
                                                 horizontal: 8, vertical: 2),
                                             decoration: BoxDecoration(
                                               color: const Color(0xFF1A2F5A).withOpacity(0.08),
                                               borderRadius: BorderRadius.circular(6),
                                             ),
                                             child: Text(
                                               'Reg: ${item.noRegister}',
                                               style: const TextStyle(
                                                 fontSize: 11,
                                                 fontWeight: FontWeight.w600,
                                                 color: Color(0xFF1A2F5A),
                                               ),
                                             ),
                                           ),
                                           const SizedBox(width: 6),
                                         ],
                                         Container(
                                           padding: const EdgeInsets.symmetric(
                                               horizontal: 8, vertical: 2),
                                           decoration: BoxDecoration(
                                             color: item.kondisiAset.toLowerCase() == 'rusak'
                                                 ? const Color(0xFFFFEBEE)
                                                 : item.kondisiAset.toLowerCase() == 'kurang baik'
                                                     ? const Color(0xFFFFF3E0)
                                                     : const Color(0xFFE8F5E9),
                                             borderRadius: BorderRadius.circular(6),
                                           ),
                                           child: Text(
                                             item.kondisiAset.isNotEmpty ? item.kondisiAset : 'Baik',
                                             style: TextStyle(
                                               fontSize: 11,
                                               fontWeight: FontWeight.w700,
                                               color: item.kondisiAset.toLowerCase() == 'rusak'
                                                   ? const Color(0xFFC62828)
                                                   : item.kondisiAset.toLowerCase() == 'kurang baik'
                                                       ? const Color(0xFFE65100)
                                                       : const Color(0xFF2E7D32),
                                             ),
                                           ),
                                         ),
                                       ],
                                     ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_ios_rounded,
                                  size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
