import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static User? get currentUser => FirebaseAuth.instance.currentUser;
  static String? get currentUid => FirebaseAuth.instance.currentUser?.uid;
}
