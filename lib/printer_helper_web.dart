// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:barcode/barcode.dart';
import 'package:flutter/services.dart';
import 'package:qr/qr.dart';
import 'models.dart';

Future<void> printItemLabelImpl(Item item, Room room) async {
  final qrUrl =
      'https://gensetarch.github.io/webdp3a/?item=${item.id}';
  final logoBase64 = await _loadLogoBase64();
  final qrSvg = _generateQrSvg(qrUrl, logoBase64);

  final htmlContent = '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Label - ${item.jenisBarang}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }

    @page {
      size: 9cm 12cm;
      margin: 0;
    }

    @media print {
      html, body {
        width: 9cm;
        height: 12cm;
        -webkit-print-color-adjust: exact !important;
        print-color-adjust: exact !important;
      }
      .card {
        box-shadow: none !important;
        border-radius: 0 !important;
        -webkit-print-color-adjust: exact !important;
        print-color-adjust: exact !important;
      }
      .print-btn { display: none !important; }
    }

    body {
      font-family: 'Arial Black', Arial, sans-serif;
      background: #e0e0e0;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
    }

    .card {
      width: 9cm;
      height: 12cm;
      background: linear-gradient(160deg, #1565C0 0%, #1976D2 40%, #2196F3 100%);
      border-radius: 16px;
      box-shadow: 0 8px 32px rgba(0,0,0,0.4);
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: space-between;
      overflow: hidden;
      position: relative;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }

    /* Zigzag top decoration */
    .zigzag-top {
      width: 100%;
      height: 28px;
      flex-shrink: 0;
    }

    /* Zigzag bottom decoration */
    .zigzag-bottom {
      width: 100%;
      height: 28px;
      flex-shrink: 0;
    }

    .title {
      color: #FFFFFF;
      font-size: 22pt;
      font-weight: 900;
      letter-spacing: 3px;
      text-shadow: 0 2px 6px rgba(0,0,0,0.3);
      margin-top: -4px;
      text-align: center;
    }

    .qr-wrapper {
      background: white;
      border-radius: 12px;
      padding: 10px;
      box-shadow: 0 4px 16px rgba(0,0,0,0.25);
      width: 5.5cm;
      height: 5.5cm;
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .qr-wrapper svg {
      width: 100% !important;
      height: 100% !important;
    }

    .info-box {
      background: rgba(255,255,255,0.92);
      border-radius: 8px;
      padding: 6px 16px;
      text-align: center;
      width: 85%;
    }

    .info-name {
      font-size: 10pt;
      font-weight: 900;
      color: #1565C0;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      line-height: 1.3;
    }

    .info-code {
      font-size: 8pt;
      font-weight: 700;
      color: #333;
      font-family: 'Courier New', monospace;
      margin-top: 2px;
    }

    .footer-bar {
      background: rgba(255,255,255,0.18);
      width: 75%;
      border-radius: 20px;
      padding: 4px 12px;
      margin-bottom: 2px;
    }

    .footer-text {
      font-size: 8.5pt;
      font-weight: 900;
      color: #FFFFFF;
      text-align: center;
      letter-spacing: 1px;
      text-transform: uppercase;
    }

    .print-btn {
      position: fixed;
      bottom: 20px;
      right: 20px;
      background: #1565C0;
      color: white;
      border: none;
      border-radius: 8px;
      padding: 10px 22px;
      font-size: 13pt;
      font-weight: bold;
      cursor: pointer;
      box-shadow: 0 4px 12px rgba(0,0,0,0.3);
    }
    .print-btn:hover { background: #0D47A1; }
  </style>
</head>
<body>
  <div class="card">
    <!-- Zigzag Top -->
    <svg class="zigzag-top" viewBox="0 0 360 28" preserveAspectRatio="none" xmlns="http://www.w3.org/2000/svg">
      <polygon points="0,0 360,0 360,28 330,10 300,28 270,10 240,28 210,10 180,28 150,10 120,28 90,10 60,28 30,10 0,28" fill="rgba(255,255,255,0.15)"/>
      <polygon points="0,0 360,0 360,20 345,6 315,22 285,6 255,22 225,6 195,22 165,6 135,22 105,6 75,22 45,6 15,22 0,8" fill="rgba(255,255,255,0.10)"/>
    </svg>

    <div class="title">SCAN BANDA</div>

    <div class="qr-wrapper">
      $qrSvg
    </div>

    <div class="info-box">
      <div class="info-name">${item.jenisBarang}</div>
      <div class="info-code">${item.kodeBarang}</div>
    </div>

    <div class="footer-bar">
      <div class="footer-text">DP3A DALDUK KB</div>
    </div>

    <!-- Zigzag Bottom -->
    <svg class="zigzag-bottom" viewBox="0 0 360 28" preserveAspectRatio="none" xmlns="http://www.w3.org/2000/svg">
      <polygon points="0,28 360,28 360,0 330,18 300,0 270,18 240,0 210,18 180,0 150,18 120,0 90,18 60,0 30,18 0,0" fill="rgba(255,255,255,0.15)"/>
      <polygon points="0,28 360,28 360,8 345,22 315,6 285,22 255,6 225,22 195,6 165,22 135,6 105,22 75,6 45,22 15,6 0,20" fill="rgba(255,255,255,0.10)"/>
    </svg>
  </div>

  <button class="print-btn" onclick="window.print(); setTimeout(()=>window.close(),800);">🖨️ Cetak</button>
  <script>
    // Load logo and overlay it on the QR code center
    fetch('https://gensetarch.github.io/webdp3a/assets/assets/logo_sulsel.png')
      .then(r => r.blob())
      .then(blob => {
        const reader = new FileReader();
        reader.onload = function(e) {
          const logoPlaceholder = document.getElementById('qr-logo-overlay');
          if (logoPlaceholder) {
            const img = document.createElementNS('http://www.w3.org/2000/svg','image');
            const svgEl = logoPlaceholder.closest('svg');
            if (svgEl) {
              const vb = svgEl.viewBox.baseVal;
              const logoSize = vb.width * 0.28;
              const logoOffset = (vb.width - logoSize) / 2;
              img.setAttributeNS('http://www.w3.org/1999/xlink','href', e.target.result);
              img.setAttribute('x', logoOffset + 2);
              img.setAttribute('y', logoOffset + 2);
              img.setAttribute('width', logoSize - 4);
              img.setAttribute('height', logoSize - 4);
              svgEl.appendChild(img);
            }
          }
        };
        reader.readAsDataURL(blob);
      }).catch(() => {});
  </script>
</body>
</html>''';

  final blob = html.Blob([htmlContent], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, 'label-${item.id}', 'width=400,height=560');
  Future.delayed(
      const Duration(seconds: 60), () => html.Url.revokeObjectUrl(url));
}

Future<void> printRoomLabelImpl(Room room) async {
  final qrUrl =
      'https://gensetarch.github.io/webdp3a/?room=${room.id}';
  final logoBase64 = await _loadLogoBase64();
  final qrSvg = _generateQrSvg(qrUrl, logoBase64);

  final htmlContent = '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Label Ruangan - ${room.name}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }

    @page {
      size: 9cm 12cm;
      margin: 0;
    }

    @media print {
      html, body {
        width: 9cm;
        height: 12cm;
        -webkit-print-color-adjust: exact !important;
        print-color-adjust: exact !important;
      }
      .card {
        box-shadow: none !important;
        border-radius: 0 !important;
        -webkit-print-color-adjust: exact !important;
        print-color-adjust: exact !important;
      }
      .print-btn { display: none !important; }
    }

    body {
      font-family: 'Arial Black', Arial, sans-serif;
      background: #e0e0e0;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
    }

    .card {
      width: 9cm;
      height: 12cm;
      background: linear-gradient(160deg, #1565C0 0%, #1976D2 40%, #2196F3 100%);
      border-radius: 16px;
      box-shadow: 0 8px 32px rgba(0,0,0,0.4);
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: space-between;
      overflow: hidden;
      position: relative;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }

    .zigzag-top { width: 100%; height: 28px; flex-shrink: 0; }
    .zigzag-bottom { width: 100%; height: 28px; flex-shrink: 0; }

    .title {
      color: #FFFFFF;
      font-size: 22pt;
      font-weight: 900;
      letter-spacing: 3px;
      text-shadow: 0 2px 6px rgba(0,0,0,0.3);
      margin-top: -4px;
      text-align: center;
    }

    .qr-wrapper {
      background: white;
      border-radius: 12px;
      padding: 10px;
      box-shadow: 0 4px 16px rgba(0,0,0,0.25);
      width: 5.5cm;
      height: 5.5cm;
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .qr-wrapper svg { width: 100% !important; height: 100% !important; }

    .info-box {
      background: rgba(255,255,255,0.92);
      border-radius: 8px;
      padding: 6px 16px;
      text-align: center;
      width: 85%;
    }

    .info-name {
      font-size: 10pt;
      font-weight: 900;
      color: #1565C0;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      line-height: 1.3;
    }

    .info-code {
      font-size: 8pt;
      font-weight: 700;
      color: #333;
      font-family: 'Courier New', monospace;
      margin-top: 2px;
    }

    .footer-bar {
      background: rgba(255,255,255,0.18);
      width: 75%;
      border-radius: 20px;
      padding: 4px 12px;
      margin-bottom: 2px;
    }

    .footer-text {
      font-size: 8.5pt;
      font-weight: 900;
      color: #FFFFFF;
      text-align: center;
      letter-spacing: 1px;
      text-transform: uppercase;
    }

    .print-btn {
      position: fixed;
      bottom: 20px;
      right: 20px;
      background: #1565C0;
      color: white;
      border: none;
      border-radius: 8px;
      padding: 10px 22px;
      font-size: 13pt;
      font-weight: bold;
      cursor: pointer;
      box-shadow: 0 4px 12px rgba(0,0,0,0.3);
    }
    .print-btn:hover { background: #0D47A1; }
  </style>
</head>
<body>
  <div class="card">
    <svg class="zigzag-top" viewBox="0 0 360 28" preserveAspectRatio="none" xmlns="http://www.w3.org/2000/svg">
      <polygon points="0,0 360,0 360,28 330,10 300,28 270,10 240,28 210,10 180,28 150,10 120,28 90,10 60,28 30,10 0,28" fill="rgba(255,255,255,0.15)"/>
      <polygon points="0,0 360,0 360,20 345,6 315,22 285,6 255,22 225,6 195,22 165,6 135,22 105,6 75,22 45,6 15,22 0,8" fill="rgba(255,255,255,0.10)"/>
    </svg>

    <div class="title">SCAN BANDA</div>

    <div class="qr-wrapper">
      $qrSvg
    </div>

    <div class="info-box">
      <div class="info-name">${room.name}</div>
      <div class="info-code">${room.year} — ${room.barcode.replaceFirst('RM-', '')}</div>
    </div>

    <div class="footer-bar">
      <div class="footer-text">DP3A DALDUK KB</div>
    </div>

    <svg class="zigzag-bottom" viewBox="0 0 360 28" preserveAspectRatio="none" xmlns="http://www.w3.org/2000/svg">
      <polygon points="0,28 360,28 360,0 330,18 300,0 270,18 240,0 210,18 180,0 150,18 120,0 90,18 60,0 30,18 0,0" fill="rgba(255,255,255,0.15)"/>
      <polygon points="0,28 360,28 360,8 345,22 315,6 285,22 255,6 225,22 195,6 165,22 135,6 105,22 75,6 45,22 15,6 0,20" fill="rgba(255,255,255,0.10)"/>
    </svg>
  </div>

  <button class="print-btn" onclick="window.print(); setTimeout(()=>window.close(),800);">🖨️ Cetak</button>
  <script>
    // Load logo and overlay it on the QR code center
    fetch('https://gensetarch.github.io/webdp3a/assets/assets/logo_sulsel.png')
      .then(r => r.blob())
      .then(blob => {
        const reader = new FileReader();
        reader.onload = function(e) {
          const logoPlaceholder = document.getElementById('qr-logo-overlay');
          if (logoPlaceholder) {
            const img = document.createElementNS('http://www.w3.org/2000/svg','image');
            const svgEl = logoPlaceholder.closest('svg');
            if (svgEl) {
              const vb = svgEl.viewBox.baseVal;
              const logoSize = vb.width * 0.28;
              const logoOffset = (vb.width - logoSize) / 2;
              img.setAttributeNS('http://www.w3.org/1999/xlink','href', e.target.result);
              img.setAttribute('x', logoOffset + 2);
              img.setAttribute('y', logoOffset + 2);
              img.setAttribute('width', logoSize - 4);
              img.setAttribute('height', logoSize - 4);
              svgEl.appendChild(img);
            }
          }
        };
        reader.readAsDataURL(blob);
      }).catch(() => {});
  </script>
</body>
</html>''';

  final blob = html.Blob([htmlContent], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, 'label-ruang-${room.id}', 'width=400,height=560');
  Future.delayed(
      const Duration(seconds: 60), () => html.Url.revokeObjectUrl(url));
}

String _generateBarcodeSvg(String data) {
  try {
    final bc = Barcode.code128();
    return bc.toSvg(data, width: 220, height: 50, drawText: false);
  } catch (e) {
    return '<svg width="220" height="50"><text x="10" y="25">Error Barcode</text></svg>';
  }
}

Future<String> _loadLogoBase64() async {
  return ''; // Placeholder - logo is now loaded via JS in print HTML
}

String _generateQrSvg(String data, String logoBase64) {
  try {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.H,
    );
    final qrImage = QrImage(qrCode);

    final moduleCount = qrImage.moduleCount;
    final size = 150.0;
    final dotSize = size / moduleCount;

    final sb = StringBuffer();
    sb.write(
        '<svg width="100%" height="100%" viewBox="0 0 $size $size" fill="none" xmlns="http://www.w3.org/2000/svg">');
    sb.write('<rect width="$size" height="$size" fill="white"/>');

    for (int x = 0; x < moduleCount; x++) {
      for (int y = 0; y < moduleCount; y++) {
        if (qrImage.isDark(y, x)) {
          final px = x * dotSize;
          final py = y * dotSize;
          sb.write(
              '<rect x="$px" y="$py" width="$dotSize" height="$dotSize" fill="#1565C0"/>');
        }
      }
    }

    // White background box for logo center - logo inserted via JS
    final logoSize = size * 0.28;
    final logoOffset = (size - logoSize) / 2;
    sb.write(
        '<rect id="qr-logo-overlay" x="$logoOffset" y="$logoOffset" width="$logoSize" height="$logoSize" fill="white" rx="4" ry="4"/>');

    sb.write('</svg>');
    return sb.toString();
  } catch (e) {
    return '<svg width="75" height="75"><text x="5" y="40">Error QR</text></svg>';
  }
}
