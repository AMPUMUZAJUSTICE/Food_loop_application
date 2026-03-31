import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../../../core/constants/app_colors.dart';
import '../bloc/post_food_cubit.dart';
import '../../domain/entities/post_food_draft.dart';

class PostFoodStep1Screen extends StatefulWidget {
  const PostFoodStep1Screen({super.key});

  @override
  State<PostFoodStep1Screen> createState() => _PostFoodStep1ScreenState();
}

class _PostFoodStep1ScreenState extends State<PostFoodStep1Screen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  Future<void> _pickImage(ImageSource source) async {
    context.pop(); // Close bottom sheet
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 100);
      if (pickedFile != null) {
        setState(() => _isProcessing = true);
        
        final tempDir = Directory.systemTemp;
        final targetPath = '${tempDir.path}/compress_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          pickedFile.path,
          targetPath,
          minWidth: 800,
          minHeight: 800,
          quality: 75,
        );
        
        if (compressedFile != null && mounted) {
           context.read<PostFoodCubit>().addImage(File(compressedFile.path));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Select Photo Source', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primaryGreen),
              title: const Text('Camera'),
              onTap: () => _pickImage(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primaryGreen),
              title: const Text('Gallery'),
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSlot(BuildContext context, int index, List<File> currentFiles) {
    if (index < currentFiles.length) {
      // Filled slot
      return Stack(
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: FileImage(currentFiles[index]),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => context.read<PostFoodCubit>().removeImage(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.errorRed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: AppColors.white),
              ),
            ),
          ),
        ],
      );
    } else if (index == currentFiles.length) {
      // Active empty slot ready for input
      return GestureDetector(
        onTap: _showImageSourceSheet,
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: AppColors.lightGreen.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primaryGreen, width: 2, style: BorderStyle.none), // Dashed border natively is harder, simulating via clean border here
            // Note: flutter lacks native dashed borders. A custom painter or dependency is needed.
            // Keeping it highly aesthetic with solid but thin borders
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo, color: AppColors.primaryGreen, size: 32),
              SizedBox(height: 8),
              Text('Add Photo', style: TextStyle(color: AppColors.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    } else {
      // Inactive empty slots
      return Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
      );
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
      ),
      body: BlocBuilder<PostFoodCubit, PostFoodDraft>(
        builder: (context, draft) {
          final hasPhoto = draft.imageFiles.isNotEmpty;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress pill
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.offWhite,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            value: 0.33,
                            backgroundColor: Colors.white,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text('Step 1 of 3', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add Photos of Your Food', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    const Text('Upload up to 3 clear photos (required)', style: TextStyle(color: AppColors.textGrey, fontSize: 14)),
                    const SizedBox(height: 32),
                    
                    // Photo Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(3, (index) => _buildPhotoSlot(context, index, draft.imageFiles)),
                    ),
                    
                    if (_isProcessing) ...[
                      const SizedBox(height: 32),
                      const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
                    ],
                  ],
                ),
              ),

              const Spacer(),
              
              // Bottom Action
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
                ),
                child: ElevatedButton(
                  onPressed: hasPhoto ? () => context.push('/post/step2') : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    disabledBackgroundColor: Colors.grey[300],
                    foregroundColor: AppColors.white,
                    disabledForegroundColor: Colors.grey[500],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Next: Add Details →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
