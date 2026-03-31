import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../feed/domain/entities/food_listing.dart';

@lazySingleton
class SearchRepository {
  final FirebaseFirestore _firestore;
  static const String _recentSearchesKey = 'recent_searches';

  SearchRepository(this._firestore);

  Future<List<FoodListing>> searchListings(String query, List<String> filters) async {
    // 1. Fetch active, non-expired listings
    Query firestoreQuery = _firestore
        .collection('listings')
        .where('status', isEqualTo: 'active')
        .where('pickupWindowEnd', isGreaterThan: Timestamp.now());

    // Fetch up to 100 items for local filtering
    final snapshot = await firestoreQuery.orderBy('pickupWindowEnd').limit(100).get();
    var results = snapshot.docs
        .map((d) => FoodListing.fromJson(d.data() as Map<String, dynamic>))
        .toList();

    // 2. Client-side Category Chip Filter
    final categoryFilters = filters
        .where((f) => ['Cooked', 'Groceries', 'Snacks', 'Beverages', 'Baked Goods'].contains(f))
        .toList();

    if (categoryFilters.isNotEmpty) {
      final enumNames = categoryFilters.map((f) {
        if (f == 'Cooked') return FoodCategory.cookedMeal.name;
        if (f == 'Groceries') return FoodCategory.groceries.name;
        if (f == 'Snacks') return FoodCategory.snacks.name;
        if (f == 'Beverages') return FoodCategory.beverages.name;
        if (f == 'Baked Goods') return FoodCategory.bakedGoods.name;
        return FoodCategory.other.name;
      }).toList();
      results = results.where((item) => enumNames.contains(item.category.name)).toList();
    }

    // 3. Client-side Free Filter
    if (filters.contains('Free Only')) {
      results = results.where((item) => item.isFree).toList();
    }

    // 4. Client-side Text Search (Case-Insensitive substring on Title, Description and Category)
    // This perfectly solves the rapid tap behavior where Category strings get passed as queries
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      results = results.where((item) {
        return item.title.toLowerCase().contains(q) ||
               (item.description?.toLowerCase().contains(q) ?? false) ||
               item.category.name.toLowerCase().contains(q);
      }).toList();
    }

    // Client-side sorting
    if (filters.contains('Price: Low→High')) {
      results.sort((a, b) => a.price.compareTo(b.price));
    } else if (filters.contains('Price: High→Low')) {
      results.sort((a, b) => b.price.compareTo(a.price));
    } else if (filters.contains('Expiring Soon')) {
      results.sort((a, b) => a.pickupWindowEnd.compareTo(b.pickupWindowEnd));
    }

    return results;
  }

  Future<List<String>> getRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentSearchesKey) ?? [];
  }

  Future<void> saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    final recents = prefs.getStringList(_recentSearchesKey) ?? [];
    
    if (recents.contains(query)) {
      recents.remove(query);
    }
    recents.insert(0, query);
    
    if (recents.length > 5) {
      recents.removeLast();
    }
    await prefs.setStringList(_recentSearchesKey, recents);
  }

  Future<void> clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }
}
