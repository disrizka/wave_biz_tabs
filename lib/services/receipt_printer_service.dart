import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wave_biz_tabs/models/receipt_model.dart';

/// Pengaturan printer yang disimpan permanen di perangkat.
class PrinterConfig {
  final String mac;
  final String name;
  final bool is58mm;
  final bool autoPrint;

  const PrinterConfig({
    this.mac = '',
    this.name = '',
    this.is58mm = true,
    this.autoPrint = true,
  });

  bool get hasPrinter => mac.isNotEmpty;

  PrinterConfig copyWith({
    String? mac,
    String? name,
    bool? is58mm,
    bool? autoPrint,
  }) {
    return PrinterConfig(
      mac: mac ?? this.mac,
      name: name ?? this.name,
      is58mm: is58mm ?? this.is58mm,
      autoPrint: autoPrint ?? this.autoPrint,
    );
  }
}

class PrintResult {
  final bool ok;
  final String message;
  const PrintResult(this.ok, this.message);
}

/// Cetak struk ke printer thermal Bluetooth (58mm / 80mm, ESC/POS).
///
/// Printer harus sudah di-pair dulu lewat Pengaturan Bluetooth Android,
/// lalu dipilih di layar "Printer Struk".
class ReceiptPrinterService {
  ReceiptPrinterService._();
  static final ReceiptPrinterService instance = ReceiptPrinterService._();

  static const _kMac = 'receipt_printer.mac';
  static const _kName = 'receipt_printer.name';
  static const _kIs58 = 'receipt_printer.is58mm';
  static const _kAuto = 'receipt_printer.auto_print';

  // ---------------------------------------------------------------- config

  Future<PrinterConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return PrinterConfig(
      mac: prefs.getString(_kMac) ?? '',
      name: prefs.getString(_kName) ?? '',
      is58mm: prefs.getBool(_kIs58) ?? true,
      autoPrint: prefs.getBool(_kAuto) ?? true,
    );
  }

  Future<void> saveConfig(PrinterConfig c) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMac, c.mac);
    await prefs.setString(_kName, c.name);
    await prefs.setBool(_kIs58, c.is58mm);
    await prefs.setBool(_kAuto, c.autoPrint);
  }

  // ------------------------------------------------------------ bluetooth

  Future<bool> ensurePermissions() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.bluetoothConnect.request();
    if (status.isGranted) return true;
    // Android < 12 tidak butuh izin runtime.
    return PrintBluetoothThermal.isPermissionBluetoothGranted;
  }

  Future<bool> isBluetoothOn() => PrintBluetoothThermal.bluetoothEnabled;

  Future<List<BluetoothInfo>> pairedPrinters() =>
      PrintBluetoothThermal.pairedBluetooths;

  Future<bool> _ensureConnected(String mac) async {
    if (await PrintBluetoothThermal.connectionStatus) return true;
    if (await PrintBluetoothThermal.connect(macPrinterAddress: mac)) {
      return true;
    }
    // Coba sekali lagi dari kondisi bersih.
    await PrintBluetoothThermal.disconnect;
    await Future.delayed(const Duration(milliseconds: 400));
    return PrintBluetoothThermal.connect(macPrinterAddress: mac);
  }

  Future<bool> _write(List<int> bytes) async {
    const chunk = 512;
    for (var i = 0; i < bytes.length; i += chunk) {
      final end = math.min(i + chunk, bytes.length);
      final ok = await PrintBluetoothThermal.writeBytes(bytes.sublist(i, end));
      if (!ok) return false;
      await Future.delayed(const Duration(milliseconds: 40));
    }
    return true;
  }

  Future<PrintResult> _send(List<int> Function(PrinterConfig) build) async {
    try {
      final config = await loadConfig();
      if (!config.hasPrinter) {
        return const PrintResult(
          false,
          'Printer belum dipilih. Atur di Profil > Printer Struk.',
        );
      }
      if (!await ensurePermissions()) {
        return const PrintResult(
          false,
          'Izin Bluetooth ditolak. Aktifkan di pengaturan aplikasi.',
        );
      }
      if (!await isBluetoothOn()) {
        return const PrintResult(false, 'Bluetooth belum menyala.');
      }
      if (!await _ensureConnected(config.mac)) {
        return PrintResult(
          false,
          'Tidak bisa terhubung ke ${config.name.isEmpty ? 'printer' : config.name}. '
          'Pastikan printer menyala dan berada di dekat perangkat.',
        );
      }
      if (!await _write(build(config))) {
        return const PrintResult(false, 'Gagal mengirim data ke printer.');
      }
      return const PrintResult(true, 'Struk berhasil dicetak.');
    } catch (e) {
      debugPrint('[ReceiptPrinter] error: $e');
      return PrintResult(false, 'Gagal mencetak: $e');
    }
  }

  // ---------------------------------------------------------------- public

  Future<PrintResult> printReceipt(ReceiptData receipt) =>
      _send((c) => buildReceiptBytes(receipt, is58mm: c.is58mm));

  Future<PrintResult> printTest() => _send(
    (c) => buildReceiptBytes(
      ReceiptData(
        businessName: 'TES PRINTER',
        cashierName: 'Kasir',
        reference: 'REF-TEST',
        dateTime: DateTime.now(),
        orderTypeLabel: 'Dine In',
        paymentMethodLabel: 'Tunai',
        items: const [
          ReceiptItem(name: 'Produk Contoh A', quantity: 2, unitPrice: 15000),
          ReceiptItem(
            name: 'Produk Contoh B dengan nama yang panjang sekali',
            variantLabel: 'Large',
            quantity: 1,
            unitPrice: 20500,
          ),
        ],
        total: 50500,
      ),
      is58mm: c.is58mm,
    ),
  );

  Future<void> disconnect() async {
    await PrintBluetoothThermal.disconnect;
  }

  // ------------------------------------------------------------ ESC/POS

  static String _num(int v) {
    final s = v.abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      b.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) b.write('.');
    }
    return '${v < 0 ? '-' : ''}$b';
  }

  /// Printer thermal umumnya hanya paham ASCII -> karakter lain jadi '?'.
  static String _ascii(String s) {
    final b = StringBuffer();
    for (final c in s.runes) {
      b.write(c >= 32 && c < 127 ? String.fromCharCode(c) : '?');
    }
    return b.toString();
  }

  static List<String> _wrap(String text, int width) {
    final words = _ascii(text).split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final lines = <String>[];
    var cur = '';
    for (var w in words) {
      while (w.length > width) {
        if (cur.isNotEmpty) {
          lines.add(cur);
          cur = '';
        }
        lines.add(w.substring(0, width));
        w = w.substring(width);
      }
      if (cur.isEmpty) {
        cur = w;
      } else if (cur.length + 1 + w.length <= width) {
        cur = '$cur $w';
      } else {
        lines.add(cur);
        cur = w;
      }
    }
    if (cur.isNotEmpty) lines.add(cur);
    return lines.isEmpty ? [''] : lines;
  }

  static String _lr(String left, String right, int width) {
    var l = _ascii(left);
    final r = _ascii(right);
    final maxLeft = width - r.length - 1;
    if (l.length > maxLeft) l = l.substring(0, math.max(0, maxLeft));
    final gap = math.max(1, width - l.length - r.length);
    return '$l${' ' * gap}$r';
  }

  @visibleForTesting
  static List<int> buildReceiptBytes(ReceiptData r, {required bool is58mm}) {
    final w = is58mm ? 32 : 48;
    final out = <int>[];

    void raw(List<int> b) => out.addAll(b);
    void align(int a) => raw([0x1B, 0x61, a]); // 0 kiri, 1 tengah, 2 kanan
    void bold(bool on) => raw([0x1B, 0x45, on ? 1 : 0]);
    void size(int wMul, int hMul) =>
        raw([0x1D, 0x21, ((wMul - 1) << 4) | (hMul - 1)]);
    void line([String s = '']) {
      out.addAll(_ascii(s).codeUnits);
      out.add(0x0A);
    }

    void hr([String ch = '-']) => line(ch * w);

    raw([0x1B, 0x40]); // reset printer

    // Header
    align(1);
    bold(true);
    size(1, 2);
    for (final l in _wrap(r.businessName, w)) {
      line(l);
    }
    size(1, 1);
    bold(false);
    line('STRUK PEMBAYARAN');
    align(0);
    hr();

    // Info transaksi
    final date = DateFormat('dd/MM/yyyy HH:mm').format(r.dateTime);
    line(_lr('Tanggal', date, w));
    if (r.reference.isNotEmpty) line(_lr('Ref', r.reference, w));
    if (r.cashierName.isNotEmpty) line(_lr('Kasir', r.cashierName, w));
    if (r.orderTypeLabel.isNotEmpty) line(_lr('Tipe', r.orderTypeLabel, w));
    hr();

    // Item
    for (final item in r.items) {
      for (final l in _wrap(item.name, w)) {
        line(l);
      }
      if (item.variantLabel.isNotEmpty) {
        for (final l in _wrap('(${item.variantLabel})', w - 2)) {
          line('  $l');
        }
      }
      line(
        _lr(
          '  ${item.quantity} x ${_num(item.unitPrice)}',
          _num(item.lineTotal),
          w,
        ),
      );
      if (item.note.isNotEmpty) {
        for (final l in _wrap('Cat: ${item.note}', w - 2)) {
          line('  $l');
        }
      }
    }
    hr();

    // Total
    final totalQty = r.items.fold<int>(0, (s, e) => s + e.quantity);
    line(_lr('Jumlah item', '$totalQty', w));
    bold(true);
    size(1, 2);
    line(_lr('TOTAL', 'Rp ${_num(r.total)}', w));
    size(1, 1);
    bold(false);
    if (r.paymentMethodLabel.isNotEmpty) {
      line(_lr('Pembayaran', r.paymentMethodLabel, w));
    }
    hr();

    // Footer
    align(1);
    line('Terima kasih');
    line('Selamat datang kembali');
    align(0);

    raw([0x1B, 0x64, 4]); // feed 4 baris
    raw([
      0x1D,
      0x56,
      0x42,
      0x00,
    ]); // potong kertas (diabaikan bila tak ada cutter)
    return out;
  }
}
