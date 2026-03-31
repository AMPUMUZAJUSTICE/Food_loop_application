import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/expiry_item.dart';
import '../bloc/expiry_tracker_cubit.dart';

class ExpiryTrackerScreen extends StatelessWidget {
  const ExpiryTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! AuthAuthenticated) {
          return const Scaffold(body: Center(child: Text('Not authenticated')));
        }
        
        return BlocProvider(
          create: (_) => sl<ExpiryTrackerCubit>()..loadItems(authState.user.uid),
          child: _ExpiryTrackerView(userId: authState.user.uid),
        );
      },
    );
  }
}

class _ExpiryTrackerView extends StatelessWidget {
  final String userId;
  const _ExpiryTrackerView({required this.userId});

  void _showAddItemBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddItemSheet(
        userId: userId,
        cubit: context.read<ExpiryTrackerCubit>(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Expiry Tracker', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Track your food before it goes to waste', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add, color: AppColors.white),
            label: const Text('Add Item', style: TextStyle(color: AppColors.white)),
            onPressed: () => _showAddItemBottomSheet(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocBuilder<ExpiryTrackerCubit, ExpiryTrackerState>(
        builder: (context, state) {
          if (state is ExpiryTrackerLoading || state is ExpiryTrackerInitial) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
          }

          if (state is ExpiryTrackerError) {
            return Center(child: Text('Error: ${state.message}', style: const TextStyle(color: AppColors.errorRed)));
          }

          if (state is ExpiryTrackerLoaded) {
            if (state.items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    const Text('No items tracked yet', style: TextStyle(fontSize: 18, color: AppColors.textGrey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Add food to get daily expiry reminders.', style: TextStyle(color: AppColors.textGrey)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Item'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: AppColors.white),
                      onPressed: () => _showAddItemBottomSheet(context),
                    ),
                  ],
                ),
              );
            }

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            
            final expiringToday = <ExpiryItem>[];
            final thisWeek = <ExpiryItem>[];
            final safe = <ExpiryItem>[];

            for (final item in state.items) {
              final itemDate = DateTime(item.expiryDate.year, item.expiryDate.month, item.expiryDate.day);
              final diff = itemDate.difference(today).inDays;
              
              if (diff <= 0) {
                expiringToday.add(item);
              } else if (diff <= 3) {
                thisWeek.add(item);
              } else {
                safe.add(item);
              }
            }

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                if (expiringToday.isNotEmpty) _Section(title: 'Expiring Today 🔴', items: expiringToday, userId: userId),
                if (thisWeek.isNotEmpty) _Section(title: 'Soon 🟡', items: thisWeek, userId: userId),
                if (safe.isNotEmpty) _Section(title: 'Safe 🟢', items: safe, userId: userId),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<ExpiryItem> items;
  final String userId;

  const _Section({required this.title, required this.items, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 1),
          itemBuilder: (context, index) => _ExpiryItemTile(item: items[index], userId: userId),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ExpiryItemTile extends StatefulWidget {
  final ExpiryItem item;
  final String userId;
  const _ExpiryItemTile({required this.item, required this.userId});

  @override
  State<_ExpiryItemTile> createState() => _ExpiryItemTileState();
}

class _ExpiryItemTileState extends State<_ExpiryItemTile> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    final diff = DateTime(widget.item.expiryDate.year, widget.item.expiryDate.month, widget.item.expiryDate.day)
        .difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;
    
    if (diff <= 0) {
      _animController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_ExpiryItemTile old) {
    super.didUpdateWidget(old);
    final diff = DateTime(widget.item.expiryDate.year, widget.item.expiryDate.month, widget.item.expiryDate.day)
        .difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;
    if (diff <= 0 && !_animController.isAnimating) {
      _animController.repeat(reverse: true);
    } else if (diff > 0 && _animController.isAnimating) {
      _animController.stop();
      _animController.value = 1;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  int get _daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(widget.item.expiryDate.year, widget.item.expiryDate.month, widget.item.expiryDate.day);
    return itemDate.difference(today).inDays;
  }

  Color get _color {
    if (_daysLeft <= 0) return AppColors.errorRed;
    if (_daysLeft <= 3) return AppColors.warningAmber;
    return AppColors.successGreen;
  }

  Color get _bgColor {
    if (_daysLeft <= 0) return AppColors.errorRed.withOpacity(0.08);
    if (_daysLeft <= 3) return AppColors.warningAmber.withOpacity(0.08);
    return AppColors.white;
  }

  String get _subtitle {
    if (_daysLeft < 0) return 'Expired ${_daysLeft.abs()} days ago';
    if (_daysLeft == 0) return 'Expires today';
    if (_daysLeft == 1) return 'Expires tomorrow';
    return 'Expires in $_daysLeft days';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgColor,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: AnimatedBuilder(
          animation: _animController,
          builder: (_, child) => Opacity(
            opacity: _daysLeft <= 0 ? _animController.value : 1.0,
            child: Container(
              width: 14, height: 14,
              decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
            ),
          ),
        ),
        title: Text(widget.item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(_subtitle, style: TextStyle(color: _color, fontWeight: _daysLeft <= 0 ? FontWeight.bold : FontWeight.normal)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.share, color: AppColors.primaryGreen),
              tooltip: 'Share to Feed',
              onPressed: () {
                // Here we'd populate the post wizard with the item name
                context.push('/post/step1', extra: widget.item.name);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.textGrey),
              tooltip: 'Delete',
              onPressed: () {
                context.read<ExpiryTrackerCubit>().deleteItem(widget.userId, widget.item.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AddItemSheet extends StatefulWidget {
  final String userId;
  final ExpiryTrackerCubit cubit; // Passed to ensure it's available in the overlay

  const _AddItemSheet({required this.userId, required this.cubit});

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _nameController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryGreen,
            onPrimary: AppColors.white,
            onSurface: AppColors.textDark,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedDate == null) return;

    setState(() => _isLoading = true);
    
    final item = ExpiryItem(
      id: const Uuid().v4(),
      userId: widget.userId,
      name: name,
      expiryDate: _selectedDate!,
      isSharedToFeed: false,
      createdAt: DateTime.now(),
    );

    await widget.cubit.addItem(item);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Track New Item', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Item Name',
              hintText: 'e.g. Milk, Bread, Apples',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.fastfood),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Expiry Date',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(
                _selectedDate == null
                    ? 'Select Date'
                    : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                style: TextStyle(
                  color: _selectedDate == null ? AppColors.textGrey : AppColors.textDark,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: (_isLoading || _nameController.text.trim().isEmpty || _selectedDate == null) ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                : const Text('Save Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
