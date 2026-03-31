import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../feed/domain/entities/food_listing.dart';
import '../bloc/post_food_cubit.dart';
import '../../domain/entities/post_food_draft.dart';

class PostFoodStep2Screen extends StatefulWidget {
  const PostFoodStep2Screen({super.key});

  @override
  State<PostFoodStep2Screen> createState() => _PostFoodStep2ScreenState();
}

class _PostFoodStep2ScreenState extends State<PostFoodStep2Screen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _priceController;

  FoodCategory? _selectedCategory;
  bool _isFree = false;
  final Set<String> _selectedTags = {};

  final List<String> _availableTags = [
    'Vegetarian', 'Vegan', 'Halal', 'Contains Nuts',
    'Contains Gluten', 'Contains Dairy', 'Spicy'
  ];

  final Map<FoodCategory, Map<String, String>> _categories = {
    FoodCategory.cookedMeal: {'label': 'Cooked Meal', 'icon': '🍲'},
    FoodCategory.groceries: {'label': 'Groceries', 'icon': '🛒'},
    FoodCategory.snacks: {'label': 'Snacks', 'icon': '🍿'},
    FoodCategory.beverages: {'label': 'Beverages', 'icon': '☕'},
    FoodCategory.bakedGoods: {'label': 'Baked Goods', 'icon': '🍞'},
    FoodCategory.other: {'label': 'Other', 'icon': '📦'},
  };

  @override
  void initState() {
    super.initState();
    final draft = context.read<PostFoodCubit>().state;
    _titleController = TextEditingController(text: draft.title);
    _descController = TextEditingController(text: draft.description);
    _priceController = TextEditingController(text: draft.price > 0 ? draft.price.toStringAsFixed(0) : '');
    _selectedCategory = draft.category;
    _isFree = draft.isFree;
    _selectedTags.addAll(draft.allergenTags);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_formKey.currentState!.validate()) {
      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category'), backgroundColor: AppColors.errorRed));
        return;
      }

      double price = 0.0;
      if (!_isFree) {
        price = double.tryParse(_priceController.text.replaceAll(',', '')) ?? 0.0;
        if (price <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid price'), backgroundColor: AppColors.errorRed));
          return;
        }
      }

      final currentDraft = context.read<PostFoodCubit>().state;
      context.read<PostFoodCubit>().updateDraft(
        currentDraft.copyWith(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          category: _selectedCategory,
          isFree: _isFree,
          price: price,
          allergenTags: _selectedTags.toList(),
        ),
      );

      context.push('/post/step3');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Post Food'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Progress pill
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(color: AppColors.offWhite, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(
                        value: 0.66,
                        backgroundColor: Colors.white,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text('Step 2 of 3', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
                ],
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Food Details', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const SizedBox(height: 24),

                    // Title
                    TextFormField(
                      controller: _titleController,
                      maxLength: 60,
                      decoration: InputDecoration(
                        labelText: 'Food Title',
                        hintText: 'e.g. Leftover rice and beans',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Title is required';
                        if (value.trim().length < 3) return 'Title must be at least 3 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description (optional)',
                        hintText: 'Add notes about allergens, packaging, or freshness...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Category
                    const Text('Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: FoodCategory.values.length,
                      itemBuilder: (context, index) {
                        final cat = FoodCategory.values[index];
                        final info = _categories[cat]!;
                        final isSelected = _selectedCategory == cat;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = cat),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.lightGreen : AppColors.white,
                              border: Border.all(color: isSelected ? AppColors.primaryGreen : Colors.grey[300]!, width: isSelected ? 2 : 1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(info['icon']!, style: const TextStyle(fontSize: 24)),
                                const SizedBox(height: 4),
                                Text(
                                  info['label']!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? AppColors.primaryGreen : AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    // Listing Type Toggle
                    const Text('Listing Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(value: false, label: Text('For Sale')),
                              ButtonSegment(value: true, label: Text('Free')),
                            ],
                            selected: {_isFree},
                            onSelectionChanged: (Set<bool> newSelection) {
                              setState(() {
                                _isFree = newSelection.first;
                                if (_isFree) _priceController.clear();
                              });
                            },
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                if (states.contains(WidgetState.selected)) return AppColors.primaryGreen;
                                return AppColors.white;
                              }),
                              foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                if (states.contains(WidgetState.selected)) return AppColors.white;
                                return AppColors.textDark;
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Price Input
                    if (!_isFree)
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Price',
                          prefixText: 'UGX ',
                          prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2)),
                        ),
                        validator: (value) {
                          if (!_isFree) {
                            if (value == null || value.isEmpty) return 'Price is required';
                            final val = double.tryParse(value.replaceAll(',', ''));
                            if (val == null || val <= 0) return 'Enter a valid price';
                          }
                          return null;
                        },
                      ),
                    
                    const SizedBox(height: 32),

                    // Allergen Tags
                    const Text('Allergen & Dietary Tags', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableTags.map((tag) {
                        final isSelected = _selectedTags.contains(tag);
                        return FilterChip(
                          label: Text(tag),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTags.add(tag);
                              } else {
                                _selectedTags.remove(tag);
                              }
                            });
                          },
                          selectedColor: AppColors.lightGreen,
                          checkmarkColor: AppColors.primaryGreen,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.primaryGreen : AppColors.textDark,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: isSelected ? AppColors.primaryGreen : Colors.grey[300]!),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Next: Pickup Details →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
