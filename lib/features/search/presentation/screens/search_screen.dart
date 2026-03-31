import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../injection_container.dart';
import '../../../feed/presentation/widgets/food_card.dart';
import '../bloc/search_bloc.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SearchBloc>(),
      child: const _SearchScreenView(),
    );
  }
}

class _SearchScreenView extends StatefulWidget {
  const _SearchScreenView();

  @override
  State<_SearchScreenView> createState() => _SearchScreenViewState();
}

class _SearchScreenViewState extends State<_SearchScreenView> {
  final _searchController = TextEditingController();
  final _searchSubject = PublishSubject<String>();
  
  final List<String> _quickFilters = [
    'Price: Low→High',
    'Price: High→Low',
    'Free Only',
    'Expiring Soon',
    'Cooked',
    'Groceries',
    'Snacks',
    'Beverages',
    'Baked Goods',
  ];
  
  final Set<String> _activeFilters = {};

  @override
  void initState() {
    super.initState();
    // Debounce input by 400ms using RxDart before dispatching SearchQueryChanged
    _searchSubject.debounceTime(const Duration(milliseconds: 400)).listen((query) {
      if (mounted) {
        context.read<SearchBloc>().add(SearchQueryChanged(query.trim()));
      }
    });

    _searchController.addListener(() {
      _searchSubject.add(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchSubject.close();
    super.dispose();
  }

  void _toggleFilter(String filter) {
    setState(() {
      if (_activeFilters.contains(filter)) {
        _activeFilters.remove(filter);
      } else {
        // Mutually exclusive price sorting logic
        if (filter == 'Price: Low→High') _activeFilters.remove('Price: High→Low');
        if (filter == 'Price: High→Low') _activeFilters.remove('Price: Low→High');
        _activeFilters.add(filter);
      }
    });
    context.read<SearchBloc>().add(SearchFilterChanged(_activeFilters.toList()));
  }

  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar Area
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: AppColors.white,
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search food, groceries...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.textGrey),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, color: AppColors.textGrey, size: 20),
                              onPressed: _clearSearch,
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.offWhite,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Quick Filters (Horizontal Scroll)
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _quickFilters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final filter = _quickFilters[index];
                        final isActive = _activeFilters.contains(filter);
                        return FilterChip(
                          label: Text(
                            filter,
                            style: TextStyle(
                              color: isActive ? AppColors.white : AppColors.textDark,
                              fontSize: 13,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          backgroundColor: AppColors.white,
                          selectedColor: AppColors.primaryGreen,
                          selected: isActive,
                          onSelected: (_) => _toggleFilter(filter),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isActive ? AppColors.primaryGreen : Colors.grey[300]!,
                            ),
                          ),
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            // Results Area
            Expanded(
              child: BlocBuilder<SearchBloc, SearchState>(
                builder: (context, state) {
                  if (state is SearchLoading) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
                  }
                  
                  if (state is SearchError) {
                    return Center(
                      child: Text('Error: ${state.message}', style: const TextStyle(color: AppColors.errorRed)),
                    );
                  }

                  if (state is SearchEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            "No food found for '${_searchController.text}'",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Try a different search or clear filters",
                            style: TextStyle(color: AppColors.textGrey),
                          ),
                          const SizedBox(height: 24),
                          OutlinedButton(
                            onPressed: () {
                              setState(() => _activeFilters.clear());
                              _clearSearch();
                              context.read<SearchBloc>().add(const SearchFilterChanged([]));
                            },
                            child: const Text('Clear Filters'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (state is SearchResults) {
                    return _SearchResultsGrid(
                      listings: state.listings,
                      query: _searchController.text,
                    );
                  }

                  // Initial State (Recent Searches & Popular Categories)
                  if (state is SearchInitial) {
                    return _InitialStateView(
                      recentSearches: state.recentSearches,
                      onSearchSelected: (query) {
                        _searchController.text = query;
                        // Focus is kept in the textfield from listener
                        context.read<SearchBloc>().add(SearchQueryChanged(query));
                      },
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultsGrid extends StatelessWidget {
  final List<dynamic> listings;
  final String query;

  const _SearchResultsGrid({required this.listings, required this.query});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            "${listings.length} results${query.isNotEmpty ? " for '$query'" : ""}",
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGrey),
          ),
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                context.read<SearchBloc>().add(SearchLoadMore());
              }
              return false;
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75, // Adjust for FoodCard height
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: listings.length,
              itemBuilder: (context, index) {
                return FoodCard(
                  listing: listings[index],
                  distanceKm: 2.5, // Prototype static distance for search
                  onTap: () => context.push('/feed/listing/${listings[index].id}'),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _InitialStateView extends StatelessWidget {
  final List<String> recentSearches;
  final Function(String) onSearchSelected;

  const _InitialStateView({required this.recentSearches, required this.onSearchSelected});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Searches', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton(
                onPressed: () => context.read<SearchBloc>().add(SearchClearRecent()),
                child: const Text('Clear', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: recentSearches.map((query) => ActionChip(
                  label: Text(query, style: const TextStyle(color: AppColors.textDark, fontSize: 13)),
                  backgroundColor: AppColors.white,
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onPressed: () => onSearchSelected(query),
                  avatar: const Icon(Icons.history, size: 16, color: AppColors.textGrey),
                )).toList(),
          ),
          const SizedBox(height: 24),
        ],

        const Text('Popular Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.0,
          children: [
            _CategoryTile(icon: Icons.restaurant, label: 'Cooked', onTap: () => _applyCategory(context, 'Cooked')),
            _CategoryTile(icon: Icons.local_grocery_store, label: 'Groceries', onTap: () => _applyCategory(context, 'Groceries')),
            _CategoryTile(icon: Icons.cake, label: 'Baked Goods', onTap: () => _applyCategory(context, 'Baked Goods')),
            _CategoryTile(icon: Icons.local_cafe, label: 'Beverages', onTap: () => _applyCategory(context, 'Beverages')),
            _CategoryTile(icon: Icons.fastfood, label: 'Snacks', onTap: () => _applyCategory(context, 'Snacks')),
            _CategoryTile(icon: Icons.more_horiz, label: 'Other', onTap: () => _applyCategory(context, 'Other')),
          ],
        ),
      ],
    );
  }

  void _applyCategory(BuildContext context, String cat) {
    // We just dispatch a filter event and UI automatically updates the chips 
    // Wait, the parent UI state _activeFilters wouldn't know. 
    // For prototype simplicity, let's just do a search text.
    onSearchSelected(cat);
  }
}

class _CategoryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CategoryTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primaryGreen, size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
