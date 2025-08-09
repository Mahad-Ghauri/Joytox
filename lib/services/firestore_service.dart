import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveUserData({
    required String uid,
    required String email,
    required String name,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'email': email,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Firestore error: $e');
    }
  }
}
