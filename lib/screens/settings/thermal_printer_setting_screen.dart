import 'package:flutter/material.dart';
import 'package:wave_biz_tabs/services/printer_service.dart';

const _kBrand = Color(0xFF008080);

/// Pengaturan printer thermal + Test Print.
/// Alur disamakan dengan waze-app (lihat [PrinterService]).
class ThermalPrinterSettingsScreen extends StatefulWidget {
  const ThermalPrinterSettingsScreen({super.key});

  @override
  State<ThermalPrinterSettingsScreen> createState() =>
      _ThermalPrinterSettingsScreenState();
}

class _ThermalPrinterSettingsScreenState
    extends State<ThermalPrinterSettingsScreen> {
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '9100');
  final _pickedCtrl = TextEditingController();

  String _type = 'bluetooth'; // 'bluetooth' | 'network'
  int _paper = 58; // 58 | 80
  String _btId = ''; // Android: MAC, iOS: UUID
  String _btName = '';

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _scanning = false;

  bool get _isIOS => PrinterService.isIOS;
  bool get _isAndroid => PrinterService.isAndroid;
  bool get _busy => _saving || _testing || _scanning || _loading;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _pickedCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------- prefs
  Future<void> _loadPrefs() async {
    final cfg = await PrinterConfig.load();
    if (!mounted) return;
    setState(() {
      _type = cfg.type;
      _btId = cfg.btId;
      _btName = cfg.btName;
      _pickedCtrl.text = _display(cfg.btName, cfg.btId);
      _ipCtrl.text = cfg.ip;
      _portCtrl.text = cfg.port.toString();
      _paper = cfg.paper;
      _loading = false;
    });
  }

  /// Setting sesuai isi form saat ini (belum tentu sudah di-Save).
  PrinterConfig _currentConfig() => PrinterConfig(
    type: _type,
    btId: _btId.trim(),
    btName: _btName,
    ip: _ipCtrl.text.trim(),
    port: int.tryParse(_portCtrl.text.trim()) ?? 9100,
    paper: _paper,
  );

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _currentConfig().save();
      _snack('Pengaturan printer disimpan');
    } catch (e) {
      _snack('Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _display(String name, String id) {
    final n = name.trim();
    final i = id.trim();
    if (n.isEmpty && i.isEmpty) return '';
    if (n.isNotEmpty && i.isNotEmpty) {
      final short = i.length > 10 ? '${i.substring(0, 10)}…' : i;
      return '$n ($short)';
    }
    return n.isNotEmpty ? n : i;
  }

  // ---------------------------------------------------- scan & pick
  Future<void> _scanAndPick() async {
    setState(() => _scanning = true);
    List<PairedPrinter> list;
    try {
      await PrinterService.ensureBluetoothPermission();
      if (_isIOS) {
        list = await PrinterService.scanIOS();
      } else {
        await PrinterService.ensureBluetoothOn();
        list = await PrinterService.pairedAndroid();
      }
    } catch (e) {
      _snack('Scan gagal: $e');
      if (mounted) setState(() => _scanning = false);
      return;
    }
    if (mounted) setState(() => _scanning = false);

    if (list.isEmpty) {
      _snack(
        _isIOS
            ? 'Tidak ada printer BLE di sekitar.'
            : 'Belum ada perangkat Bluetooth yang di-pair. Pair printer dulu di Pengaturan Bluetooth Android.',
      );
      return;
    }
    if (!mounted) return;

    final picked = await showModalBottomSheet<PairedPrinter>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final d = list[i];
            return ListTile(
              leading: const Icon(Icons.print_rounded, color: _kBrand),
              title: Text(d.name.isEmpty ? 'Unknown' : d.name),
              subtitle: Text(d.id),
              onTap: () => Navigator.pop(ctx, d),
            );
          },
        ),
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _btName = picked.name;
        _btId = picked.id;
        _pickedCtrl.text = _display(_btName, _btId);
      });
    }
  }

  // ------------------------------------------------------ test print
  Future<void> _testPrint() async {
    setState(() => _testing = true);
    try {
      final cfg = _currentConfig();
      if (!cfg.isNetwork && cfg.btId.isEmpty) {
        _snack('Belum ada printer dipilih. Tekan "Scan & Pick" dulu.');
        return;
      }
      final bytes = await PrinterService.buildTestBytes(
        paper: cfg.paper,
        mode: cfg.type,
      );
      await PrinterService.printBytes(cfg, bytes);
      _snack('Test print terkirim');
    } catch (e) {
      _snack('Test print gagal: $e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  // -------------------------------------------------------------- UI
  @override
  Widget build(BuildContext context) {
    final isBt = _type == 'bluetooth';
    final macOk = PrinterService.macRegex.hasMatch(_btId.trim());
    final canTest =
        !_busy && (!isBt || (_isAndroid ? macOk : _btId.trim().isNotEmpty));

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Printer Thermal',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canTest ? _testPrint : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: _kBrand,
                    ),
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_outlined),
                    label: const Text('Test Print'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBrand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Simpan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    if (_isIOS)
                      _notice(
                        'iOS: kebanyakan printer Bluetooth ESC/POS hanya bisa jika BLE. '
                        'Sebaiknya pakai Network (RAW 9100) bila memungkinkan.',
                        bg: const Color(0xFFF0FDF4),
                        line: const Color(0xFFBBF7D0),
                        fg: const Color(0xFF166534),
                      ),
                    if (_isAndroid && isBt && !macOk)
                      _notice(
                        'Android butuh MAC Bluetooth yang valid. Pair printer di '
                        'Pengaturan Bluetooth Android, lalu tekan "Scan & Pick".',
                        bg: const Color(0xFFFFF7ED),
                        line: const Color(0xFFF59E0B),
                        fg: const Color(0xFF92400E),
                      ),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'bluetooth',
                          label: Text('Bluetooth'),
                          icon: Icon(Icons.bluetooth),
                        ),
                        ButtonSegment(
                          value: 'network',
                          label: Text('Network'),
                          icon: Icon(Icons.lan_outlined),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: _busy
                          ? null
                          : (s) => setState(() => _type = s.first),
                      showSelectedIcon: false,
                    ),
                    const SizedBox(height: 12),
                    if (isBt) ...[
                      TextField(
                        controller: _pickedCtrl,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Printer terpilih',
                          prefixIcon: const Icon(Icons.bluetooth),
                          border: border,
                          disabledBorder: border,
                          helperText:
                              'Tekan "Scan & Pick" untuk memilih printer Bluetooth yang sudah di-pair.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _scanAndPick,
                        icon: _scanning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.search),
                        label: const Text('Scan & Pick'),
                      ),
                    ] else ...[
                      TextField(
                        controller: _ipCtrl,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'IP Address (LAN)',
                          hintText: 'contoh: 192.168.1.50',
                          border: border,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _portCtrl,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Port',
                          hintText: '9100',
                          border: border,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Ukuran kertas',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PaperChip(
                          label: '58 mm',
                          selected: _paper == 58,
                          onTap: _busy
                              ? null
                              : () => setState(() => _paper = 58),
                        ),
                        _PaperChip(
                          label: '80 mm',
                          selected: _paper == 80,
                          onTap: _busy
                              ? null
                              : () => setState(() => _paper = 80),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Test Print memakai isi form saat ini. Tekan "Simpan" '
                      'supaya pengaturan ini dipakai saat mencetak struk.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _notice(
    String text, {
    required Color bg,
    required Color line,
    required Color fg,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: fg)),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}

class _PaperChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _PaperChip({required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = selected ? _kBrand.withOpacity(0.12) : const Color(0xFFF3F4F6);
    final fg = selected ? _kBrand : const Color(0xFF374151);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _kBrand : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
