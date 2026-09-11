import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wave_biz_tabs/models/cart_model.dart';
import 'package:wave_biz_tabs/models/draft_order_model.dart';
import 'package:wave_biz_tabs/providers/auth_provider.dart';

/// Keeps the list of "parked" draft orders (saved from the order summary
/// panel) and persists them to disk, scoped per active business — mirrors
/// the pattern used by [CartNotifier].
class DraftNotifier extends Notifier<List<DraftOrder>> {
  static const _keyPrefix = 'wave_biz_tabs.cart.drafts.';

  String get _businessId =>
      ref.read(authProvider).activeBusinessId ?? 'default';
  String get _key => '$_keyPrefix$_businessId';

  @override
  List<DraftOrder> build() {
    ref.listen(authProvider, (previous, next) {
      if (previous?.activeBusinessId != next.activeBusinessId) {
        state = [];
        _load();
      }
    });
    Future.microtask(_load);
    return [];
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        state = decoded
            .map((e) => DraftOrder.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        state = [];
      }
    } catch (_) {
      state = [];
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  /// Parks the given cart snapshot as a new draft, most recent first.
  Future<DraftOrder> saveDraft({
    required List<CartItem> items,
    required OrderType orderType,
  }) async {
    final draft = DraftOrder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      items: items,
      orderType: orderType,
      savedAt: DateTime.now(),
    );
    state = [draft, ...state];
    await _persist();
    return draft;
  }

  Future<void> removeDraft(String id) async {
    state = state.where((d) => d.id != id).toList();
    await _persist();
  }

  Future<void> clearAll() async {
    state = [];
    await _persist();
  }
}

final draftProvider = NotifierProvider<DraftNotifier, List<DraftOrder>>(
  DraftNotifier.new,
);
