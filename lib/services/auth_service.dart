import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Вход
  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  /// Регистрация
  Future<UserCredential> signUp(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  /// Выход
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Найти родителя по коду семьи
  Future<String?> findParentByFamilyCode(String code) async {
    final doc = await _firestore.collection('family_codes').doc(code).get();
    if (doc.exists) return doc.data()?['parentId'] as String?;
    return null;
  }

  /// Сохранить код семьи
  Future<void> saveFamilyCode(String code, String parentId) async {
    await _firestore
        .collection('family_codes')
        .doc(code)
        .set({'parentId': parentId});
  }
}
