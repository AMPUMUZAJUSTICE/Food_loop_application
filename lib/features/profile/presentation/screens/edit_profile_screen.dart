import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../bloc/profile_bloc.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ProfileBloc _profileBloc;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _deptController = TextEditingController();
  final TextEditingController _hostelController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  File? _selectedImage;
  String? _currentPhotoUrl;
  bool _removePhoto = false;

  @override
  void initState() {
    super.initState();
    _profileBloc = sl<ProfileBloc>();

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _profileBloc.add(LoadProfile(authState.user.uid));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _deptController.dispose();
    _hostelController.dispose();
    _bioController.dispose();
    _profileBloc.close();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _removePhoto = false;
      });
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primaryGreen),
                title: const Text('Camera'),
                onTap: () {
                  context.pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primaryGreen),
                title: const Text('Gallery'),
                onTap: () {
                  context.pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_selectedImage != null || (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty))
                ListTile(
                  leading: const Icon(Icons.delete, color: AppColors.errorRed),
                  title: const Text('Remove Photo', style: TextStyle(color: AppColors.errorRed)),
                  onTap: () {
                    context.pop();
                    setState(() {
                      _selectedImage = null;
                      _removePhoto = true;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _saveProfile() {
    if (!_formKey.currentState!.validate()) return;
    
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    _profileBloc.add(UpdateProfile(
      uid: authState.user.uid,
      displayName: _nameController.text.trim(),
      department: _deptController.text.trim(),
      hostel: _hostelController.text.trim(),
      bio: _bioController.text.trim(),
      newProfileImage: _selectedImage,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }
    final user = authState.user;

    return BlocProvider.value(
      value: _profileBloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.primaryGreen,
          elevation: 1,
        ),
        body: BlocConsumer<ProfileBloc, ProfileState>(
          listener: (context, state) {
            if (state is ProfileUpdated) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: AppColors.primaryGreen),
              );
              context.pop();
            } else if (state is ProfileError) {
               ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: AppColors.errorRed),
              );
            }
          },
          builder: (context, state) {
            if (state is ProfileInitial || state is ProfileLoading) {
               return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
            }
            if (state is ProfileLoaded && _nameController.text.isEmpty) {
              final user = state.user;
              _nameController.text = user.fullName;
              _deptController.text = user.department ?? '';
              _hostelController.text = user.hostel ?? '';
              _bioController.text = user.bio ?? '';
              _currentPhotoUrl = user.profileImageUrl;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // AVATAR SECTION
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 55,
                            backgroundColor: AppColors.lightGreen,
                            backgroundImage: _selectedImage != null
                                ? FileImage(_selectedImage!) as ImageProvider
                                : (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty && !_removePhoto
                                    ? CachedNetworkImageProvider(_currentPhotoUrl!)
                                    : null),
                            child: _selectedImage == null && (_currentPhotoUrl == null || _currentPhotoUrl!.isEmpty || _removePhoto)
                                ? Text(
                                    _nameController.text.isNotEmpty ? _nameController.text.substring(0, 1).toUpperCase() : '?',
                                    style: const TextStyle(fontSize: 40, color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _showImagePickerModal,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.white, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt, color: AppColors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // FORM FIELDS
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().length < 2) return 'Name must be at least 2 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _deptController,
                      decoration: const InputDecoration(
                        labelText: 'University Department',
                        hintText: 'e.g. Computer Science',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _hostelController,
                      decoration: const InputDecoration(
                        labelText: 'Hostel / Residential Area',
                        hintText: 'e.g. Block C, Hostel 4',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bioController,
                      maxLines: 3,
                      maxLength: 150,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        hintText: 'Tell others a bit about yourself',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // READ-ONLY INFO SECTION
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Verified Email', style: TextStyle(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(user.email ?? '', style: const TextStyle(fontSize: 16, color: AppColors.textDark)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // SAVE BUTTON
                    ElevatedButton(
                      onPressed: state is ProfileSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: state is ProfileSaving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                          : const Text('Save Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
