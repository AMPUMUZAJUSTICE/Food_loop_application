import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  final String uid;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String? profileImageUrl;
  final String? department;
  final String? hostel;
  final String? bio;
  final double averageRating;
  final int totalRatings;
  final double walletBalance;
  final bool isVerified;
  final DateTime createdAt;
  final String? fcmToken;

  const AppUser({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.profileImageUrl,
    this.department,
    this.hostel,
    this.bio,
    this.averageRating = 0.0,
    this.totalRatings = 0,
    this.walletBalance = 0.0,
    required this.isVerified,
    required this.createdAt,
    this.fcmToken,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String,
      profileImageUrl: json['profileImageUrl'] as String?,
      department: json['department'] as String?,
      hostel: json['hostel'] as String?,
      bio: json['bio'] as String?,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: json['totalRatings'] as int? ?? 0,
      walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0.0,
      isVerified: json['isVerified'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      fcmToken: json['fcmToken'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      if (department != null) 'department': department,
      if (hostel != null) 'hostel': hostel,
      if (bio != null) 'bio': bio,
      'averageRating': averageRating,
      'totalRatings': totalRatings,
      'walletBalance': walletBalance,
      'isVerified': isVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      if (fcmToken != null) 'fcmToken': fcmToken,
    };
  }

  AppUser copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? profileImageUrl,
    String? department,
    String? hostel,
    String? bio,
    double? averageRating,
    int? totalRatings,
    double? walletBalance,
    bool? isVerified,
    DateTime? createdAt,
    String? fcmToken,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      department: department ?? this.department,
      hostel: hostel ?? this.hostel,
      bio: bio ?? this.bio,
      averageRating: averageRating ?? this.averageRating,
      totalRatings: totalRatings ?? this.totalRatings,
      walletBalance: walletBalance ?? this.walletBalance,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }

  @override
  List<Object?> get props => [
        uid, fullName, email, phoneNumber, profileImageUrl, department,
        hostel, bio, averageRating, totalRatings, walletBalance, isVerified,
        createdAt, fcmToken,
      ];
}
