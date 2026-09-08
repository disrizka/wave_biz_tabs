import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wave_biz_tabs/models/business_model.dart';
import 'package:wave_biz_tabs/providers/auth_provider.dart';
import 'package:wave_biz_tabs/providers/card_provider.dart';
import 'package:wave_biz_tabs/screens/home/widgets/business_switcher_sheet.dart';
import 'package:wave_biz_tabs/screens/home/widgets/order_summary_panel.dart';
import 'product_list_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tabIndex = 0;

  List<_NavItem> _tabs(bool cartHasItems) => [
    const _NavItem(icon: Icons.note_add_rounded, label: 'Produk'),
    _NavItem(
      icon: Icons.receipt_long_outlined,
      label: 'Pesanan',
      hasBadge: cartHasItems,
    ),
    const _NavItem(
      icon: Icons.account_balance_wallet_outlined,
      label: 'Transaksi',
    ),
  ];

  void _openSwitcher(
    BusinessModel active,
    List<BusinessModel> list, {
    bool showLogout = true,
  }) {
    if (list.length <= 1 && !showLogout) return;
    showBusinessSwitcher(
      context,
      businessList: list,
      activeBusinessId: active.idBusiness,
      onSelected: (b) =>
          ref.read(authProvider.notifier).setActiveBusiness(b.idBusiness),
      onLogout: _confirmLogout,
      showLogout: showLogout,
    );
  }

  void _handleMobileProfileTap(BusinessModel active, List<BusinessModel> list) {
    if (list.length <= 1) {
      _confirmLogout();
    } else {
      _openSwitcher(active, list, showLogout: true);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Keluar dari akun?'),
        content: const Text('Kamu perlu login lagi untuk masuk ke akun ini.'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _logout();
    }
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final activeBusiness = authState.activeBusiness;
    final cartState = ref.watch(cartProvider);
    final tabs = _tabs(!cartState.isEmpty);

    if (activeBusiness == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('WAVEUP'),
          actions: [
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          ],
        ),
        body: const Center(child: Text('Belum ada bisnis terdaftar')),
      );
    }

    final page = IndexedStack(
      index: _tabIndex,
      children: [
        ProductListScreen(
          key: ValueKey(activeBusiness.idBusiness),
          businessId: activeBusiness.idBusiness,
        ),
        const OrderSummaryPanel(),
        const _ComingSoonScreen(title: 'Transaksi'),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;

        if (isWide) {
          return Scaffold(
            backgroundColor: const Color(0xFFF4F6FB),
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SideRail(
                  tabs: tabs,
                  selectedIndex: _tabIndex,
                  onSelectTab: (i) => setState(() => _tabIndex = i),
                  onTapLogo: () => _openSwitcher(
                    activeBusiness,
                    authState.businessList,
                    showLogout: false,
                  ),
                  onTapProfile: _confirmLogout,
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      bottomLeft: Radius.circular(24),
                    ),
                    child: Container(color: Colors.white, child: page),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: SafeArea(child: page),
          bottomNavigationBar: _BottomNav(
            tabs: tabs,
            selectedIndex: _tabIndex,
            onSelectTab: (i) => setState(() => _tabIndex = i),
            onTapProfile: () =>
                _handleMobileProfileTap(activeBusiness, authState.businessList),
          ),
        );
      },
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final bool hasBadge;
  const _NavItem({
    required this.icon,
    required this.label,
    this.hasBadge = false,
  });
}

class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelectTab,
    required this.onTapLogo,
    required this.onTapProfile,
  });

  final List<_NavItem> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onTapLogo;
  final VoidCallback onTapProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      margin: const EdgeInsets.fromLTRB(14, 16, 10, 16),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Tooltip(
            message: 'Pilih bisnis',
            child: InkWell(
              onTap: onTapLogo,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 46,
                height: 46,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF1FD),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFDCE2FA)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.asset(
                    'assets/images/icon.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.storefront,
                      size: 20,
                      color: Color(0xFF3B5FE0),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          for (var i = 0; i < tabs.length; i++) ...[
            _RailIcon(
              icon: tabs[i].icon,
              selected: i == selectedIndex,
              hasBadge: tabs[i].hasBadge,
              onTap: () => onSelectTab(i),
            ),
            const SizedBox(height: 10),
          ],
          const Spacer(),
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            height: 1,
            width: 28,
            color: Colors.grey.shade200,
          ),
          const SizedBox(height: 12),
          Tooltip(
            message: 'Keluar',
            child: _RailIcon(
              icon: Icons.person_outline,
              selected: false,
              onTap: onTapProfile,
            ),
          ),
        ],
      ),
    );
  }
}

class _RailIcon extends StatelessWidget {
  const _RailIcon({
    required this.icon,
    required this.selected,
    required this.onTap,
    this.hasBadge = false,
  });

  final IconData icon;
  final bool selected;
  final bool hasBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 50,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3B5FE0) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF3B5FE0).withOpacity(0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? Colors.white : Colors.grey.shade500,
            ),
            if (hasBadge)
              Positioned(
                top: -2,
                right: 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? const Color(0xFF3B5FE0) : Colors.white,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelectTab,
    required this.onTapProfile,
  });

  final List<_NavItem> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onTapProfile;

  @override
  Widget build(BuildContext context) {
    final profileIndex = tabs.length;
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: selectedIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: const Color(0xFF3B5FE0),
        unselectedItemColor: Colors.grey.shade500,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        onTap: (i) {
          if (i == profileIndex) {
            onTapProfile();
            return;
          }
          onSelectTab(i);
        },
        items: [
          for (final t in tabs)
            BottomNavigationBarItem(
              icon: t.hasBadge
                  ? Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(t.icon),
                        Positioned(
                          top: -2,
                          right: -3,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Icon(t.icon),
              label: t.label,
            ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ComingSoonScreen extends StatelessWidget {
  const _ComingSoonScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            '$title - segera hadir',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
