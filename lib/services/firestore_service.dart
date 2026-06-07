import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class FirestoreService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser!.uid;

  static const defaultRewards = [
    {'name': '🍿 Поход в кино', 'cost': 100, 'bought': false},
    {'name': '🍕 Пицца', 'cost': 50, 'bought': false},
    {'name': '🎮 Игры 1 час', 'cost': 30, 'bought': false},
  ];

  Future<String> getFamilyCode(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) return doc.data()?['familyCode'] as String? ?? '';
    return '';
  }

  Future<List<Map<String, dynamic>>> getChildrenList(String parentId) async {
    final doc = await _firestore.collection('users').doc(parentId).get();
    if (doc.exists) {
      final list = doc.data()?['childrenList'] as List?;
      if (list != null) {
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }
    return [];
  }

  Future<String> addChild(
      String parentId, String name, String avatar, String email) async {
    final childRef = await _firestore.collection('children').add({
      'name': name,
      'avatar': avatar,
      'email': email,
      'points': 0,
      'tasks': [],
      'rewards': defaultRewards,
      'lastLoginDate': '',
      'loginStreak': 0,
    });
    final childrenList = await getChildrenList(parentId);
    childrenList.add(
        {'id': childRef.id, 'name': name, 'avatar': avatar, 'email': email});
    await _firestore
        .collection('users')
        .doc(parentId)
        .update({'childrenList': childrenList});
    return childRef.id;
  }

  Future<void> initFirstChild(String parentId, String childId) async {
    final doc = await _firestore.collection('children').doc(childId).get();
    if (!doc.exists) {
      await _firestore.collection('children').doc(childId).set({
        'points': 0,
        'tasks': [],
        'rewards': defaultRewards,
        'lastLoginDate': '',
        'loginStreak': 0,
        'email': '',
        'name': 'Ребёнок',
        'avatar': '🧒',
      });
    }
    final childrenList = await getChildrenList(parentId);
    if (childrenList.isEmpty) {
      await _firestore.collection('users').doc(parentId).update({
        'childrenList': [
          {'id': childId, 'name': 'Ребёнок', 'avatar': '🧒', 'email': ''}
        ]
      });
    }
  }

  Future<String?> getChildIdByEmail(String parentId, String email) async {
    final childrenList = await getChildrenList(parentId);
    for (final child in childrenList) {
      if (child['email'] == email) return child['id'] as String?;
    }
    return null;
  }

  // ===== СИНХРОНИЗАЦИЯ ПРОФИЛЯ РЕБЕНКА =====
  Future<void> updateChildProfileAsChild(String childId, String currentUserId,
      String parentId, String name, String avatar) async {
    // 1. Обновляем имя и аватар в документе заданий ребенка
    await _firestore
        .collection('children')
        .doc(childId)
        .update({'name': name, 'avatar': avatar});

    // 2. Обновляем имя в самом аккаунте юзера (чтобы чат подхватил новое имя)
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .update({'displayName': name, 'avatar': avatar});

    // 3. Синхронизируем это имя с аккаунтом родителя, чтобы родитель тоже видел изменения
    if (parentId.isNotEmpty) {
      final parentDoc =
          await _firestore.collection('users').doc(parentId).get();
      if (parentDoc.exists) {
        List childrenList = parentDoc.data()?['childrenList'] ?? [];
        for (int i = 0; i < childrenList.length; i++) {
          if (childrenList[i]['id'] == childId) {
            childrenList[i]['name'] = name;
            childrenList[i]['avatar'] = avatar;
            break;
          }
        }
        await _firestore
            .collection('users')
            .doc(parentId)
            .update({'childrenList': childrenList});
      }
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> childDocStream(
      String childId) {
    return _firestore.collection('children').doc(childId).snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getChildDoc(
      String childId) async {
    return await _firestore.collection('children').doc(childId).get();
  }

  Future<void> updateTasks(
      String childId, List<Map<String, dynamic>> tasks) async {
    await _firestore
        .collection('children')
        .doc(childId)
        .update({'tasks': tasks});
  }

  Future<void> updateRewards(
      String childId, List<Map<String, dynamic>> rewards) async {
    await _firestore
        .collection('children')
        .doc(childId)
        .update({'rewards': rewards});
  }

  Future<void> updatePoints(String childId, int points) async {
    await _firestore
        .collection('children')
        .doc(childId)
        .update({'points': points});
  }

  Future<void> updateDailyBonus(String childId,
      {required int points,
      required String lastLoginDate,
      required int streak}) async {
    await _firestore.collection('children').doc(childId).update({
      'points': points,
      'lastLoginDate': lastLoginDate,
      'loginStreak': streak,
    });
  }

  Future<String> uploadPhoto(String childId, Uint8List fileBytes) async {
    const apiKey = '0e53bd55177746296f5b6a6f0082ab4e';
    final uri = Uri.parse('https://api.imgbb.com/1/upload');
    final base64Image = base64Encode(fileBytes);

    final response = await http.post(uri, body: {
      'key': apiKey,
      'image': base64Image,
    });

    final json = jsonDecode(response.body);
    if (json['success'] == true) {
      return json['data']['url'] as String? ?? '';
    } else {
      final errorMsg =
          json['error']?['message'] ?? 'Неизвестная ошибка сервера';
      throw Exception('Ошибка ImgBB: $errorMsg');
    }
  }

  Future<void> signOut() => _auth.signOut();
}
