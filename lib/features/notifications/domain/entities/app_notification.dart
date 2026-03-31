import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class AppNotification extends Equatable {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final String? deepLink;
  final Map<String, dynamic> data;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.deepLink,
    required this.data,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: json['type'] as String,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      deepLink: json['deepLink'] as String?,
      data: json['data'] != null ? Map<String, dynamic>.from(json['data'] as Map) : {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      if (deepLink != null) 'deepLink': deepLink,
      'data': data,
    };
  }

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    bool? isRead,
    DateTime? createdAt,
    String? deepLink,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      deepLink: deepLink ?? this.deepLink,
      data: data ?? this.data,
    );
  }

  @override
  List<Object?> get props => [id, title, body, type, isRead, createdAt, deepLink, data];
}
