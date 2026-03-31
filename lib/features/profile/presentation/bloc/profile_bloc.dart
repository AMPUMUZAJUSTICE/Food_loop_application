import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../data/profile_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/domain/entities/app_user.dart';

// EVENTS
abstract class ProfileEvent extends Equatable {
  const ProfileEvent();
  @override
  List<Object?> get props => [];
}

class LoadProfile extends ProfileEvent {
  final String uid;
  const LoadProfile(this.uid);
  @override
  List<Object?> get props => [uid];
}

class UpdateProfile extends ProfileEvent {
  final String uid;
  final String displayName;
  final String? department;
  final String? hostel;
  final String? bio;
  final File? newProfileImage;

  const UpdateProfile({
    required this.uid,
    required this.displayName,
    this.department,
    this.hostel,
    this.bio,
    this.newProfileImage,
  });

  @override
  List<Object?> get props => [uid, displayName, department, hostel, bio, newProfileImage];
}

// STATES
abstract class ProfileState extends Equatable {
  const ProfileState();
  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}
class ProfileLoading extends ProfileState {}
class ProfileSaving extends ProfileState {}
class ProfileUpdated extends ProfileState {}
class ProfileLoaded extends ProfileState {
  final AppUser user;
  const ProfileLoaded(this.user);
  @override
  List<Object?> get props => [user];
}
class ProfileError extends ProfileState {
  final String message;
  const ProfileError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLOC
@injectable
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository _repository;
  final AuthBloc _authBloc;

  ProfileBloc(this._repository, this._authBloc) : super(ProfileInitial()) {
    on<LoadProfile>(_onLoadProfile);
    on<UpdateProfile>(_onUpdateProfile);
  }

  Future<void> _onLoadProfile(LoadProfile event, Emitter<ProfileState> emit) async {
    emit(ProfileLoading());
    try {
      final user = await _repository.getUserProfile(event.uid);
      emit(ProfileLoaded(user));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> _onUpdateProfile(UpdateProfile event, Emitter<ProfileState> emit) async {
    emit(ProfileSaving());
    try {
      String? imageUrl;
      
      if (event.newProfileImage != null) {
        imageUrl = await _repository.uploadProfileImage(event.uid, event.newProfileImage!);
      }

      final Map<String, dynamic> updates = {
        'fullName': event.displayName,
        'department': event.department,
        'hostel': event.hostel,
        'bio': event.bio,
      };

      if (imageUrl != null) {
        updates['profileImageUrl'] = imageUrl;
      }

      await _repository.updateProfile(event.uid, updates);
      emit(ProfileUpdated());
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }
}
