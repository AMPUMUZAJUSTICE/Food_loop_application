import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../feed/domain/entities/food_listing.dart';
import '../bloc/post_food_cubit.dart';

class PostFoodStep3Screen extends StatefulWidget {
  const PostFoodStep3Screen({super.key});

  @override
  State<PostFoodStep3Screen> createState() => _PostFoodStep3ScreenState();
}

class _PostFoodStep3ScreenState extends State<PostFoodStep3Screen> {
  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(0.6065, 30.6580); // MUST Campus
  String _resolvedAddress = 'Resolving location...';
  
  late DateTime _pickupStart;
  late DateTime _pickupEnd;
  
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _pickupStart = now.add(const Duration(minutes: 30));
    _pickupEnd = now.add(const Duration(hours: 4));
    _resolveAddress(_selectedLocation);
  }

  Future<void> _resolveAddress(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(location.latitude, location.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _resolvedAddress = '${place.name}, ${place.locality}, ${place.country}'.replaceAll(RegExp(r'^, '), '');
        });
      }
    } catch (e) {
      if (mounted) setState(() => _resolvedAddress = 'Unknown Location');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }
  
  void _onCameraMove(CameraPosition position) {
    _selectedLocation = position.target;
  }
  
  void _onCameraIdle() {
    _resolveAddress(_selectedLocation);
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled.')));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied')));
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')));
      return;
    } 

    final position = await Geolocator.getCurrentPosition();
    final newLocation = LatLng(position.latitude, position.longitude);
    
    setState(() => _selectedLocation = newLocation);
    _mapController?.animateCamera(CameraUpdate.newLatLng(newLocation));
    _resolveAddress(newLocation);
  }

  Future<void> _selectDateTime(BuildContext context, bool isStart) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: isStart ? _pickupStart : _pickupEnd,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryGreen),
        ),
        child: child!,
      ),
    );
    if (date != null && mounted) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStart ? _pickupStart : _pickupEnd),
        builder: (context, child) => Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primaryGreen),
          ),
          child: child!,
        ),
      );
      if (time != null) {
        final selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        setState(() {
          if (isStart) {
            _pickupStart = selectedDateTime;
            if (_pickupEnd.isBefore(_pickupStart)) {
              _pickupEnd = _pickupStart.add(const Duration(hours: 1));
            }
          } else {
            if (selectedDateTime.isAfter(_pickupStart)) {
              _pickupEnd = selectedDateTime;
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End time must be after start time')));
            }
          }
        });
      }
    }
  }

  Future<void> _publishListing() async {
    if (_pickupStart.isBefore(DateTime.now().subtract(const Duration(minutes: 5)))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pickup Start Time must be in the future')));
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthAuthenticated) {
        throw Exception('User not authenticated');
      }
      final user = authState.user;
      final draft = context.read<PostFoodCubit>().state;
      
      // Fetch user's full name from Firestore because Auth displayName might be null
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final fullName = userDoc.data()?['fullName'] as String? ?? 'User';
      
      final storage = FirebaseStorage.instance;
      final uuid = const Uuid();
      List<String> uploadedUrls = [];
      
      for (File image in draft.imageFiles) {
        final ext = image.path.split('.').last;
        final fileName = '${uuid.v4()}.$ext';
        final ref = storage.ref().child('listings/${user.uid}/$fileName');
        
        final bytes = await image.readAsBytes();
        final uploadTask = await ref.putData(bytes).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception("Upload timed out!"),
        );
        
        final url = await uploadTask.ref.getDownloadURL();
        uploadedUrls.add(url);
      }
      
      final firestoreRef = FirebaseFirestore.instance.collection('listings').doc();
      final listing = FoodListing(
        id: firestoreRef.id,
        sellerId: user.uid,
        sellerName: fullName,
        sellerRating: 0.0,
        sellerImageUrl: user.photoURL,
        title: draft.title,
        category: draft.category!,
        description: draft.description.isNotEmpty ? draft.description : null,
        isFree: draft.isFree,
        price: draft.price,
        imageUrls: uploadedUrls,
        allergenTags: draft.allergenTags,
        pickupLocation: PickupLocation(
          latitude: _selectedLocation.latitude,
          longitude: _selectedLocation.longitude,
          address: _resolvedAddress,
        ),
        pickupWindowStart: _pickupStart,
        pickupWindowEnd: _pickupEnd,
        status: ListingStatus.active,
        createdAt: DateTime.now(),
      );
      
      await firestoreRef.set(listing.toJson());
      if (mounted) context.read<PostFoodCubit>().resetDraft();
      
      if (mounted) {
         context.go('/feed');
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your listing is live! 🎉'), backgroundColor: AppColors.primaryGreen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to publish: $e'), backgroundColor: AppColors.errorRed));
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.read<PostFoodCubit>().state;

    return Stack(
      children: [
        Scaffold(
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
                            value: 1.0,
                            backgroundColor: Colors.white,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text('Step 3 of 3', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pickup Details', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      const SizedBox(height: 24),

                      // MAP 
                      const Text('Pickup Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      const SizedBox(height: 12),
                      Container(
                        height: 220,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: _selectedLocation,
                                  zoom: 15,
                                ),
                                onMapCreated: _onMapCreated,
                                onCameraMove: _onCameraMove,
                                onCameraIdle: _onCameraIdle,
                                zoomControlsEnabled: false,
                                myLocationEnabled: true,
                                myLocationButtonEnabled: false,
                              ),
                              const Icon(Icons.location_on, size: 40, color: AppColors.errorRed),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: AppColors.textGrey, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _resolvedAddress,
                              style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _getUserLocation,
                          icon: const Icon(Icons.my_location),
                          label: const Text('Use My Current Location'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryGreen,
                            side: const BorderSide(color: AppColors.primaryGreen),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // TIME WINDOW
                      const Text('Pickup Time Window', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildTimePickerTile(
                              title: 'Pickup From',
                              dateTime: _pickupStart,
                              onTap: () => _selectDateTime(context, true),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTimePickerTile(
                              title: 'Pickup Until',
                              dateTime: _pickupEnd,
                              onTap: () => _selectDateTime(context, false),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),

                      // FOOD SAFETY
                      if (draft.category == FoodCategory.cookedMeal)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.warningAmber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.warningAmber),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: AppColors.warningAmber),
                                  SizedBox(width: 8),
                                  Expanded(child: Text('⚠️ Cooked food must be stored safely.', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text('Please ensure the items are packaged securely and kept at safe temperatures.', style: TextStyle(fontSize: 14)),
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: () => context.push('/settings/safety'),
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                child: const Text('Read our Food Safety Guidelines', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 48), // Padding below content
                    ],
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
                        onPressed: _isPublishing ? null : _publishListing,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Publish Listing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        if (_isPublishing)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryGreen),
                  SizedBox(height: 16),
                  Text('Uploading highly compressed files...', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTimePickerTile({required String title, required DateTime dateTime, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            const SizedBox(height: 4),
            Text(DateFormat('MMM d, h:mm a').format(dateTime), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          ],
        ),
      ),
    );
  }
}
