import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'genset_card.dart';
import 'barcode_widget.dart';
import 'scan_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'printer_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

String generateItemUrl(String itemId) {
  return '$kPublicBaseUrl/?item=$itemId';
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
  String? _publicRoomId;
  String? _publicItemId;
  String? _selectedItemId;


  // Simulated database of rooms & items
  List<Room> _rooms = [];

  @override
  void initState() {
    super.initState();
    _initData();
    _checkUrlRouting();
  }

  Future<void> _initData() async {
    if (isSupabaseConfigured) {
      await _fetchDataFromSupabase();
    } else {
      _loadSampleData();
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
          return Item(
            id: itemData['id'] ?? '',
            jenisBarang: itemData['jenis_barang'] ?? '',
            merekModel: itemData['merek_model'] ?? '',
            kodeBarang: itemData['kode_barang'] ?? '',
            namaPengguna: itemData['nama_pengguna'] ?? '',
            nipPengguna: itemData['nip_pengguna'] ?? '',
            teleponPengguna: itemData['telepon_pengguna'] ?? '',
            fotoUrl: itemData['foto_url'] ?? '',
            barcode: itemData['barcode'] ?? '',
          );
        }).toList();

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
    if (queryParams.containsKey('room')) {
      setState(() {
        _publicRoomId = queryParams['room'];
      });
    } else if (queryParams.containsKey('item')) {
      setState(() {
        _publicItemId = queryParams['item'];
      });
    }
  }

  void _handleScannedData(String scannedText) {
    // Coba parsing jika input berupa URL
    final uri = Uri.tryParse(scannedText);
    if (uri != null && uri.host.isNotEmpty) {
      final queryParams = uri.queryParameters;
      if (queryParams.containsKey('room')) {
        setState(() {
          _publicRoomId = queryParams['room'];
          _publicItemId = null;
        });
        return;
      } else if (queryParams.containsKey('item')) {
        setState(() {
          _publicItemId = queryParams['item'];
          _publicRoomId = null;
        });
        return;
      }
    }

    final cleanedText = scannedText.trim();

    // Cari item berdasarkan kodeBarang atau barcode
    bool hasItemMatch = false;
    for (var r in _rooms) {
      for (var i in r.items) {
        if (i.kodeBarang.trim() == cleanedText ||
            i.barcode.trim() == cleanedText ||
            i.id.trim() == cleanedText) {
          hasItemMatch = true;
          break;
        }
      }
      if (hasItemMatch) break;
    }

    if (hasItemMatch) {
      setState(() {
        _publicItemId = cleanedText;
        _publicRoomId = null;
        _selectedItemId = null;
      });
      return;
    }

    // Cari ruangan berdasarkan barcode atau ID
    for (var r in _rooms) {
      if (r.barcode.trim().toUpperCase() == cleanedText.toUpperCase() ||
          r.id.trim() == cleanedText) {
        setState(() {
          _publicRoomId = r.id;
          _publicItemId = null;
        });
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
            namaPengguna: 'Zul Fadli Al Gifari, A. Md. M',
            nipPengguna: '20010523 202203 I 001',
            teleponPengguna: '0852-5154-2879',
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
            namaPengguna: 'Hj. Andi Kartini, S.E., M.Si.',
            nipPengguna: '19750912 199903 I 002',
            teleponPengguna: '0811-4567-8910',
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
            namaPengguna: 'Rahmat Hidayat, S. Kom.',
            nipPengguna: '19920815 201803 I 003',
            teleponPengguna: '0812-9876-5432',
            fotoUrl:
                'https://images.unsplash.com/photo-1547082299-de196ea013d6?q=80&w=400&auto=format&fit=crop',
            barcode: '1.3.2.10.02.03.003',
          ),
        ],
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

    // 1. Check Public Item View Route
    if (_publicItemId != null) {
      final List<MapEntry<Item, Room>> matchedItems = [];
      for (var r in _rooms) {
        for (var i in r.items) {
          if (i.id == _publicItemId ||
              i.kodeBarang.trim() == _publicItemId!.trim() ||
              i.barcode.trim() == _publicItemId!.trim()) {
            matchedItems.add(MapEntry(i, r));
          }
        }
      }

      if (matchedItems.isNotEmpty) {
        if (_selectedItemId != null) {
          final selectedEntry = matchedItems.firstWhere(
            (entry) => entry.key.id == _selectedItemId,
            orElse: () => matchedItems.first,
          );
          return PublicItemScreen(
            item: selectedEntry.key,
            room: selectedEntry.value,
            onBack: () {
              setState(() {
                if (matchedItems.length > 1) {
                  _selectedItemId = null;
                } else {
                  _publicItemId = null;
                  _selectedItemId = null;
                }
              });
            },
          );
        }

        if (matchedItems.length == 1) {
          return PublicItemScreen(
            item: matchedItems.first.key,
            room: matchedItems.first.value,
            onBack: () {
              setState(() {
                _publicItemId = null;
                _selectedItemId = null;
              });
            },
          );
        }

        return PublicItemListScreen(
          scannedCode: _publicItemId!,
          matchedItems: matchedItems,
          onBack: () {
            setState(() {
              _publicItemId = null;
              _selectedItemId = null;
            });
          },
          onViewItem: (item) {
            setState(() {
              _selectedItemId = item.id;
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
                    setState(() {
                      _publicItemId = null;
                      _publicRoomId = null;
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

    // 2. Check Public Room View Route
    if (_publicRoomId != null) {
      return PublicRoomScreen(
        roomId: _publicRoomId!,
        rooms: _rooms,
        onBackToLogin: () {
          setState(() {
            _publicRoomId = null;
            _publicItemId = null;
          });
        },
        onViewItem: (item) {
          setState(() {
            _publicItemId = item.id;
          });
        },
      );
    }

    // 3. Admin view (Standard Flow)
    if (!_isAdminLoggedIn) {
      return LoginScreen(
        onLoginSuccess: () {
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

    return DashboardScreen(
      rooms: _rooms,
      onLogout: () {
        setState(() {
          _isAdminLoggedIn = false;
        });
      },
      onRoomsChanged: (updatedRooms) {
        setState(() {
          _rooms = updatedRooms;
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
// 1. LOGIN SCREEN — Tema Pemberdayaan Perempuan & Anak
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

  // Warm, empowerment-themed color palette
  static const Color _coral = Color(0xFFE8776F);
  static const Color _rose = Color(0xFFD4567A);
  static const Color _teal = Color(0xFF2A9D8F);
  static const Color _warmCream = Color(0xFFFFF8F0);
  static const Color _mustard = Color(0xFFE9C46A);

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
    final screenSize = MediaQuery.of(context).size;
    final isWide = screenSize.width > 900;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background Image ──
          Positioned.fill(
            child: Image.asset(
              'assets/bg_empowerment.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),

          // ── Gradient overlay for readability ──
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFFF8F0).withOpacity(0.35),
                    const Color(0xFFE8776F).withOpacity(0.18),
                    const Color(0xFF2A9D8F).withOpacity(0.22),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // ── Content ──
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Wide layout: side‑by‑side welcome + login ──
  Widget _buildWideLayout() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left — Welcome Panel
        Container(
          width: 380,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE8776F), Color(0xFFD4567A)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              bottomLeft: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: _rose.withOpacity(0.3),
                blurRadius: 40,
                offset: const Offset(-10, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo Sulsel
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/logo_sulsel.png',
                      fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Selamat Datang',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Dinas Pemberdayaan Perempuan,\nPerlindungan Anak, Pengendalian\nPenduduk dan Keluarga Berencana',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.92),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 3,
                width: 50,
                decoration: BoxDecoration(
                  color: _mustard,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '✿ GENSET — Gerakan Sayang Aset',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.85),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sistem pencatatan dan pengelolaan aset\nuntuk mendukung pelayanan terbaik bagi\nperempuan dan anak di Sulawesi Selatan.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        // Right — Login Card
        _buildLoginCard(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
      ],
    );
  }

  // ── Narrow layout: stacked ──
  Widget _buildNarrowLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Welcome banner (compact)
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE8776F), Color(0xFFD4567A)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: _rose.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset('assets/logo_sulsel.png',
                          fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selamat Datang',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Dinas Pemberdayaan Perempuan, Perlindungan Anak, Pengendalian Penduduk dan Keluarga Berencana',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
        // Login card
        Container(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _buildLoginCard(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard({required BorderRadius borderRadius}) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        // Glassmorphism effect
        color: Colors.white.withOpacity(0.92),
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: _teal.withOpacity(0.08),
            blurRadius: 60,
            offset: const Offset(10, 30),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.6),
          width: 1.5,
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // GENSET Branding
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE8776F), Color(0xFFD4567A)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _coral.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'GENSET',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Gerakan Sayang Aset',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF4A4A4A),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Divider with heart
            Row(
              children: [
                Expanded(
                    child:
                        Container(height: 1, color: const Color(0xFFEEE0E0))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.favorite,
                      size: 14, color: _coral.withOpacity(0.4)),
                ),
                Expanded(
                    child:
                        Container(height: 1, color: const Color(0xFFEEE0E0))),
              ],
            ),
            const SizedBox(height: 24),

            const Text(
              'Login Admin',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF333333),
              ),
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: 6),
            Text(
              'Masukkan password untuk mengakses panel admin',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF4A4A4A),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Password Input — styled warmly
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                prefixIcon: Icon(Icons.lock_outline,
                    color: _coral.withOpacity(0.7), size: 20),
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
                fillColor: const Color(0xFFFFF5F3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFf0d4d0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFf0d4d0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _coral, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Silakan masukkan password admin';
                }
                return null;
              },
              onFieldSubmitted: (_) => _handleLogin(),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFD0D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Login Button — warm gradient
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE8776F), Color(0xFFD4567A)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _coral.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.login_rounded, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Masuk ke Panel',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: widget.onScanPressed,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2A9D8F), width: 1.5),
                foregroundColor: const Color(0xFF2A9D8F),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Pindai QR / Barcode Aset',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            // Footer
            Text(
              '© ${2026} Dinas Pemberdayaan Perempuan, Perlindungan Anak,\nPengendalian Penduduk dan Keluarga Berencana\nProvinsi Sulawesi Selatan',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[400],
                height: 1.5,
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
// 2. DASHBOARD / ROOMS LIST SCREEN
// ----------------------------------------------------
class DashboardScreen extends StatelessWidget {
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

  void _showAddRoomDialog(BuildContext context) {
    final nameController = TextEditingController();
    final yearController = TextEditingController(text: '2024');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Buat Ruangan Baru'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Ruangan',
                    hintText: 'Misal: Ruang Rapat',
                  ),
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
                  decoration: const InputDecoration(
                    labelText: 'Tahun',
                    hintText: 'Misal: 2024',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Tahun tidak boleh kosong';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
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
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 6),
                          ),
                        );
                      }
                    }
                  }

                  onRoomsChanged([...rooms, newRoom]);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                foregroundColor: Colors.white,
              ),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showEditRoomDialog(BuildContext context, Room room) {
    final nameController = TextEditingController(text: room.name);
    final yearController = TextEditingController(text: room.year);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Ruangan'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nama Ruangan'),
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
                  decoration: const InputDecoration(labelText: 'Tahun'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Tahun tidak boleh kosong';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
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
              child: const Text('Simpan'),
            ),
          ],
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
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        title: const Text(
          'GENSET Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: onScanPressed,
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Pindai Barcode Aset',
          ),
          IconButton(
            onPressed: onLogout,
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
          // Gradient overlay for readability
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFFF8F0).withOpacity(0.4),
                    const Color(0xFFE8776F).withOpacity(0.2),
                    const Color(0xFF2A9D8F).withOpacity(0.2),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Main content with padding
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header banner / Stats (Responsive)
                MediaQuery.of(context).size.width > 600
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Daftar Ruangan Terdaftar',
                                style: TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w900),
                              ),
                              Text(
                                'Total ruangan: ${rooms.length}',
                                style: const TextStyle(
                                    color: Color(0xFF4A4A4A),
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showAddRoomDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Tambah Ruangan'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC9E12C),
                              foregroundColor: const Color(0xFF111111),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Daftar Ruangan Terdaftar',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Total ruangan: ${rooms.length}',
                            style: const TextStyle(
                                color: Color(0xFF4A4A4A),
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => _showAddRoomDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Tambah Ruangan'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC9E12C),
                              foregroundColor: const Color(0xFF111111),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 24),

                // Grid of rooms (unchanged)
                Expanded(
                  child: rooms.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.door_sliding_outlined,
                                  size: 80, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              const Text(
                                'Belum ada ruangan.',
                                style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Buat ruangan baru untuk mulai menambahkan barang.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 380,
                            mainAxisExtent: 220,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                          ),
                          itemCount: rooms.length,
                          itemBuilder: (context, index) {
                            final room = rooms[index];
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
                                    Text(
                                      'Jumlah Aset: ${room.items.length} barang',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          onPressed: () => _showEditRoomDialog(
                                              context, room),
                                          icon: const Icon(Icons.edit_outlined),
                                          tooltip: 'Edit Ruangan',
                                        ),
                                        IconButton(
                                          onPressed: () => _deleteRoom(room),
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.red),
                                          tooltip: 'Hapus Ruangan',
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () {
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
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF111111),
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Buka'),
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

  @override
  void initState() {
    super.initState();
    _room = widget.room;
  }

  /// Generate kode barang otomatis berdasarkan prefix standar + nomor urut
  String _generateNextKodeBarang() {
    const prefix = '1.3.2.10.02.01.';
    // Kumpulkan semua kode barang yang ada di seluruh ruangan
    final allKodes = widget.allRooms
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

    // Kode barang selalu auto-generate (berlaku untuk tambah & edit)
    // User bisa matikan toggle jika ingin input manual
    bool autoGenerateKode = true;
    final kodeController = TextEditingController(
        text: isEditing ? itemToEdit.kodeBarang : '');

    final namaUserController =
        TextEditingController(text: itemToEdit?.namaPengguna ?? '');
    final nipUserController =
        TextEditingController(text: itemToEdit?.nipPengguna ?? '');
    final telpUserController =
        TextEditingController(text: itemToEdit?.teleponPengguna ?? '');
    final fotoController =
        TextEditingController(text: itemToEdit?.fotoUrl ?? '');
    // barcode is auto-generated from kodeBarang — no separate controller needed
    final formKey = GlobalKey<FormState>();
    bool isUploadingFoto = false;

    // Variabel state lokal dialog untuk pencarian autofill
    Item? matchedItem;
    Room? matchedRoom;

    // Helper untuk mencari barang dengan semua data yang sama (kecuali foto)
    Item? findItemByAllData(String jenis, String merek, String nama, String nip, String telp) {
      final j = jenis.trim().toLowerCase();
      final m = merek.trim().toLowerCase();
      final n = nama.trim().toLowerCase();
      final ni = nip.trim();
      final t = telp.trim();
      if (j.isEmpty || m.isEmpty) return null;
      for (var r in widget.allRooms) {
        for (var i in r.items) {
          if (i.jenisBarang.trim().toLowerCase() == j &&
              i.merekModel.trim().toLowerCase() == m &&
              i.namaPengguna.trim().toLowerCase() == n &&
              i.nipPengguna.trim() == ni &&
              i.teleponPengguna.trim() == t &&
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
      for (var r in widget.allRooms) {
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
      final nama = namaUserController.text.trim();
      final nip = nipUserController.text.trim();
      final telp = telpUserController.text.trim();

      // Kode hanya di-generate setelah jenis, merek, dan nama terisi
      if (jenis.isEmpty || merek.isEmpty || nama.isEmpty) {
        kodeController.text = '';
        return;
      }

      // Cari barang dengan semua data yang sama (kecuali foto)
      final matched = findItemByAllData(jenis, merek, nama, nip, telp);
      if (matched != null) {
        // Gunakan kode barang yang sama dengan barang serupa
        kodeController.text = matched.kodeBarang;
      } else {
        // Tidak ada yang cocok — cek apakah data sama dengan original (saat edit)
        if (isEditing) {
          final sameJenis = jenis.toLowerCase() == itemToEdit.jenisBarang.trim().toLowerCase();
          final sameMerek = merek.toLowerCase() == itemToEdit.merekModel.trim().toLowerCase();
          final samaNama = nama.toLowerCase() == itemToEdit.namaPengguna.trim().toLowerCase();
          final samaNip = nip == itemToEdit.nipPengguna.trim();
          final samaTelp = telp == itemToEdit.teleponPengguna.trim();
          if (sameJenis && sameMerek && samaNama && samaNip && samaTelp) {
            // Data tidak berubah — pakai kode lama
            kodeController.text = itemToEdit.kodeBarang;
            return;
          }
        }
        // Data baru / berbeda — generate kode urut berikutnya
        kodeController.text = _generateNextKodeBarang();
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
      for (var r in widget.allRooms) {
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
        namaUserController.text = foundItem.namaPengguna;
        nipUserController.text = foundItem.nipPengguna;
        telpUserController.text = foundItem.teleponPengguna;
        fotoController.text = foundItem.fotoUrl;
      }
    }

    InputDecoration themedInput(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF888888), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF2A9D8F), size: 18),
        filled: true,
        fillColor: const Color(0xFFFFF8F4),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFFFD5C8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFFFD5C8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2A9D8F), width: 2),
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
                  final isCodeLocked = autoGenerateKode ||
                      findItemByModel(
                              jenisController.text, merekController.text) !=
                          null;

              Widget livePreview = AnimatedBuilder(
                animation: Listenable.merge([
                  jenisController,
                  merekController,
                  kodeController,
                  namaUserController,
                  nipUserController,
                  telpUserController,
                  fotoController,
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
                    namaPengguna: namaUserController.text.isNotEmpty
                        ? namaUserController.text
                        : 'Nama Pengguna',
                    nipPengguna: nipUserController.text.isNotEmpty
                        ? nipUserController.text
                        : 'NIP / ID',
                    teleponPengguna: telpUserController.text.isNotEmpty
                        ? telpUserController.text
                        : '08xx-xxxx-xxxx',
                    fotoUrl: fotoController.text,
                    barcode: kode, // auto-generated from kodeBarang
                  );
                  return GensetCard(room: _room, item: previewItem);
                },
              );

              Widget formContent = Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header gradient
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE8776F), Color(0xFF2A9D8F)],
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
                          Icon(
                            isEditing
                                ? Icons.edit_note_rounded
                                : Icons.add_box_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isEditing
                                  ? 'Edit Data Barang'
                                  : 'Tambah Barang Baru',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white),
                            tooltip: 'Tutup',
                          ),
                        ],
                      ),
                    ),

                        // Form fields
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _sectionLabel(
                                  'Informasi Barang',
                                  Icons.inventory_2_outlined,
                                  const Color(0xFFE8776F)),
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
                              // ── Kode Barang dengan toggle auto/manual ──
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Toggle row
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FBF9),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: const Color(0xFF2A9D8F)
                                              .withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.auto_fix_high,
                                            size: 16,
                                            color: Color(0xFF2A9D8F)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            autoGenerateKode
                                                ? 'Kode dibuat otomatis'
                                                : 'Masukkan kode manual',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2A9D8F),
                                            ),
                                          ),
                                        ),
                                        Switch(
                                          value: autoGenerateKode,
                                          activeColor:
                                              const Color(0xFF2A9D8F),
                                          onChanged: (val) {
                                            dialogSetState(() {
                                              autoGenerateKode = val;
                                              if (val) {
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
                                    style: TextStyle(
                                      color: isCodeLocked
                                          ? const Color(0xFF555555)
                                          : const Color(0xFF111111),
                                    ),
                                    onChanged: (val) {
                                      performAutofillLookup(val, dialogSetState);
                                    },
                                    decoration: themedInput(
                                      'Kode Barang',
                                      Icons.qr_code_outlined,
                                    ).copyWith(
                                      suffixIcon: isCodeLocked
                                          ? const Tooltip(
                                              message:
                                                  'Kode dikunci / dibuat otomatis oleh sistem',
                                              child: Icon(
                                                Icons.lock_outline,
                                                color: Color(0xFF2A9D8F),
                                                size: 18,
                                              ),
                                            )
                                          : null,
                                      filled: true,
                                      fillColor: isCodeLocked
                                          ? const Color(0xFFEDF7F6)
                                          : const Color(0xFFFFF8F4),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Kode barang wajib diisi';
                                      }

                                      final trimmedVal = v.trim();
                                      final currentJenis = jenisController.text.trim();
                                      final currentMerek = merekController.text.trim();

                                      // 1. Cek apakah ada item lain dengan jenis & merek yang sama
                                      final matchedModel = findItemByModel(currentJenis, currentMerek);
                                      if (matchedModel != null) {
                                        if (matchedModel.kodeBarang.trim() != trimmedVal) {
                                          return 'Jenis & merek ini sudah ada dengan kode "${matchedModel.kodeBarang}". Kode harus sama!';
                                        }
                                      }

                                      // 2. Cek apakah kode ini sudah digunakan oleh barang dengan jenis/merek lain
                                      Item? sameCodeItem;
                                      for (var r in widget.allRooms) {
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
                                        final sameMerek = sameCodeItem.merekModel.trim().toLowerCase() ==
                                            currentMerek.toLowerCase();
                                        if (!sameJenis || !sameMerek) {
                                          return 'Kode ini milik "${sameCodeItem.jenisBarang} - ${sameCodeItem.merekModel}". Nama & Merek harus sama!';
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
                                              'Aset terdaftar di "${matchedRoom!.name}". Menyimpan akan memindahkan aset tersebut ke ruangan ini.',
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
                              const SizedBox(height: 20),
                              _sectionLabel(
                                  'Data Pengguna',
                                  Icons.person_outline_rounded,
                                  const Color(0xFF2A9D8F)),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: namaUserController,
                                decoration: themedInput(
                                    'Nama Pengguna', Icons.badge_outlined),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r"[a-zA-ZÀ-öø-ÿ\s.,\-']"),
                                  ),
                                ],
                                keyboardType: TextInputType.name,
                                textCapitalization: TextCapitalization.words,
                                onChanged: (_) => dialogSetState(() => updateKodeBarang()),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: nipUserController,
                                decoration: themedInput(
                                    'NIP / ID Pengguna', Icons.numbers_outlined),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9\s\-]'),
                                  ),
                                ],
                                keyboardType: TextInputType.number,
                                onChanged: (_) => dialogSetState(() => updateKodeBarang()),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: telpUserController,
                                decoration: themedInput(
                                    'Telepon Pengguna', Icons.phone_outlined),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9\-]'),
                                  ),
                                  LengthLimitingTextInputFormatter(15),
                                ],
                                keyboardType: TextInputType.phone,
                                onChanged: (_) => dialogSetState(() => updateKodeBarang()),
                              ),
                              const SizedBox(height: 20),
                              _sectionLabel(
                                  'Foto Barang',
                                  Icons.photo_camera_outlined,
                                  const Color(0xFFE8776F)),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: fotoController,
                                      decoration: themedInput(
                                          'URL Foto / Path File Gambar',
                                          Icons.link_outlined),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
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
                                      backgroundColor: const Color(0xFF2A9D8F),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 15),
                                    ),
                                  ),
                                ],
                              ),
                          if (!isWide) ...[
                            const SizedBox(height: 24),
                            _sectionLabel(
                                'Preview Kartu Aset',
                                Icons.preview_outlined,
                                const Color(0xFF2A9D8F)),
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
                                    foregroundColor: const Color(0xFF888888)),
                                child: const Text('Batal'),
                              ),
                              const SizedBox(width: 12),
                               ElevatedButton.icon(
                                onPressed: () async {
                                   if (!isEditing && kodeController.text.trim().isNotEmpty) {
                                     final val = kodeController.text.trim();
                                     Item? foundItem;
                                     Room? foundRoom;
                                     for (var r in widget.allRooms) {
                                       for (var i in r.items) {
                                         if (i.kodeBarang.trim() == val) {
                                           foundItem = i;
                                           foundRoom = r;
                                           break;
                                         }
                                       }
                                       if (foundItem != null) break;
                                     }
                                     if (foundItem != null) {
                                       final nonNullItem = foundItem;
                                       dialogSetState(() {
                                         matchedItem = nonNullItem;
                                         matchedRoom = foundRoom;
                                         jenisController.text = nonNullItem.jenisBarang;
                                         merekController.text = nonNullItem.merekModel;
                                         namaUserController.text = nonNullItem.namaPengguna;
                                         nipUserController.text = nonNullItem.nipPengguna;
                                         telpUserController.text = nonNullItem.teleponPengguna;
                                         fotoController.text = nonNullItem.fotoUrl;
                                       });
                                     }
                                   }
                                  if (formKey.currentState!.validate()) {
                                    final bool isMoving = matchedItem != null;
                                    final newItem = Item(
                                      id: isMoving
                                          ? matchedItem!.id
                                          : (isEditing
                                              ? itemToEdit.id
                                              : 'item-${DateTime.now().millisecondsSinceEpoch}'),
                                      jenisBarang: jenisController.text,
                                      merekModel: merekController.text,
                                      kodeBarang: kodeController.text,
                                      namaPengguna: namaUserController.text,
                                      nipPengguna: nipUserController.text,
                                      teleponPengguna: telpUserController.text,
                                      fotoUrl: fotoController.text,
                                      barcode: kodeController.text,
                                    );

                                    if (isSupabaseConfigured) {
                                      try {
                                        if (isEditing || isMoving) {
                                          await Supabase.instance.client
                                              .from('items')
                                              .update({
                                                'room_id': _room.id,
                                                'jenis_barang': newItem.jenisBarang,
                                                'merek_model': newItem.merekModel,
                                                'kode_barang': newItem.kodeBarang,
                                                'nama_pengguna': newItem.namaPengguna,
                                                'nip_pengguna': newItem.nipPengguna,
                                                'telepon_pengguna': newItem.teleponPengguna,
                                                'foto_url': newItem.fotoUrl,
                                                'barcode': newItem.barcode,
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
                                                'nama_pengguna': newItem.namaPengguna,
                                                'nip_pengguna': newItem.nipPengguna,
                                                'telepon_pengguna': newItem.teleponPengguna,
                                                'foto_url': newItem.fotoUrl,
                                                'barcode': newItem.barcode,
                                              });
                                        }
                                      } catch (e) {
                                        debugPrint('Supabase Item Add/Edit Error: $e');
                                      }
                                    }

                                    setState(() {
                                      // Buat copy global dari list ruangan
                                      final List<Room> updatedRooms = widget.allRooms.map((r) {
                                        // 1. Jika ini adalah ruangan asal barang yang dipindah
                                        if (isMoving && r.id == matchedRoom!.id) {
                                          return r.copyWith(
                                            items: r.items.where((i) => i.id != matchedItem!.id).toList(),
                                          );
                                        }
                                        // 2. Jika ini adalah ruangan saat ini (tujuan)
                                        if (r.id == _room.id) {
                                          List<Item> newItemsList;
                                          if (isEditing) {
                                            newItemsList = r.items
                                                .map((i) => i.id == itemToEdit.id ? newItem : i)
                                                .toList();
                                          } else {
                                            // Jika dipindah, keluarkan dulu versi lamanya dari ruangan ini (antisipasi)
                                            newItemsList = r.items.where((i) => i.id != newItem.id).toList();
                                            newItemsList.add(newItem);
                                          }
                                          return r.copyWith(items: newItemsList);
                                        }
                                        return r;
                                      }).toList();

                                      // Perbarui state lokal _room agar UI detail ruangan ini langsung update
                                      _room = updatedRooms.firstWhere((r) => r.id == _room.id);
                                      
                                      // Beritahu parent dashboard agar state global sinkron
                                      widget.onRoomsChanged(updatedRooms);
                                    });

                                    Navigator.pop(context);
                                  }
                                },
                                icon: Icon(isEditing
                                    ? Icons.save_outlined
                                    : Icons.check_circle_outline),
                                label: Text(isEditing
                                    ? 'Simpan Perubahan'
                                    : 'Tambah Barang'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE8776F),
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
                        child: SingleChildScrollView(child: formContent),
                      ),
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF8F4),
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
                                      color: Color(0xFF2A9D8F), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Preview Kartu Aset',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2A9D8F),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Tampilan real-time sesuai data yang diisi',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF888888)),
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
                child: SingleChildScrollView(child: formContent),
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
      final List<Room> updatedRooms = widget.allRooms.map((r) {
        if (r.id == _room.id) {
          return _room;
        }
        return r;
      }).toList();
      
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
              const Icon(Icons.meeting_room_outlined,
                  color: Color(0xFFE8776F), size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _room.name,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2C3E50)),
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

          // Room QR card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F0),
              border: Border.all(color: const Color(0xFFFFE3D1), width: 1.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  'BARCODE RUANGAN',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Color(0xFFE8776F)),
                ),
                const SizedBox(height: 12),
                QRCodeWidget(data: generateRoomUrl(_room.id), size: 140),
                const SizedBox(height: 8),
                Text(
                  _room.barcode,
                  style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async => await printRoomLabelImpl(_room),
                  icon: const Icon(Icons.print, size: 14, color: Color(0xFFE8776F)),
                  label: const Text(
                    'Cetak Label Ruangan',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFE8776F),
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile) const Spacer(),
          if (isMobile) const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showAddEditItemDialog(),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Tambah Barang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A9D8F),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );

    // Right/Bottom Pane Content
    final rightPaneContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        color: Color(0xFF2A9D8F), size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Daftar Barang',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2C3E50)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Menampilkan ${_room.items.length} barang terdaftar',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

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
                          color: const Color(0xFFE8776F).withOpacity(0.5)),
                      const SizedBox(height: 16),
                      const Text(
                        'Belum ada barang di ruangan ini',
                        style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF2C3E50),
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showAddEditItemDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Tambahkan Barang Pertama'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A9D8F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: isMobile,
                physics: isMobile ? const NeverScrollableScrollPhysics() : null,
                itemCount: _room.items.length,
                itemBuilder: (context, index) {
                  final item = _room.items[index];

                  // GensetCard fills available width automatically via LayoutBuilder
                  final cardWidget = GensetCard(room: _room, item: item);

                  final barcodePanel = Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFE3D1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              children: [
                                const Text(
                                  'BARCODE BARANG',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFE8776F),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                BarcodeWidget(
                                  data: item.kodeBarang,
                                  width: 150,
                                  height: 55,
                                ),
                              ],
                            ),
                            const SizedBox(width: 20),
                            Column(
                              children: [
                                const Text(
                                  'QR SCAN HP',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2A9D8F),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                QRCodeWidget(
                                  data: generateItemUrl(item.id),
                                  size: 55,
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
                              color: Color(0xFF555555),
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: () async => await printItemLabelImpl(item, _room),
                          icon: const Icon(Icons.print, size: 14,
                              color: Color(0xFF2A9D8F)),
                          label: const Text(
                            'Cetak Label Barang',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF2A9D8F),
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
                        // Title & Action bar of asset card container
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2A9D8F), // warm teal header
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle_outline,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    item.jenisBarang,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
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
                                        builder: (ctx) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16)),
                                          title: const Text('Hapus Barang?',
                                              style: TextStyle(fontWeight: FontWeight.bold)),
                                          content: Text(
                                              'Barang "${item.jenisBarang} - ${item.merekModel}" akan dihapus permanen dari sistem dan database. Yakin?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: const Text('Batal'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white),
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('Hapus'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) _deleteItem(item);
                                    },
                                    icon: const Icon(Icons.delete,
                                        color: Color(0xFFFFF0F0), size: 18),
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
        backgroundColor: const Color(0xFF111111),
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
          // Gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFFF8F0).withOpacity(0.4),
                    const Color(0xFFE8776F).withOpacity(0.2),
                    const Color(0xFF2A9D8F).withOpacity(0.2),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Main content with padding
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        sidebar,
                        const SizedBox(height: 24),
                        rightPaneContent,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        sidebar,
                        Expanded(
                          child: rightPaneContent,
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

  const PublicRoomScreen({
    Key? key,
    required this.roomId,
    required this.rooms,
    required this.onBackToLogin,
    required this.onViewItem,
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

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        title: Text('GENSET Ruangan: ${room.name}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
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
                        Text(
                          room.name,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111111)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tahun Registrasi Ruang: ${room.year}',
                          style: const TextStyle(
                              color: Color(0xFF555555),
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
                      color: Color(0xFF111111)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9E12C).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${room.items.length} Barang',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111111),
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
                      itemCount: room.items.length,
                      itemBuilder: (context, index) {
                        final item = room.items[index];
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
                              '${item.merekModel} • ${item.kodeBarang}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.chevron_right,
                                color: Colors.grey),
                            onTap: () => onViewItem(item),
                          ),
                        );
                      },
                    ),
            ),
          ],
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
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
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
                              'Informasi di atas merupakan data resmi Dinas Pemberdayaan Perempuan, Perlindungan Anak, Pengendalian Penduduk dan Keluarga Berencana Provinsi Sulawesi Selatan.',
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
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
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
                      color: const Color(0xFF2A9D8F).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${matchedItems.length} Duplikat',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D6A4F),
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
                                    if (item.namaPengguna.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8776F).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'User: ${item.namaPengguna}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFC04037),
                                          ),
                                        ),
                                      ),
                                    ],
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
