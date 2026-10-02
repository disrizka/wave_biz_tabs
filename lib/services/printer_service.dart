// Layanan printer thermal (ESC/POS) - alur disamakan dengan waze-app:
//   Bluetooth Android : cek izin -> cek BT ON -> validasi MAC -> putus koneksi
//                       lama -> connect (retry 1x) -> cek status -> kirim
//                       bytes per chunk 512.
//   Bluetooth iOS     : izin -> BLE connect -> write (chunk 20) -> disconnect.
//   Network           : RAW TCP (port 9100).
//
// Test print dan cetak struk WAJIB lewat [PrinterService.printBytes] supaya
// alurnya sama persis.
import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart' as esc;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ios_ble_printer_service.dart';

/// Setting printer yang disimpan di SharedPreferences.
/// Key sama dengan waze-app: printer.type, printer.bt.id, printer.bt.name,
/// printer.ip, printer.port, printer.paper.
class PrinterConfig {
  final String type; // 'bluetooth' | 'network'
  final String btId; // Android: MAC, iOS: UUID BLE
  final String btName;
  final String ip;
  final int port;
  final int paper; // 58 | 80

  const PrinterConfig({
    this.type = 'bluetooth',
    this.btId = '',
    this.btName = '',
    this.ip = '',
    this.port = 9100,
    this.paper = 58,
  });

  bool get isNetwork => type == 'network';

  static Future<PrinterConfig> load() async {
    final sp = await SharedPreferences.getInstance();
    return PrinterConfig(
      type: sp.getString('printer.type') ?? 'bluetooth',
      btId: (sp.getString('printer.bt.id') ?? sp.getString('printer.mac') ?? '')
          .trim(),
      btName: sp.getString('printer.bt.name') ?? '',
      ip: (sp.getString('printer.ip') ?? '').trim(),
      port: sp.getInt('printer.port') ?? 9100,
      paper: sp.getInt('printer.paper') ?? 58,
    );
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('printer.type', type);
    await sp.setString('printer.bt.id', btId);
    await sp.setString('printer.bt.name', btName);
    await sp.setString('printer.ip', ip);
    await sp.setInt('printer.port', port);
    await sp.setInt('printer.paper', paper);
  }
}

/// Perangkat printer hasil scan / paired.
class PairedPrinter {
  final String name;
  final String id; // MAC (Android) / UUID (iOS)
  const PairedPrinter({required this.name, required this.id});
}

class PrinterService {
  PrinterService._();

  static const MethodChannel _btChannel = MethodChannel('bt/paired');
  static final RegExp macRegex = RegExp(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$');
  static final IosBlePrinterService _iosBle = IosBlePrinterService();

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  // ---------------------------------------------------------------- izin
  static Future<void> ensureBluetoothPermission() async {
    if (isIOS) {
      final s = await Permission.bluetooth.request();
      if (s.isDenied || s.isPermanentlyDenied) {
        throw 'Izin Bluetooth ditolak. Aktifkan di Pengaturan aplikasi.';
      }
      return;
    }
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    final c = statuses[Permission.bluetoothConnect];
    if (c != null && (c.isDenied || c.isPermanentlyDenied)) {
      throw 'Izin Bluetooth Connect diperlukan. Aktifkan di Pengaturan aplikasi.';
    }
  }

  static Future<void> ensureBluetoothOn() async {
    final on = await PrintBluetoothThermal.bluetoothEnabled;
    if (on != true) {
      throw 'Bluetooth mati. Nyalakan Bluetooth terlebih dahulu.';
    }
  }

  // ---------------------------------------------------------------- scan
  /// Android: daftar printer yang sudah di-pair (gabungan native + plugin,
  /// utamakan yang punya MAC dari native).
  static Future<List<PairedPrinter>> pairedAndroid() async {
    final out = <PairedPrinter>[];
    final seenIds = <String>{};
    final seenNames = <String>{};

    // 1) native channel (nama + MAC)
    try {
      final res = await _btChannel.invokeMethod('getBonded');
      if (res is List) {
        for (final e in res) {
          if (e is! Map) continue;
          final name = (e['name'] ?? '').toString();
          final id = (e['address'] ?? '').toString();
          if (id.isEmpty) continue;
          if (seenIds.add(id)) {
            seenNames.add(name);
            out.add(PairedPrinter(name: name, id: id));
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Printer] getBonded error: $e');
    }

    // 2) plugin (tambahan kalau native tidak menemukan)
    try {
      final dynamic paired = await PrintBluetoothThermal.pairedBluetooths;
      for (final d in List<dynamic>.from((paired ?? const []) as Iterable)) {
        final name = _readName(d);
        final id = _readMac(d);
        if (id.isEmpty || seenIds.contains(id)) continue;
        if (name.isNotEmpty && seenNames.contains(name)) continue;
        seenIds.add(id);
        out.add(PairedPrinter(name: name, id: id));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Printer] pairedBluetooths error: $e');
    }

    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  /// iOS: scan printer BLE di sekitar.
  static Future<List<PairedPrinter>> scanIOS({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final list = await _iosBle.scan(timeout: timeout);
    return list.map((d) => PairedPrinter(name: d.name, id: d.id)).toList();
  }

  static String _readName(dynamic d) {
    try {
      final n = (d as dynamic).name;
      if (n != null) return n.toString();
    } catch (_) {}
    return '';
  }

  static String _readMac(dynamic d) {
    // nama field di plugin: macAdress (typo dari package-nya)
    try {
      final m = (d as dynamic).macAdress;
      if (m != null && m.toString().isNotEmpty) return m.toString();
    } catch (_) {}
    try {
      final m = (d as dynamic).macAddress;
      if (m != null && m.toString().isNotEmpty) return m.toString();
    } catch (_) {}
    return '';
  }

  // ------------------------------------------------------------- cetak
  /// Kirim bytes ESC/POS ke printer sesuai [cfg]. Melempar String/Exception
  /// berisi pesan yang siap ditampilkan kalau gagal.
  static Future<void> printBytes(PrinterConfig cfg, Uint8List bytes) async {
    if (cfg.isNetwork) {
      await _printNetwork(cfg, bytes);
      return;
    }
    if (cfg.btId.isEmpty) {
      throw 'Printer Bluetooth belum dipilih. Buka Pengaturan Printer lalu tekan "Scan & Pick".';
    }
    if (isIOS) {
      await _printIOS(cfg, bytes);
      return;
    }
    await _printAndroid(cfg, bytes);
  }

  static Future<void> _printNetwork(PrinterConfig cfg, Uint8List bytes) async {
    if (cfg.ip.isEmpty) {
      throw 'IP Address printer belum diisi.';
    }
    Socket? socket;
    try {
      socket = await Socket.connect(
        cfg.ip,
        cfg.port,
        timeout: const Duration(seconds: 4),
      );
      socket.add(bytes);
      await socket.flush();
      await Future.delayed(const Duration(milliseconds: 200));
    } on SocketException catch (e) {
      throw 'Tidak bisa terhubung ke ${cfg.ip}:${cfg.port} (${e.message}).';
    } finally {
      await socket?.close();
    }
  }

  static Future<void> _printIOS(PrinterConfig cfg, Uint8List bytes) async {
    await ensureBluetoothPermission();
    try {
      await _iosBle.connect(cfg.btId); // btId = UUID
      await _iosBle.write(bytes); // chunking 20 byte
    } finally {
      await _iosBle.disconnect();
    }
  }

  static Future<void> _printAndroid(PrinterConfig cfg, Uint8List bytes) async {
    await ensureBluetoothPermission();
    await ensureBluetoothOn();

    final mac = cfg.btId.trim();
    if (!macRegex.hasMatch(mac)) {
      throw 'MAC Bluetooth tidak valid. Pair printer di Pengaturan Android lalu pilih ulang lewat "Scan & Pick".';
    }

    // putus koneksi lama (best effort)
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}

    // connect (retry ringan 1x)
    bool connected = await PrintBluetoothThermal.connect(
      macPrinterAddress: mac,
    );
    if (!connected) {
      await Future.delayed(const Duration(milliseconds: 200));
      connected = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
    }
    if (!connected) {
      throw 'Tidak bisa terhubung ke printer ($mac). Pastikan printer menyala dan berada di dekat perangkat.';
    }

    final status = await PrintBluetoothThermal.connectionStatus;
    if (status != true) throw 'Bluetooth tidak terhubung ke printer.';

    await Future.delayed(const Duration(milliseconds: 120)); // warm-up
    await _writeChunkedAndroid(bytes);
    await Future.delayed(const Duration(milliseconds: 120));
  }

  /// Plugin butuh List<int> (bukan Uint8List) -> kirim per chunk 512.
  static Future<void> _writeChunkedAndroid(Uint8List data) async {
    final payload = data.toList();
    const chunkSize = 512;
    for (var offset = 0; offset < payload.length; offset += chunkSize) {
      final end = (offset + chunkSize < payload.length)
          ? offset + chunkSize
          : payload.length;
      final ok = await PrintBluetoothThermal.writeBytes(
        payload.sublist(offset, end),
      );
      if (ok != true) throw 'Gagal mengirim data ke printer ($offset..$end).';
      await Future.delayed(const Duration(milliseconds: 8));
    }
  }

  // ------------------------------------------------------- isi test print
  static Future<Uint8List> buildTestBytes({
    required int paper,
    String mode = '',
  }) async {
    final profile = await esc.CapabilityProfile.load();
    final gen = esc.Generator(
      paper == 80 ? esc.PaperSize.mm80 : esc.PaperSize.mm58,
      profile,
    );
    final b = <int>[];
    b.addAll(
      gen.text(
        'TEST PRINT',
        styles: const esc.PosStyles(
          align: esc.PosAlign.center,
          bold: true,
          height: esc.PosTextSize.size2,
          width: esc.PosTextSize.size2,
        ),
      ),
    );
    b.addAll(gen.hr());
    b.addAll(gen.text('Hello from WaveUp POS!'));
    b.addAll(gen.text('Paper: $paper mm'));
    if (mode.isNotEmpty) b.addAll(gen.text('Mode: ${mode.toUpperCase()}'));
    b.addAll(gen.feed(2));
    b.addAll(gen.cut());
    return Uint8List.fromList(b);
  }
}