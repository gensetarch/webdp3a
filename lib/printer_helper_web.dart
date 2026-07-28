// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'package:barcode/barcode.dart';
import 'package:qr/qr.dart';
import 'models.dart';


Future<void> printItemLabelImpl(Item item, Room room) async {
  final qrUrl = 'https://gensetarch.github.io/webdp3a/?item=${item.id}';
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
      size: 5cm 7cm;
      margin: 0;
    }

    @media print {
      html, body {
        width: 5cm;
        height: 7cm;
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
      width: 5cm;
      height: 7cm;
      background: linear-gradient(160deg, #1565C0 0%, #1976D2 40%, #2196F3 100%);
      border-radius: 10px;
      box-shadow: 0 4px 16px rgba(0,0,0,0.4);
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
      height: 18px;
      flex-shrink: 0;
    }

    /* Zigzag bottom decoration */
    .zigzag-bottom {
      width: 100%;
      height: 18px;
      flex-shrink: 0;
    }

    .corner-logo {
      position: absolute;
      top: 4px;
      left: 6px;
      width: 0.42cm;
      height: 0.42cm;
      object-fit: contain;
      z-index: 10;
      filter: drop-shadow(0 1px 2px rgba(0,0,0,0.3));
    }

    .title {
      color: #FFFFFF;
      font-size: 14pt;
      font-weight: 900;
      letter-spacing: 2px;
      text-shadow: 0 2px 6px rgba(0,0,0,0.3);
      margin-top: -4px;
      text-align: center;
      width: 100%;
    }

    .qr-wrapper {
      background: white;
      border-radius: 8px;
      padding: 7px;
      box-shadow: 0 3px 12px rgba(0,0,0,0.25);
      width: 3.6cm;
      height: 3.6cm;
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
      border-radius: 4px;
      padding: 3px 6px;
      text-align: center;
      width: 90%;
    }

    .info-name {
      font-size: 9pt;
      font-weight: 900;
      color: #1565C0;
      text-transform: uppercase;
      letter-spacing: 0.3px;
      line-height: 1.3;
    }

    .info-code {
      font-size: 7pt;
      font-weight: 700;
      color: #333;
      margin-top: 2px;
      text-transform: uppercase;
    }

    .footer-bar {
      background: rgba(255,255,255,0.18);
      width: 80%;
      border-radius: 12px;
      padding: 3px 10px;
      margin-bottom: 3px;
    }

    .footer-text {
      font-size: 7.5pt;
      font-weight: 900;
      color: #FFFFFF;
      text-align: center;
      letter-spacing: 0.5px;
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
    <!-- Logo Sulsel pojok kiri (dalam area zigzag, tidak overlap title) -->
    <img id="corner-logo-img" class="corner-logo" alt="Logo Sulsel" />

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
      <div class="info-name">${room.name}</div>
      <div class="info-code">${item.jenisBarang}${item.merekModel.isNotEmpty ? ' — ${item.merekModel}' : ''}</div>
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
    const baseUrl = 'https://gensetarch.github.io/webdp3a/assets/assets';

    // Load logo_sulsel_transparent into corner logo (bypass cache)
    fetch(baseUrl + '/logo_sulsel_transparent.png?t=' + new Date().getTime())
      .then(r => r.blob())
      .then(blob => {
        const reader = new FileReader();
        reader.onload = function(e) {
          const cornerImg = document.getElementById('corner-logo-img');
          if (cornerImg) cornerImg.src = e.target.result;
        };
        reader.readAsDataURL(blob);
      }).catch(() => {});

    // Load original logo_sulsel into QR center (bypass cache)
    fetch(baseUrl + '/logo_sulsel_original.png?t=' + new Date().getTime())
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
  html.window.open(url, 'label-${item.id}', 'width=360,height=510');
  Future.delayed(
      const Duration(seconds: 60), () => html.Url.revokeObjectUrl(url));
}

Future<void> printRoomLabelImpl(Room room) async {
  final qrUrl = 'https://gensetarch.github.io/webdp3a/?room=${room.id}';
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
      size: 9cm 13cm;
      margin: 0;
    }

    @media print {
      html, body {
        width: 9cm;
        height: 13cm;
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
      height: 13cm;
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

    .corner-logo {
      position: absolute;
      top: 32px;
      left: 10px;
      width: 0.85cm;
      height: 0.85cm;
      object-fit: contain;
      z-index: 10;
      filter: drop-shadow(0 1px 3px rgba(0,0,0,0.3));
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
    <!-- Logo Sulsel top-left corner -->
    <img id="corner-logo-img" class="corner-logo" alt="Logo Sulsel" />

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
      <div class="info-code">${room.year} — ${room.barcode.replaceFirst('RM-', '').replaceFirst('-${room.year}', '').replaceAll('-', ' ')}</div>
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
    const baseUrl = 'https://gensetarch.github.io/webdp3a/assets/assets';

    // Load logo_sulsel_transparent into corner logo (bypass cache)
    fetch(baseUrl + '/logo_sulsel_transparent.png?t=' + new Date().getTime())
      .then(r => r.blob())
      .then(blob => {
        const reader = new FileReader();
        reader.onload = function(e) {
          const cornerImg = document.getElementById('corner-logo-img');
          if (cornerImg) cornerImg.src = e.target.result;
        };
        reader.readAsDataURL(blob);
      }).catch(() => {});

    // Load original logo_sulsel into QR center (bypass cache)
    fetch(baseUrl + '/logo_sulsel_original.png?t=' + new Date().getTime())
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
  html.window.open(url, 'label-ruang-${room.id}', 'width=420,height=600');
  Future.delayed(
      const Duration(seconds: 60), () => html.Url.revokeObjectUrl(url));
}

Future<void> printAgencyLabelImpl(Agency agency) async {
  final qrUrl = 'https://gensetarch.github.io/webdp3a/?agency=${agency.id}';
  final logoBase64 = await _loadLogoBase64();
  final qrSvg = _generateQrSvg(qrUrl, logoBase64);

  final htmlContent = '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Label Instansi - ${agency.name}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }

    @page {
      size: 9cm 13cm;
      margin: 0;
    }

    @media print {
      html, body {
        width: 9cm;
        height: 13cm;
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
      height: 13cm;
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
      font-size: 11pt;
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

    .corner-logo {
      position: absolute;
      top: 32px;
      left: 10px;
      width: 0.85cm;
      height: 0.85cm;
      object-fit: contain;
      z-index: 10;
      filter: drop-shadow(0 1px 3px rgba(0,0,0,0.3));
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
    <img id="corner-logo-img" class="corner-logo" alt="Logo Sulsel" />

    <svg class="zigzag-top" viewBox="0 0 360 28" preserveAspectRatio="none" xmlns="http://www.w3.org/2000/svg">
      <polygon points="0,0 360,0 360,28 330,10 300,28 270,10 240,28 210,10 180,28 150,10 120,28 90,10 60,28 30,10 0,28" fill="rgba(255,255,255,0.15)"/>
      <polygon points="0,0 360,0 360,20 345,6 315,22 285,6 255,22 225,6 195,22 165,6 135,22 105,6 75,22 45,6 15,22 0,8" fill="rgba(255,255,255,0.10)"/>
    </svg>

    <div class="title">SCAN BANDA</div>

    <div class="qr-wrapper">
      $qrSvg
    </div>

    <div class="info-box">
      <div class="info-name">${agency.name}</div>
      <div class="info-code">${agency.barcode}</div>
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
    const baseUrl = 'https://gensetarch.github.io/webdp3a/assets/assets';

    fetch(baseUrl + '/logo_sulsel_transparent.png?t=' + new Date().getTime())
      .then(r => r.blob())
      .then(blob => {
        const reader = new FileReader();
        reader.onload = function(e) {
          const cornerImg = document.getElementById('corner-logo-img');
          if (cornerImg) cornerImg.src = e.target.result;
        };
        reader.readAsDataURL(blob);
      }).catch(() => {});

    fetch(baseUrl + '/logo_sulsel_original.png?t=' + new Date().getTime())
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
  html.window.open(url, 'label-instansi-${agency.id}', 'width=420,height=600');
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
        '<rect class="qr-logo-overlay" id="qr-logo-overlay" x="$logoOffset" y="$logoOffset" width="$logoSize" height="$logoSize" fill="white" rx="4" ry="4"/>');

    sb.write('</svg>');
    return sb.toString();
  } catch (e) {
    return '<svg width="75" height="75"><text x="5" y="40">Error QR</text></svg>';
  }
}

Future<void> printMultipleItemsLabelImpl(List<Item> items, Room room) async {
  if (items.isEmpty) return;

  final logoBase64 = await _loadLogoBase64();

  final sb = StringBuffer();
  sb.write('''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Label Barcode Barang - ${room.name}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }

    @page {
      size: A4 portrait;
      margin: 0.8cm 0.6cm;
    }

    @media print {
      body {
        background: white !important;
        padding: 0 !important;
      }
      .print-btn { display: none !important; }
      .card {
        box-shadow: none !important;
        -webkit-print-color-adjust: exact !important;
        print-color-adjust: exact !important;
      }
    }

    body {
      font-family: 'Arial Black', Arial, sans-serif;
      background: #e0e0e0;
      padding: 16px;
      min-height: 100vh;
    }

    .grid-container {
      display: grid;
      grid-template-columns: repeat(4, 4.5cm);
      gap: 0.4cm;
      justify-content: center;
      margin: 0 auto;
    }

    .card {
      width: 4.5cm;
      height: 6.5cm;
      background: linear-gradient(160deg, #1565C0 0%, #1976D2 40%, #2196F3 100%);
      border-radius: 8px;
      box-shadow: 0 3px 10px rgba(0,0,0,0.25);
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: space-between;
      overflow: hidden;
      position: relative;
      page-break-inside: avoid;
      break-inside: avoid;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }

    .zigzag-top {
      width: 100%;
      height: 16px;
      flex-shrink: 0;
    }

    .zigzag-bottom {
      width: 100%;
      height: 16px;
      flex-shrink: 0;
    }

    .corner-logo {
      position: absolute;
      top: 3px;
      left: 5px;
      width: 0.38cm;
      height: 0.38cm;
      object-fit: contain;
      z-index: 10;
      filter: drop-shadow(0 1px 2px rgba(0,0,0,0.3));
    }

    .title {
      color: #FFFFFF;
      font-size: 11pt;
      font-weight: 900;
      letter-spacing: 1.5px;
      text-shadow: 0 1px 4px rgba(0,0,0,0.3);
      margin-top: -4px;
      text-align: center;
      width: 100%;
    }

    .qr-wrapper {
      background: white;
      border-radius: 6px;
      padding: 5px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.2);
      width: 3.2cm;
      height: 3.2cm;
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
      border-radius: 4px;
      padding: 3px 5px;
      text-align: center;
      width: 90%;
    }

    .info-name {
      font-size: 8pt;
      font-weight: 900;
      color: #1565C0;
      text-transform: uppercase;
      letter-spacing: 0.3px;
      line-height: 1.2;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .info-code {
      font-size: 6.5pt;
      font-weight: 700;
      color: #333;
      margin-top: 1px;
      text-transform: uppercase;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .footer-bar {
      background: rgba(255,255,255,0.18);
      width: 82%;
      border-radius: 10px;
      padding: 2px 6px;
      margin-bottom: 2px;
    }

    .footer-text {
      font-size: 6.5pt;
      font-weight: 900;
      color: #FFFFFF;
      text-align: center;
      letter-spacing: 0.5px;
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
      z-index: 1000;
    }
    .print-btn:hover { background: #0D47A1; }
  </style>
</head>
<body>
  <div class="grid-container">
''');

  for (final item in items) {
    final qrUrl = 'https://gensetarch.github.io/webdp3a/?item=${item.id}';
    final qrSvg = _generateQrSvg(qrUrl, logoBase64);
    final itemSubtext = item.merekModel.isNotEmpty
        ? '${item.jenisBarang} — ${item.merekModel}'
        : item.jenisBarang;

    sb.write('''
    <div class="card">
      <img class="corner-logo corner-logo-item" alt="Logo Sulsel" />

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
        <div class="info-code">$itemSubtext</div>
      </div>

      <div class="footer-bar">
        <div class="footer-text">DP3A DALDUK KB</div>
      </div>

      <svg class="zigzag-bottom" viewBox="0 0 360 28" preserveAspectRatio="none" xmlns="http://www.w3.org/2000/svg">
        <polygon points="0,28 360,28 360,0 330,18 300,0 270,18 240,0 210,18 180,0 150,18 120,0 90,18 60,0 30,18 0,0" fill="rgba(255,255,255,0.15)"/>
        <polygon points="0,28 360,28 360,8 345,22 315,6 285,22 255,6 225,22 195,6 165,22 135,6 105,22 75,6 45,22 15,6 0,20" fill="rgba(255,255,255,0.10)"/>
      </svg>
    </div>
''');
  }

  sb.write('''
  </div>

  <button class="print-btn" onclick="window.print(); setTimeout(()=>window.close(),800);">🖨️ Cetak (${items.length} Label)</button>
  <script>
    const baseUrl = 'https://gensetarch.github.io/webdp3a/assets/assets';

    fetch(baseUrl + '/logo_sulsel_transparent.png?t=' + new Date().getTime())
      .then(r => r.blob())
      .then(blob => {
        const reader = new FileReader();
        reader.onload = function(e) {
          document.querySelectorAll('.corner-logo-item').forEach(img => {
            img.src = e.target.result;
          });
        };
        reader.readAsDataURL(blob);
      }).catch(() => {});

    fetch(baseUrl + '/logo_sulsel_original.png?t=' + new Date().getTime())
      .then(r => r.blob())
      .then(blob => {
        const reader = new FileReader();
        reader.onload = function(e) {
          document.querySelectorAll('.qr-logo-overlay').forEach(logoPlaceholder => {
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
          });
        };
        reader.readAsDataURL(blob);
      }).catch(() => {});
  </script>
</body>
</html>''');

  final blob = html.Blob([sb.toString()], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, 'multi-labels-${room.id}', 'width=900,height=700');
  Future.delayed(
      const Duration(seconds: 60), () => html.Url.revokeObjectUrl(url));
}

