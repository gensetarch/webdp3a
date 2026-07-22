import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'models.dart';

class GensetCard extends StatelessWidget {
  final Room room;
  final Item item;
  final String logoUrl;

  const GensetCard({
    Key? key,
    required this.room,
    required this.item,
    this.logoUrl = 'assets/logo_sulsel_original.png',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder so the card fills its parent width automatically
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth.isInfinite ? 600.0 : constraints.maxWidth;
        // Scale all sizes relative to a reference width of 600
        final scale = (cardWidth / 600.0).clamp(0.55, 1.4);

        return Container(
          width: cardWidth,
          decoration: BoxDecoration(
            // Cream white background matching the theme
            color: const Color(0xFFFFF8F4),
            border: Border.all(color: const Color(0xFFFFD5C8), width: 1.5),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE8776F).withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Background Star shape (top-right corner decoration) — theme color
              Positioned(
                top: -30 * scale,
                right: -30 * scale,
                width: 130 * scale,
                height: 130 * scale,
                child: ClipPath(
                  clipper: StarClipper(),
                  child: Container(
                    color: const Color(0xFFE8776F).withOpacity(0.18),
                  ),
                ),
              ),
              // Accent line at top edge
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 4,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE8776F), Color(0xFF2A9D8F)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                ),
              ),

              // Card contents
              Padding(
                padding: EdgeInsets.only(
                  top: 18 * scale,
                  bottom: 18 * scale,
                  left: 20 * scale,
                  right: 20 * scale,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ROW 1: Header — GENSET logo left, Sulsel logo + Dinas text right
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left: GENSET branding
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GENSET',
                              style: TextStyle(
                                fontSize: 26 * scale,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF1A1A1A),
                                letterSpacing: -0.5,
                                height: 1.0,
                              ),
                            ),
                            SizedBox(height: 2 * scale),
                            Text(
                              'GErakaN Sayang asET',
                              style: TextStyle(
                                fontSize: 9 * scale,
                                color: const Color(0xFF2A9D8F),
                                letterSpacing: 0.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: 16 * scale),
                        // Vertical divider
                        Container(
                          height: 40 * scale,
                          width: 1.5,
                          color: const Color(0xFFFFD5C8),
                        ),
                        SizedBox(width: 16 * scale),
                        // Right: Logo + Dinas name
                        _buildImage(logoUrl, width: 40 * scale, height: 40 * scale),
                        SizedBox(width: 8 * scale),
                        Expanded(
                          child: Text(
                            'Dinas Pemberdayaan Perempuan, Perlindungan Anak,\nPengendalian Penduduk dan Keluarga Berencana\nProvinsi Sulawesi Selatan',
                            style: TextStyle(
                              fontSize: 9.5 * scale,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1A1A),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 14 * scale),
                    // Gradient divider line
                    Container(
                      height: 1.5,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFE8776F), Color(0xFF2A9D8F)],
                        ),
                      ),
                    ),
                    SizedBox(height: 12 * scale),

                    // ROW 2: Main body — two columns
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT COLUMN: Room & Year
                        SizedBox(
                          width: 160 * scale,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Label
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 3 * scale),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A9D8F).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Jenis Barang',
                                  style: TextStyle(
                                    fontSize: 9 * scale,
                                    color: const Color(0xFF2A9D8F),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              SizedBox(height: 6 * scale),
                              Text(
                                item.jenisBarang,
                                style: TextStyle(
                                  fontSize: 18 * scale,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF1A1A1A),
                                  height: 1.2,
                                ),
                              ),
                              SizedBox(height: 14 * scale),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 3 * scale),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8776F).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Ruangan',
                                  style: TextStyle(
                                    fontSize: 9 * scale,
                                    color: const Color(0xFFE8776F),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              SizedBox(height: 6 * scale),
                              Text(
                                room.name,
                                style: TextStyle(
                                  fontSize: 16 * scale,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF1A1A1A),
                                  height: 1.2,
                                ),
                              ),
                              SizedBox(height: 8 * scale),
                              Text(
                                item.tahunPerolehan.isNotEmpty ? item.tahunPerolehan : room.year,
                                style: TextStyle(
                                  fontSize: 14 * scale,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF555555),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 16 * scale),

                        // RIGHT COLUMN: Kode Barang, Model, Data Pengguna, Photo
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Kode Barang
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 3 * scale),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A1A).withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Kode Barang',
                                  style: TextStyle(
                                    fontSize: 9 * scale,
                                    color: const Color(0xFF555555),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              SizedBox(height: 4 * scale),
                              Text(
                                item.kodeBarang,
                                style: TextStyle(
                                  fontSize: 14 * scale,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                              SizedBox(height: 6 * scale),
                              Text(
                                item.merekModel,
                                style: TextStyle(
                                  fontSize: 11 * scale,
                                  color: const Color(0xFF333333),
                                  height: 1.5,
                                ),
                              ),
                              SizedBox(height: 12 * scale),
                              // Divider
                              Container(
                                height: 1,
                                color: const Color(0xFFFFD5C8),
                              ),
                              SizedBox(height: 10 * scale),
                              // Register & Kondisi Aset
                              Text(
                                'Register & Kondisi Aset',
                                style: TextStyle(
                                  fontSize: 13 * scale,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF1A1A1A),
                                  height: 1.2,
                                ),
                              ),
                              SizedBox(height: 6 * scale),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'No. Reg: ${item.noRegister.isNotEmpty ? item.noRegister : '-'}',
                                          style: TextStyle(
                                            fontSize: 11 * scale,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF1A1A1A),
                                            height: 1.4,
                                          ),
                                        ),
                                        SizedBox(height: 5 * scale),
                                        _buildKondisiChip(item.kondisiAset, scale),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 8 * scale),
                                  // Photo box
                                  Container(
                                    width: 80 * scale,
                                    height: 70 * scale,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color(0xFFFFD5C8),
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(5),
                                      child: item.fotoUrl.isEmpty
                                          ? _buildPlaceholder(80 * scale, 70 * scale)
                                          : _buildImage(
                                              item.fotoUrl,
                                              width: 80 * scale,
                                              height: 70 * scale,
                                              fit: BoxFit.cover,
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
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImage(String path, {required double width, required double height, BoxFit fit = BoxFit.contain}) {
    if (path.isEmpty) {
      return _buildPlaceholder(width, height);
    }
    if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('blob:') || path.startsWith('data:')) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(width, height),
      );
    } else if (!kIsWeb && File(path).existsSync()) {
      return Image.file(
        File(path),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(width, height),
      );
    } else {
      return Image.asset(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(width, height),
      );
    }
  }

  Widget _buildPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFFFF0EA),
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      child: Image.asset(
        'assets/logo_sulsel_original.png',
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildKondisiChip(String kondisi, double scale) {
    Color bg;
    Color fg;
    Color border;
    IconData icon;

    switch (kondisi.trim().toLowerCase()) {
      case 'kurang baik':
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        border = const Color(0xFFFFB74D);
        icon = Icons.warning_amber_rounded;
        break;
      case 'rusak':
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        border = const Color(0xFFEF9A9A);
        icon = Icons.cancel_outlined;
        break;
      case 'baik':
      default:
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        border = const Color(0xFFA5D6A7);
        icon = Icons.check_circle_outline;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 3 * scale),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11 * scale, color: fg),
          SizedBox(width: 4 * scale),
          Text(
            kondisi.isNotEmpty ? kondisi : 'Baik',
            style: TextStyle(
              fontSize: 10 * scale,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Clipper for the star background decoration
class StarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width * 0.5, 0);
    path.lineTo(size.width * 0.61, size.height * 0.35);
    path.lineTo(size.width * 0.98, size.height * 0.35);
    path.lineTo(size.width * 0.68, size.height * 0.57);
    path.lineTo(size.width * 0.79, size.height * 0.91);
    path.lineTo(size.width * 0.5, size.height * 0.7);
    path.lineTo(size.width * 0.21, size.height * 0.91);
    path.lineTo(size.width * 0.32, size.height * 0.57);
    path.lineTo(size.width * 0.02, size.height * 0.35);
    path.lineTo(size.width * 0.39, size.height * 0.35);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
