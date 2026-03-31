import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../feed/domain/entities/food_listing.dart';

class EditListingScreen extends StatefulWidget {
  final FoodListing listing;
  const EditListingScreen({super.key, required this.listing});

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.listing.title);
    _descController = TextEditingController(text: widget.listing.description);
    _priceController = TextEditingController(
      text: widget.listing.price > 0 ? widget.listing.price.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final double price = widget.listing.isFree 
          ? 0.0 
          : (double.tryParse(_priceController.text) ?? 0.0);

      await FirebaseFirestore.instance
          .collection('listings')
          .doc(widget.listing.id)
          .update({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'price': price,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing updated successfully'), backgroundColor: AppColors.primaryGreen),
        );
        Navigator.pop(context); // Go back
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Listing'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primaryGreen,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Title', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Food title'),
                      validator: (v) => v == null || v.isEmpty ? 'Title required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descController,
                      maxLines: 4,
                      decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Food description'),
                      validator: (v) => v == null || v.isEmpty ? 'Description required' : null,
                    ),
                    const SizedBox(height: 16),

                    if (!widget.listing.isFree) ...[
                      const Text('Price (UGX)', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(border: OutlineInputBorder(), prefixText: 'UGX '),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Price required';
                          if (double.tryParse(v) == null) return 'Invalid price';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _saveChanges,
                        child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
