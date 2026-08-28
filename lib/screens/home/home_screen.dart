import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import 'product_list_screen.dart';

/// Placeholder home setelah login berhasil.
/// Ganti isinya sesuai kebutuhan fitur utama app kamu nanti.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WAVEUP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Belum ada data user'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundImage: NetworkImage(user.photoPath),
                ),
                const SizedBox(height: 12),
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '@${user.username}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                Text(
                  'Business (${authState.businessList.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...authState.businessList.map(
                  (b) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(b.logoPath),
                      ),
                      title: Text(b.name),
                      subtitle: Text(b.userRoleName),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProductListScreen(
                              businessId: b.idBusiness,
                              businessName: b.name,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
