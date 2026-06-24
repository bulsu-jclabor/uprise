import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreCollections {
  FirestoreCollections._();

  static CollectionReference get letterRequests =>
      FirebaseFirestore.instance.collection('letter_requests');

  static CollectionReference get savedSignatures =>
      FirebaseFirestore.instance.collection('saved_signatures');
}
