import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:wave_biz_tabs/services/receipt_printer_service.dart';

const _kAccent = Color(0xFF008080);
const _kBg = Color(0xFFF4F6FB);
const _kInk = Color(0xFF1F2430);

/// Pilih printer thermal Bluetooth untuk mencetak struk.
/// Printer harus di-pair dulu lewat Pengaturan Bluetooth Android.
class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _svc = ReceiptPrinterService.instance;

  PrinterConfig _config = const PrinterConfig();
  List<BluetoothInfo> _devices = const [];
  bool _loading = true;
  bool _busy = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _problem = null;
    });
    try {
      _config = await _svc.loadConfig();
      if (!await _svc.ensurePermissions()) {
        _problem = 'Izin Bluetooth ditolak. Aktifkan di pengaturan aplikasi.';
      } else if (!await _svc.isBluetoothOn()) {
        _problem =
            'Bluetooth belum menyala. Nyalakan lalu tarik untuk refresh.';
      } else {
        _devices = await _svc.pairedPrinters();
        if (_devices.isEmpty) {
          _problem =
              'Belum ada perangkat Bluetooth yang di-pair. Pair printer '
              'dulu di Pengaturan Bluetooth.';
        }
      }
    } catch (e) {
      _problem = 'Gagal memuat printer: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save(PrinterConfig c) async {
    setState(() => _config = c);
    await _svc.saveConfig(c);
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade400 : _kAccent,
      ),
    );
  }

  Future<void> _selectPrinter(BluetoothInfo d) async {
    await _save(_config.copyWith(mac: d.macAdress, name: d.name));
    _toast('Printer dipilih: ${d.name}');
  }

  Future<void> _testPrint() async {
    setState(() => _busy = true);
    final result = await _svc.printTest();
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(result.message, error: !result.ok);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text(
          'Printer Struk',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _kInk,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kAccent))
          : RefreshIndicator(
              color: _kAccent,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  _label('Printer terpilih'),
                  _card(
                    child: ListTile(
                      leading: const Icon(Icons.print_rounded, color: _kAccent),
                      title: Text(
                        _config.hasPrinter ? _config.name : 'Belum dipilih',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        _config.hasPrinter
                            ? _config.mac
                            : 'Pilih printer dari daftar di bawah',
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _label('Ukuran kertas'),
                  _card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: true, label: Text('58 mm')),
                          ButtonSegment(value: false, label: Text('80 mm')),
                        ],
                        selected: {_config.is58mm},
                        onSelectionChanged: (v) =>
                            _save(_config.copyWith(is58mm: v.first)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _card(
                    child: SwitchListTile(
                      activeColor: _kAccent,
                      title: const Text(
                        'Cetak otomatis setelah bayar',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Struk langsung keluar saat pembayaran berhasil',
                      ),
                      value: _config.autoPrint,
                      onChanged: (v) => _save(_config.copyWith(autoPrint: v)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: (_busy || !_config.hasPrinter)
                          ? null
                          : _testPrint,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.receipt_long_rounded, size: 18),
                      label: const Text(
                        'Tes Cetak',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _label('Printer yang sudah di-pair'),
                  if (_problem != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _problem!,
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  for (final d in _devices)
                    _card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Icon(
                          Icons.bluetooth_rounded,
                          color: d.macAdress == _config.mac
                              ? _kAccent
                              : Colors.grey,
                        ),
                        title: Text(
                          d.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(d.macAdress),
                        trailing: d.macAdress == _config.mac
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: _kAccent,
                              )
                            : null,
                        onTap: () => _selectPrinter(d),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      t.toUpperCase(),
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: Colors.grey.shade500,
      ),
    ),
  );

  Widget _card({required Widget child, EdgeInsetsGeometry? margin}) =>
      Container(
        margin: margin,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: child,
      );
}
