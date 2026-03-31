import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../bloc/feed_bloc.dart';
import '../bloc/feed_event.dart';
import '../bloc/feed_state.dart';
import '../widgets/food_card.dart';
import '../../../../injection_container.dart';
import '../../../notifications/presentation/bloc/notification_bloc.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late final FeedBloc _feedBloc;
  String _selectedCategory = 'All';
  String _selectedSort = 'Newest';
  
  final List<String> _filters = [
    "All", "Cooked Meals", "Groceries", "Snacks", "Beverages", "Baked Goods", "🆓 Free Only"
  ];

  final List<String> _sortOptions = [
    "Newest", "Price ↑", "Price ↓", "Expiring Soon"
  ];

  @override
  void initState() {
    super.initState();
    _feedBloc = sl<FeedBloc>()..add(FeedLoadRequested());
    _requestLocation();
  }

  Future<void> _requestLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    if (mounted) {
      _feedBloc.add(FeedLocationChanged(position));
    }
  }

  @override
  void dispose() {
    _feedBloc.close();
    super.dispose();
  }

  void _onFilterSelected(String filter) {
    setState(() => _selectedCategory = filter);
    _applyFilters();
  }

  void _onSortSelected(String? sort) {
    if (sort == null) return;
    setState(() => _selectedSort = sort);
    _applyFilters();
  }

  void _applyFilters() {
    String? apiCategory;
    bool? freeOnly;
    
    if (_selectedCategory == '🆓 Free Only') {
      freeOnly = true;
    } else if (_selectedCategory != 'All') {
      if (_selectedCategory == 'Cooked Meals') apiCategory = 'cookedMeal';
      else if (_selectedCategory == 'Groceries') apiCategory = 'groceries';
      else if (_selectedCategory == 'Snacks') apiCategory = 'snacks';
      else if (_selectedCategory == 'Beverages') apiCategory = 'beverages';
      else if (_selectedCategory == 'Baked Goods') apiCategory = 'bakedGoods';
    }

    String apiSort;
    if (_selectedSort == 'Newest') apiSort = 'newest';
    else if (_selectedSort == 'Price ↑') apiSort = 'price_asc';
    else if (_selectedSort == 'Price ↓') apiSort = 'price_desc';
    else apiSort = 'expiry_soonest';

    _feedBloc.add(FeedFilterChanged(
      category: apiCategory,
      freeOnly: freeOnly,
      sortBy: apiSort,
    ));
  }

  Widget _buildLoadingShimmer() {
    return MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      itemCount: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: index.isEven ? 200 : 250,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          const Icon(Icons.fastfood_outlined, size: 100, color: AppColors.lightGreen),
          const SizedBox(height: 24),
          const Text(
            'No food available right now',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/post/step1'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Post the first item'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _feedBloc,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          title: const Row(
            children: [
              Icon(Icons.restaurant_menu, color: AppColors.primaryGreen),
              SizedBox(width: 8),
              Text(
                'Food Loop',
                style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: BlocBuilder<NotificationBloc, NotificationState>(
                builder: (context, notificationState) {
                  int unreadCount = 0;
                  if (notificationState is NotificationLoaded) {
                    unreadCount = notificationState.unreadCount;
                  }
                  
                  return Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text(unreadCount > 99 ? '99+' : unreadCount.toString()),
                    backgroundColor: AppColors.errorRed,
                    child: const Icon(Icons.notifications_none, color: AppColors.textDark),
                  );
                },
              ),
              onPressed: () => context.push('/notifications'),
            ),
          ],
        ),
        body: RefreshIndicator(
          color: AppColors.primaryGreen,
          onRefresh: () async {
            _feedBloc.add(FeedRefreshRequested());
          },
          child: CustomScrollView(
            slivers: [
              // Greeting Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      String name = 'Guest';
                      if (state is AuthAuthenticated) {
                        name = state.user.displayName ?? 'User';
                      }
                      
                      final hour = DateTime.now().hour;
                      String greeting = 'Good evening';
                      if (hour < 12) greeting = 'Good morning';
                      else if (hour < 17) greeting = 'Good afternoon';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greeting, $name 👋',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Find food near you',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // Filters & Sort
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // Chips Row
                    SizedBox(
                      height: 50,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filters.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final filter = _filters[index];
                          final isSelected = filter == _selectedCategory;
                          return ChoiceChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (_) => _onFilterSelected(filter),
                            selectedColor: AppColors.primaryGreen,
                            backgroundColor: AppColors.white,
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.white : AppColors.textGrey,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected ? AppColors.primaryGreen : Colors.grey[300]!,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // Sort Dropdown
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(Icons.sort, size: 16, color: AppColors.textGrey),
                          const SizedBox(width: 4),
                          DropdownButton<String>(
                            value: _selectedSort,
                            onChanged: _onSortSelected,
                            items: _sortOptions.map((sort) {
                              return DropdownMenuItem(
                                value: sort,
                                child: Text(sort, style: const TextStyle(fontSize: 14, color: AppColors.textDark)),
                              );
                            }).toList(),
                            underline: const SizedBox(),
                            icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryGreen),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Grid Content
              BlocBuilder<FeedBloc, FeedState>(
                builder: (context, state) {
                  if (state is FeedInitial || state is FeedLoading) {
                    return SliverToBoxAdapter(child: _buildLoadingShimmer());
                  } else if (state is FeedError) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(child: Text('Error: ${state.message}')),
                      ),
                    );
                  } else if (state is FeedLoaded) {
                    if (state.listings.isEmpty) {
                      return SliverToBoxAdapter(child: _buildEmptyState());
                    }
                    
                    return SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverMasonryGrid.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childCount: state.listings.length,
                        itemBuilder: (context, index) {
                          final listing = state.listings[index];
                          double distance = 0.0;
                          
                          if (state.userLocation != null) {
                            distance = Geolocator.distanceBetween(
                              state.userLocation!.latitude,
                              state.userLocation!.longitude,
                              listing.pickupLocation.latitude,
                              listing.pickupLocation.longitude,
                            ) / 1000; // Convert to km
                          }
                          
                          return FoodCard(
                            listing: listing,
                            distanceKm: distance,
                            onTap: () => context.push('/feed/listing/${listing.id}'),
                          );
                        },
                      ),
                    );
                  }
                  
                  return const SliverToBoxAdapter(child: SizedBox());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
