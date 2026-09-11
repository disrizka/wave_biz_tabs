import 'package:flutter/material.dart';
import 'package:wave_biz_tabs/models/business_model.dart';

const _kBrandBlue = Color(0xFF3B5FE0);

Future<void> showBusinessSwitcher(
  BuildContext context, {
  required List<BusinessModel> businessList,
  required String activeBusinessId,
  required ValueChanged<BusinessModel> onSelected,
  VoidCallback? onLogout,
  bool showLogout = true,
}) {
  final isTablet = MediaQuery.sizeOf(context).width >= 600;

  if (isTablet) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
        child: _BusinessSwitcherContent(
          businessList: businessList,
          activeBusinessId: activeBusinessId,
          onSelected: onSelected,
          onLogout: onLogout,
          showLogout: showLogout,
          isTablet: true,
        ),
      ),
    );
  }

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: _BusinessSwitcherContent(
          businessList: businessList,
          activeBusinessId: activeBusinessId,
          onSelected: onSelected,
          onLogout: onLogout,
          showLogout: showLogout,
          isTablet: false,
          scrollController: scrollController,
        ),
      ),
    ),
  );
}

class _BusinessSwitcherContent extends StatelessWidget {
  const _BusinessSwitcherContent({
    required this.businessList,
    required this.activeBusinessId,
    required this.onSelected,
    required this.onLogout,
    required this.showLogout,
    required this.isTablet,
    this.scrollController,
  });

  final List<BusinessModel> businessList;
  final String activeBusinessId;
  final ValueChanged<BusinessModel> onSelected;
  final VoidCallback? onLogout;
  final bool showLogout;
  final bool isTablet;
  final ScrollController? scrollController;

  bool get _hasLogoutTile => showLogout && onLogout != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final dragHandle = Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Center(
        child: Container(
          height: 4,
          width: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );

    final title = Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih Bisnis',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Beralih ke bisnis lain yang kamu kelola',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
              ),
            ],
          ),
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 17, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );

    final list = isTablet
        ? GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(20, 0, 20, _hasLogoutTile ? 12 : 20),
            physics: const NeverScrollableScrollPhysics(),
            itemCount: businessList.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 3.2,
            ),
            itemBuilder: (context, i) => _BusinessTile(
              business: businessList[i],
              isActive: businessList[i].idBusiness == activeBusinessId,
              onTap: () {
                onSelected(businessList[i]);
                Navigator.of(context).pop();
              },
            ),
          )
        : ListView.separated(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(20, 0, 20, _hasLogoutTile ? 12 : 24),
            itemCount: businessList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _BusinessTile(
              business: businessList[i],
              isActive: businessList[i].idBusiness == activeBusinessId,
              onTap: () {
                onSelected(businessList[i]);
                Navigator.of(context).pop();
              },
            ),
          );

    final logoutTile = Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).pop();
          onLogout?.call();
        },
        icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.red),
        label: const Text(
          'Keluar',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: Colors.redAccent, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );

    if (isTablet) {
      return SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            title,
            list,
            if (_hasLogoutTile) ...[const Divider(height: 1), logoutTile],
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        dragHandle,
        title,
        Expanded(child: list),
        if (_hasLogoutTile) ...[const Divider(height: 1), logoutTile],
      ],
    );
  }
}

class _BusinessTile extends StatelessWidget {
  const _BusinessTile({
    required this.business,
    required this.isActive,
    required this.onTap,
  });

  final BusinessModel business;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isActive ? _kBrandBlue.withOpacity(0.06) : Colors.white,
          border: Border.all(
            color: isActive ? _kBrandBlue : Colors.grey.shade200,
            width: isActive ? 1.6 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: _kBrandBlue.withOpacity(0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: business.logoPath.isNotEmpty
                    ? Image.network(
                        business.logoPath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.storefront, color: Colors.grey.shade500),
                      )
                    : Icon(Icons.storefront, color: Colors.grey.shade500),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    business.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        business.userRoleName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (business.isPremium) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Premium',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isActive)
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: _kBrandBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
          ],
        ),
      ),
    );
  }
}
