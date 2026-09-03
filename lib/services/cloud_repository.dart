import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/partner_task.dart';

class PartnerProfile {
  final int partnerId;
  final String name;
  final String email;
  const PartnerProfile({required this.partnerId, required this.name, required this.email});
}

class CloudRepository {
  CloudRepository._();
  static final CloudRepository instance = CloudRepository._();
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<PartnerProfile?> profile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _db.collection('partners').doc(user.uid).get();
    final data = doc.data();
    if (data == null || data['active'] != true) return null;
    return PartnerProfile(
      partnerId: (data['partnerNumber'] as num).toInt(),
      name: data['name']?.toString() ?? 'Socio',
      email: data['email']?.toString() ?? user.email ?? '',
    );
  }

  Stream<List<PartnerTask>> streamTasks(int partnerNumber) {
    return _db
        .collection('partner_orders')
        .where('partnerNumber', isEqualTo: partnerNumber)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(PartnerTask.fromDoc).toList();
      list.sort((a, b) {
        final ad = a.updatedAt ?? DateTime.tryParse(a.createdAtLocal) ?? DateTime(2000);
        final bd = b.updatedAt ?? DateTime.tryParse(b.createdAtLocal) ?? DateTime(2000);
        return bd.compareTo(ad);
      });
      return list;
    });
  }

  Future<void> setStatus(PartnerTask task, String uiStatus) async {
    final cloudStatus = uiStatus == 'received' ? 'confirmed' : uiStatus;
    final data = <String, Object?>{
      'status': cloudStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (cloudStatus == 'confirmed') data['confirmedAt'] = FieldValue.serverTimestamp();
    if (cloudStatus == 'preparing') data['preparingAt'] = FieldValue.serverTimestamp();
    if (cloudStatus == 'ready') data['readyAt'] = FieldValue.serverTimestamp();
    if (cloudStatus == 'delivered') data['deliveredAt'] = FieldValue.serverTimestamp();
    await _db.collection('partner_orders').doc(task.id).update(data);
  }

  Future<void> reportIssue(PartnerTask task, String issue, String note) async {
    await _db.collection('partner_orders').doc(task.id).update({
      'issue': issue,
      'issueNote': note,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> registerNotifications(PartnerProfile profile) async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    final user = _auth.currentUser;
    if (user == null) return;

    Future<void> save(String token) async {
      await _db.collection('partner_devices').doc(user.uid).set({
        'token': token,
        'uid': user.uid,
        'partnerNumber': profile.partnerId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final token = await messaging.getToken();
    if (token != null) await save(token);
    FirebaseMessaging.instance.onTokenRefresh.listen(save);
  }

  Future<void> signOut() => _auth.signOut();
}
