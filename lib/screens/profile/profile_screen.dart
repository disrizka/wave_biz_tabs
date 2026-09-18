import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wave_biz_tabs/models/business_model.dart';
import 'package:wave_biz_tabs/providers/auth_provider.dart';
import 'package:wave_biz_tabs/screens/home/widgets/business_switcher_sheet.dart';

const _kBrandBlue = Color(0xFF008080);
const _kBrandBlueDark = Color(0xFF00695C);
const _kBg = Color(0xFFF4F6FB);

/// Halaman Profil.
///
/// Diakses dari ikon profile (bukan logo bisnis). Dari sini user bisa
/// membuka switcher untuk "Ganti Bisnis" atau "Keluar" dari akun.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => _LogoutDialog(),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  void _openSwitcher(
    BuildContext context,
    WidgetRef ref,
    BusinessModel active,
    List<BusinessModel> list,
  ) {
    if (list.length <= 1) return;
    showBusinessSwitcher(
      context,
      businessList: list,
      activeBusinessId: active.idBusiness,
      onSelected: (b) =>
          ref.read(authProvider.notifier).setActiveBusiness(b.idBusiness),
      // Logout sudah punya tempat sendiri di halaman Profile ini,
      // jadi sheet switcher tidak perlu menampilkan tombol keluar lagi.
      showLogout: false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final activeBusiness = authState.activeBusiness;
    final user = authState.user;
    final canSwitch = authState.businessList.length > 1;

    final displayName = (user?.fullName.isNotEmpty ?? false)
        ? user!.fullName
        : (user?.username ?? 'Pengguna');
    final initials = _initialsOf(displayName);

    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 210,
            backgroundColor: _kBrandBlue,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'Profil',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            centerTitle: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_kBrandBlue, _kBrandBlueDark],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      top: -30,
                      child: _decorCircle(120, Colors.white.withOpacity(0.08)),
                    ),
                    Positioned(
                      left: -40,
                      bottom: -50,
                      child: _decorCircle(140, Colors.white.withOpacity(0.06)),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 34,
                                backgroundColor: Colors.white,
                                backgroundImage:
                                    (user?.photoPath.isNotEmpty ?? false)
                                    ? NetworkImage(user!.photoPath)
                                    : null,
                                child: (user?.photoPath.isNotEmpty ?? false)
                                    ? null
                                    : Text(
                                        initials,
                                        style: const TextStyle(
                                          color: _kBrandBlue,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 22,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                            if ((user?.email ?? '').isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                user!.email,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (activeBusiness != null) ...[
                  _SectionLabel('Bisnis Aktif'),
                  const SizedBox(height: 10),
                  _Card(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2F1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: activeBusiness.logoPath.isNotEmpty
                                ? Image.network(
                                    activeBusiness.logoPath,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.storefront,
                                      color: _kBrandBlue,
                                    ),
                                  )
                                : const Icon(
                                    Icons.storefront,
                                    color: _kBrandBlue,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeBusiness.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  _Pill(
                                    text: activeBusiness.userRoleName,
                                    color: Colors.grey.shade100,
                                    textColor: Colors.grey.shade700,
                                  ),
                                  if (activeBusiness.isPremium) ...[
                                    const SizedBox(width: 6),
                                    _Pill(
                                      text: 'Premium',
                                      color: Colors.amber.shade100,
                                      textColor: Colors.orange.shade800,
                                      icon: Icons.workspace_premium_rounded,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                ],

                _SectionLabel('Pengaturan Akun'),
                const SizedBox(height: 10),
                _Card(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _ActionTile(
                        icon: Icons.swap_horiz_rounded,
                        iconBg: const Color(0xFFE0F2F1),
                        iconColor: _kBrandBlue,
                        title: 'Ganti Bisnis',
                        subtitle: canSwitch
                            ? 'Beralih ke bisnis lain yang kamu kelola'
                            : 'Hanya 1 bisnis terdaftar',
                        enabled: canSwitch && activeBusiness != null,
                        onTap: canSwitch && activeBusiness != null
                            ? () => _openSwitcher(
                                context,
                                ref,
                                activeBusiness,
                                authState.businessList,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Card(
                  padding: EdgeInsets.zero,
                  child: _ActionTile(
                    icon: Icons.logout_rounded,
                    iconBg: const Color(0xFFFDEDED),
                    iconColor: Colors.redAccent,
                    title: 'Keluar',
                    titleColor: Colors.redAccent,
                    subtitle: 'Keluar dari akun ini di perangkat ini',
                    onTap: () => _confirmLogout(context, ref),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _decorCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  static String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, required this.padding});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.color,
    required this.textColor,
    this.icon,
  });

  final String text;
  final Color color;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: textColor),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.titleColor,
    this.enabled = true,
    this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: titleColor ?? Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog konfirmasi keluar akun, tampil lebih hidup dengan ikon besar
/// dan tombol full-width.
class _LogoutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFDEDED),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Keluar dari akun?',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              'Kamu perlu login lagi untuk masuk ke akun ini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Ya, Keluar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: Colors.grey.shade700,
                ),
                child: const Text(
                  'Batal',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
