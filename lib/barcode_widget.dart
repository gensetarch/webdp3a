import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart' as pkg_barcode;
import 'package:qr_flutter/qr_flutter.dart';

class BarcodeWidget extends StatelessWidget {
  final String data;
  final double width;
  final double height;
  final Color barColor;
  final Color backgroundColor;
  final bool showText;

  const BarcodeWidget({
    Key? key,
    required this.data,
    this.width = 200,
    this.height = 70,
    this.barColor = Colors.black,
    this.backgroundColor = Colors.white,
    this.showText = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: pkg_barcode.BarcodeWidget(
        barcode: pkg_barcode.Barcode.code128(), // Code 128 is highly recognizable by Google Lens & scanners
        data: data,
        color: barColor,
        backgroundColor: backgroundColor,
        drawText: showText,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Colors.black87,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class QRCodeWidget extends StatelessWidget {
  final String data;
  final double size;
  final Color qrColor;
  final Color backgroundColor;

  const QRCodeWidget({
    Key? key,
    required this.data,
    this.size = 100,
    this.qrColor = Colors.black,
    this.backgroundColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: data,
      size: size,
      eyeStyle: QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: qrColor,
      ),
      dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: qrColor,
      ),
      backgroundColor: backgroundColor,
      padding: EdgeInsets.all(size * 0.06),
      errorCorrectionLevel: QrErrorCorrectLevel.H, // High error correction level needed when using a logo
      embeddedImage: const AssetImage('assets/logo_sulsel.png'),
      embeddedImageStyle: QrEmbeddedImageStyle(
        size: Size(size * 0.25, size * 0.25),
      ),
    );
  }
}
