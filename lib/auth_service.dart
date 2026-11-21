import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppMember {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String accountStatus;
  final String approvalStatus;
  final bool mustChangePassword;
  final bool locked;
  final String? lockoutReason;
  final Timestamp? lockoutAt;
  final Timestamp? registeredAt;
  final Timestamp? lastLoginAt;

  const AppMember({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.accountStatus,
    required this.approvalStatus,
    required this.mustChangePassword,
    required this.locked,
    this.lockoutReason,
    this.lockoutAt,
    this.registeredAt,
    this.lastLoginAt,
  });

  factory AppMember.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return AppMember(
      uid: snapshot.id,
      name: (data['name'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      role: (data['role'] ?? 'member') as String,
      accountStatus: (data['accountStatus'] ?? 'active') as String,
      approvalStatus: (data['approvalStatus'] ?? 'approved') as String,
      mustChangePassword: (data['mustChangePassword'] ?? false) as bool,
      locked: (data['locked'] ?? false) as bool,
      lockoutReason: data['lockoutReason'] as String?,
      lockoutAt: data['lockoutAt'] as Timestamp?,
      registeredAt: data['registeredAt'] as Timestamp?,
      lastLoginAt: data['lastLoginAt'] as Timestamp?,
    );
  }

  bool get isAdmin => role == 'administrator';
  bool get canAccess =>
      accountStatus == 'active' && approvalStatus == 'approved' && !locked;
}

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  User? get currentUser => _auth.currentUser;

  Future<AppMember?> getCurrentMember({bool refreshClaims = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    if (refreshClaims) {
      await user.getIdToken(true);
    }
    final snapshot =
        await _db.collection('users').doc(user.uid).get();
    if (!snapshot.exists) return null;
    return AppMember.fromSnapshot(snapshot);
  }

  Stream<AppMember?> watchCurrentMember() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) =>
            snapshot.exists ? AppMember.fromSnapshot(snapshot) : null);
  }

  Future<bool> isAdministrator() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final token = await user.getIdTokenResult();
    if (token.claims?['role'] == 'administrator') return true;
    final member = await getCurrentMember();
    return member?.isAdmin ?? false;
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> recordLoginActivity(String uid) async {
    await _db.collection('users').doc(uid).set({
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> createMember({
    required String name,
    required String email,
    required String role,
  }) async {
    final result = await _functions.httpsCallable('createMember').call({
      'name': name,
      'email': email,
      'role': role,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> updateMember({
    required String uid,
    required Map<String, dynamic> updates,
  }) async {
    final memberSnapshot = await _db.collection('users').doc(uid).get();
    final primaryAdmin =
        (memberSnapshot.data()?['primaryAdmin'] ?? false) == true;
    if (primaryAdmin &&
        ((updates['role'] != null && updates['role'] != 'administrator') ||
            updates['accountStatus'] == 'suspended' ||
            updates['accountStatus'] == 'rejected')) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'The primary administrator cannot be demoted or deactivated.',
      );
    }
    final allowedKeys = {
      'name',
      'role',
      'accountStatus',
      'approvalStatus',
      'locked',
    };
    final safeUpdates = <String, dynamic>{
      for (final entry in updates.entries)
        if (allowedKeys.contains(entry.key)) entry.key: entry.value,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!await isAdministrator()) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Administrator access required.',
      );
    }
    await _db.collection('users').doc(uid).update(safeUpdates);
    await _db.collection('audit').add({
      'actorUid': _auth.currentUser?.uid,
      'action': 'update_member',
      'targetUid': uid,
      'details': {
        for (final entry in updates.entries)
          if (allowedKeys.contains(entry.key)) entry.key: entry.value,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resetMemberLockout(String uid) async {
    if (!await isAdministrator()) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Administrator access required.',
      );
    }
    await _db.collection('users').doc(uid).update({
      'locked': false,
      'lockoutReason': FieldValue.delete(),
      'lockoutAt': FieldValue.delete(),
      'failedAttempts': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resetMemberPassword(String uid) async {
    if (!await isAdministrator()) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Administrator access required.',
      );
    }
    final snapshot = await _db.collection('users').doc(uid).get();
    final email = snapshot.data()?['email'] as String?;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'This member has no valid email address.',
      );
    }
    await _auth.sendPasswordResetEmail(email: email);
    await _db.collection('users').doc(uid).update({
      'mustChangePassword': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> completeFirstLoginPasswordChange() async {
    await _functions
        .httpsCallable('completeFirstLoginPasswordChange')
        .call();
  }

  Future<void> deleteMember(String uid) async {
    if (!await isAdministrator()) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Administrator access required.',
      );
    }
    await _db.collection('users').doc(uid).update({
      'accountStatus': 'suspended',
      'approvalStatus': 'rejected',
      'locked': true,
      'lockoutReason': 'Deactivated by administrator',
      'lockoutAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
