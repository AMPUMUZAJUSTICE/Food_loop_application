import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../feed/domain/entities/food_listing.dart';

class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return const Scaffold(body: Center(child: Text('Not authenticated')));
        }
        return _MyListingsView(userId: state.user.uid);
      },
    );
  }
}

class _MyListingsView extends StatelessWidget {
  final String userId;
  const _MyListingsView({required this.userId});

  Stream<List<FoodListing>> _listingsStream(String status) {
    Query query = FirebaseFirestore.instance
        .collection('listings')
        .where('sellerId', isEqualTo: userId);

    return query.snapshots().map((snap) {
      // 1. Parse documents
      final allListings = snap.docs
          .map((d) => FoodListing.fromJson(d.data() as Map<String, dynamic>))
          .toList();
          
      // 2. Filter by status locally to avoid double-field composite index constraints
      final filtered = allListings.where((item) => item.status == ListingStatus.values.firstWhere((e) => e.name == status)).toList();
      
      // 3. Sort by createdAt descending locally to avoid orderBy composite index constraints
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Listings'),
          bottom: const TabBar(
            indicatorColor: AppColors.white,
            labelColor: AppColors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Sold'),
              Tab(text: 'Expired'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ListingsTab(
              stream: _listingsStream('active'),
              emptyTitle: 'No active listings',
              emptySubtitle: 'Post food to get started!',
              showPostButton: true,
            ),
            _ListingsTab(
              stream: _listingsStream('sold'),
              emptyTitle: 'No sold listings yet',
              showPostButton: false,
            ),
            _ListingsTab(
              stream: _listingsStream('expired'),
              emptyTitle: 'No expired listings',
              showPostButton: false,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: AppColors.white,
          onPressed: () => context.push('/post/step1'),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _ListingsTab extends StatelessWidget {
  final Stream<List<FoodListing>> stream;
  final String emptyTitle;
  final String? emptySubtitle;
  final bool showPostButton;

  const _ListingsTab({
    required this.stream,
    required this.emptyTitle,
    this.emptySubtitle,
    required this.showPostButton,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FoodListing>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.errorRed)));
        }

        final listings = snapshot.data ?? [];
        if (listings.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(emptyTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
                  if (emptySubtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(emptySubtitle!, style: const TextStyle(color: AppColors.textGrey), textAlign: TextAlign.center),
                  ],
                  if (showPostButton) ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Post Food'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => context.push('/post/step1'),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: listings.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) => ListingManagementCard(listing: listings[index]),
        );
      },
    );
  }
}

class ListingManagementCard extends StatefulWidget {
  final FoodListing listing;
  const ListingManagementCard({super.key, required this.listing});

  @override
  State<ListingManagementCard> createState() => _ListingManagementCardState();
}

class _ListingManagementCardState extends State<ListingManagementCard> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.listing.status == ListingStatus.active) {
      _updateCountdown();
      _timer = Timer.periodic(const Duration(minutes: 1), (_) => _updateCountdown());
    }
  }

  void _updateCountdown() {
    if (mounted) {
      setState(() {
        final now = DateTime.now();
        final end = widget.listing.pickupWindowEnd;
        _timeLeft = end.isAfter(now) ? end.difference(now) : Duration.zero;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Color get _countdownColor {
    final mins = _timeLeft.inMinutes;
    if (mins < 30) return AppColors.errorRed;
    if (mins < 120) return AppColors.warningAmber;
    return AppColors.primaryGreen;
  }

  String get _countdownLabel {
    if (_timeLeft == Duration.zero) return 'Expired';
    final h = _timeLeft.inHours;
    final m = _timeLeft.inMinutes % 60;
    return h > 0 ? 'Expires in ${h}h ${m}m' : 'Expires in ${m}m';
  }

  Future<void> _updateStatus(String newStatus) async {
    await FirebaseFirestore.instance
        .collection('listings')
        .doc(widget.listing.id)
        .update({'status': newStatus});
  }

  void _confirmAction({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, foregroundColor: AppColors.white),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final isActive = listing.status == ListingStatus.active;
    final isFlashing = _timeLeft.inMinutes < 30 && isActive;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: listing.imageUrls.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: listing.imageUrls.first,
                      width: 80, height: 80,
                      fit: BoxFit.cover,
                      errorWidget: (context, error, stackTrace) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    listing.isFree ? 'Free' : 'UGX ${listing.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: listing.isFree ? AppColors.primaryGreen : AppColors.textDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _StatusChip(status: listing.status),
                  if (isActive) ...[
                    const SizedBox(height: 6),
                    _FlashingCountdown(
                      label: _countdownLabel,
                      color: _countdownColor,
                      flash: isFlashing,
                    ),
                  ],
                ],
              ),
            ),

            // Menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textGrey),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    context.push('/edit-listing', extra: listing);
                    break;
                  case 'sold':
                    _confirmAction(
                      context: context,
                      title: 'Mark as Sold',
                      message: 'Mark "${listing.title}" as sold?',
                      onConfirm: () => _updateStatus('sold'),
                    );
                    break;
                  case 'delete':
                    _confirmAction(
                      context: context,
                      title: 'Delete Listing',
                      message: 'Delete "${listing.title}"? This cannot be undone.',
                      onConfirm: () => _updateStatus('deleted'),
                    );
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit Listing')])),
                const PopupMenuItem(value: 'sold', child: Row(children: [Icon(Icons.check_circle_outline, size: 18, color: AppColors.primaryGreen), SizedBox(width: 8), Text('Mark as Sold')])),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed), SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppColors.errorRed))])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
    width: 80, height: 80,
    color: AppColors.lightGreen,
    child: const Icon(Icons.fastfood, color: AppColors.primaryGreen, size: 36),
  );
}

class _StatusChip extends StatelessWidget {
  final ListingStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case ListingStatus.active:
        bg = AppColors.primaryGreen.withValues(alpha: 0.12);
        fg = AppColors.primaryGreen;
        label = 'Active';
        break;
      case ListingStatus.sold:
        bg = Colors.grey[200]!;
        fg = AppColors.textGrey;
        label = 'Sold';
        break;
      case ListingStatus.expired:
        bg = AppColors.errorRed.withValues(alpha: 0.1);
        fg = AppColors.errorRed;
        label = 'Expired';
        break;
      case ListingStatus.deleted:
        bg = Colors.grey[200]!;
        fg = AppColors.textGrey;
        label = 'Deleted';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.bold)),
    );
  }
}

class _FlashingCountdown extends StatefulWidget {
  final String label;
  final Color color;
  final bool flash;

  const _FlashingCountdown({required this.label, required this.color, required this.flash});

  @override
  State<_FlashingCountdown> createState() => _FlashingCountdownState();
}

class _FlashingCountdownState extends State<_FlashingCountdown> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.flash) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_FlashingCountdown old) {
    super.didUpdateWidget(old);
    if (widget.flash && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.flash && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: widget.flash ? _controller.value : 1.0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 13, color: widget.color),
            const SizedBox(width: 4),
            Text(
              widget.label,
              style: TextStyle(fontSize: 12, color: widget.color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
