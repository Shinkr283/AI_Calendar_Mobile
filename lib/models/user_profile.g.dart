// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => UserProfile(
  email: json['email'] as String,
  name: json['name'] as String,
  profileImageUrl: json['profileImageUrl'] as String?,
  phoneNumber: json['phoneNumber'] as String?,
  mbtiType: json['mbtiType'] as String?,
  preferences: json['preferences'] as Map<String, dynamic>,
  timezone: json['timezone'] as String,
  language: json['language'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$UserProfileToJson(UserProfile instance) =>
    <String, dynamic>{
      'email': instance.email,
      'name': instance.name,
      'profileImageUrl': instance.profileImageUrl,
      'phoneNumber': instance.phoneNumber,
      'mbtiType': instance.mbtiType,
      'preferences': instance.preferences,
      'timezone': instance.timezone,
      'language': instance.language,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
