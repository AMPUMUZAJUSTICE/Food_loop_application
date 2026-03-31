import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../domain/entities/post_food_draft.dart';

@lazySingleton
class PostFoodCubit extends Cubit<PostFoodDraft> {
  PostFoodCubit() : super(const PostFoodDraft());

  void updateDraft(PostFoodDraft newDraft) {
    emit(newDraft);
  }

  void addImage(File file) {
    if (state.imageFiles.length < 3) {
      final updatedFiles = List<File>.from(state.imageFiles)..add(file);
      emit(state.copyWith(imageFiles: updatedFiles));
    }
  }

  void removeImage(int index) {
    if (index >= 0 && index < state.imageFiles.length) {
      final updatedFiles = List<File>.from(state.imageFiles)..removeAt(index);
      emit(state.copyWith(imageFiles: updatedFiles));
    }
  }

  void resetDraft() {
    emit(const PostFoodDraft());
  }
}
