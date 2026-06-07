/// Модель пользователя приложения
class UserModel {
  final String uid;
  final String email;
  final String role; // 'parent' или 'child'
  final String? familyCode;
  final String? parentId;
  final String? childId;
  final String displayName;
  final String avatar;
  final int points;
  final int loginStreak;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    this.familyCode,
    this.parentId,
    this.childId,
    this.displayName = 'Пользователь',
    this.avatar = '👤',
    this.points = 0,
    this.loginStreak = 0,
  });

  bool get isParent => role == 'parent';
  bool get isChild => role == 'child';

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      role: data['role'] ?? 'child',
      familyCode: data['familyCode'],
      parentId: data['parentId'],
      childId: data['childId'],
      displayName: data['displayName'] ?? data['name'] ?? 'Пользователь',
      avatar: data['avatar'] ?? '👤',
      points: (data['points'] as num?)?.toInt() ?? 0,
      loginStreak: (data['loginStreak'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'role': role,
      'displayName': displayName,
      'avatar': avatar,
      'points': points,
      'loginStreak': loginStreak,
      if (familyCode != null) 'familyCode': familyCode,
      if (parentId != null) 'parentId': parentId,
      if (childId != null) 'childId': childId,
    };
  }
}
