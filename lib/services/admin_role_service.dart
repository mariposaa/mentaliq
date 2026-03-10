import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/admin_config.dart';
import 'auth_service.dart';

enum AppUserRole { user, admin }

enum AdminPermission {
  manageDailyQuestions,
  moderateForum,
  manageInspirationPool,
  viewMetrics,
}

class AdminUserPreview {
  final String uid;
  final String name;
  final String email;
  final AppUserRole role;
  final bool isSuperAdmin;
  final Set<AdminPermission> permissions;
  final DateTime? lastSeenAt;
  final bool isAnonymous;

  const AdminUserPreview({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.isSuperAdmin,
    required this.permissions,
    required this.lastSeenAt,
    required this.isAnonymous,
  });

  factory AdminUserPreview.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final profile = Map<String, dynamic>.from(data['profile'] ?? const {});
    final ts = data['lastSeenAt'];
    return AdminUserPreview(
      uid: doc.id,
      name: (profile['name'] ?? 'Kullanıcı').toString(),
      email: (profile['email'] ?? '').toString(),
      role: AdminRoleService.roleFromString(data['role']?.toString()),
      isSuperAdmin: data['isSuperAdmin'] == true,
      permissions:
          AdminRoleService.permissionsFromMap(data['adminPermissions']),
      lastSeenAt: ts is Timestamp ? ts.toDate() : null,
      isAnonymous: (profile['isAnonymous'] ?? false) == true,
    );
  }
}

class AdminRoleService {
  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  static const String _roleField = 'role';
  static const String _permissionsField = 'adminPermissions';
  static const Map<AdminPermission, String> _permissionKeyMap = {
    AdminPermission.manageDailyQuestions: 'manageDailyQuestions',
    AdminPermission.moderateForum: 'moderateForum',
    AdminPermission.manageInspirationPool: 'manageInspirationPool',
    AdminPermission.viewMetrics: 'viewMetrics',
  };

  static String permissionKey(AdminPermission permission) =>
      _permissionKeyMap[permission]!;

  static AdminPermission? permissionFromKey(String key) {
    for (final entry in _permissionKeyMap.entries) {
      if (entry.value == key) return entry.key;
    }
    return null;
  }

  static Map<String, bool> permissionsToMap(Set<AdminPermission> permissions) {
    return {
      for (final entry in _permissionKeyMap.entries)
        entry.value: permissions.contains(entry.key),
    };
  }

  static Set<AdminPermission> permissionsFromMap(dynamic raw) {
    if (raw is! Map) return {};
    final map = Map<String, dynamic>.from(raw);
    final result = <AdminPermission>{};
    for (final entry in map.entries) {
      final perm = permissionFromKey(entry.key);
      if (perm != null && entry.value == true) {
        result.add(perm);
      }
    }
    return result;
  }

  static bool isSuperAdminEmail(String? email) {
    return false;
  }

  static AppUserRole roleFromString(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'admin':
        return AppUserRole.admin;
      default:
        return AppUserRole.user;
    }
  }

  static String roleToString(AppUserRole role) {
    switch (role) {
      case AppUserRole.admin:
        return 'admin';
      case AppUserRole.user:
        return 'user';
    }
  }

  static Future<AppUserRole> getCurrentUserRole() async {
    return (await isCurrentUserAdmin()) ? AppUserRole.admin : AppUserRole.user;
  }

  static Future<bool> isCurrentUserAdmin() async {
    final email = AuthService.userEmail;
    if (email == null || email.trim().isEmpty || AuthService.isAnonymous) {
      return false;
    }
    try {
      final doc = await AuthService.firestore
          .collection('admin_emails')
          .doc(_normalizeEmail(email))
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('AdminRoleService admin check error: $e');
      return false;
    }
  }

  static bool _isOwnerAdminEmail(String? email) {
    if (email == null || email.trim().isEmpty) return false;
    final normalized = _normalizeEmail(email);
    return AdminConfig.superAdminEmails
        .map((e) => _normalizeEmail(e))
        .contains(normalized);
  }

  static Future<bool> isCurrentUserOwnerAdmin() async {
    return _isOwnerAdminEmail(AuthService.userEmail);
  }

  static Future<bool> isEmailAdmin(String email) async {
    final normalized = _normalizeEmail(email);
    if (normalized.isEmpty || !normalized.contains('@')) return false;
    try {
      final doc = await AuthService.firestore
          .collection('admin_emails')
          .doc(normalized)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('AdminRoleService isEmailAdmin error: $e');
      return false;
    }
  }

  static Future<void> addAdminEmail(String email) async {
    final normalized = _normalizeEmail(email);
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw Exception('Geçerli e-posta girin.');
    }
    final canManage = await isCurrentUserOwnerAdmin();
    if (!canManage) {
      throw Exception('Bu işlem için sadece kurucu admin yetkili.');
    }
    await AuthService.firestore.collection('admin_emails').doc(normalized).set({
      'email': normalized,
      'enabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': AuthService.userId,
    }, SetOptions(merge: true));
  }

  static Future<void> removeAdminEmail(String email) async {
    final normalized = _normalizeEmail(email);
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw Exception('Geçerli e-posta girin.');
    }
    final canManage = await isCurrentUserOwnerAdmin();
    if (!canManage) {
      throw Exception('Bu işlem için sadece kurucu admin yetkili.');
    }
    await AuthService.firestore
        .collection('admin_emails')
        .doc(normalized)
        .delete();
  }

  static Future<bool> isCurrentUserSuperAdmin() async {
    return isCurrentUserAdmin();
  }

  static Future<bool> hasPermission(AdminPermission permission) async {
    return isCurrentUserAdmin();
  }

  static Future<Set<AdminPermission>> getCurrentUserPermissions() async {
    if (await isCurrentUserAdmin()) {
      return AdminPermission.values.toSet();
    }
    return {};
  }

  static Set<AdminPermission> defaultPermissionsForRole(AppUserRole role) {
    if (role == AppUserRole.admin) {
      return {AdminPermission.manageDailyQuestions};
    }
    return {};
  }

  static Stream<bool> watchIsCurrentUserAdmin() {
    final email = AuthService.userEmail;
    if (email == null || email.trim().isEmpty || AuthService.isAnonymous) {
      return Stream.value(false);
    }
    return AuthService.firestore
        .collection('admin_emails')
        .doc(_normalizeEmail(email))
        .snapshots()
        .map((doc) => doc.exists);
  }

  static bool shouldBootstrapAdminForCurrentUser({
    required String? email,
    required bool isAnonymous,
  }) {
    return false;
  }

  static Future<void> setUserRole({
    required String targetUserId,
    required AppUserRole role,
    bool requireCurrentSuperAdmin = true,
    Set<AdminPermission>? permissions,
  }) async {
    if (targetUserId.trim().isEmpty) {
      throw Exception('Geçersiz kullanıcı.');
    }

    if (requireCurrentSuperAdmin) {
      final isSuperAdmin = await isCurrentUserSuperAdmin();
      if (!isSuperAdmin) {
        throw Exception('Bu işlem için super admin yetkisi gerekli.');
      }
    }

    final finalPermissions = permissions ?? defaultPermissionsForRole(role);
    await AuthService.firestore.collection('users').doc(targetUserId).set({
      _roleField: roleToString(role),
      _permissionsField: permissionsToMap(finalPermissions),
      'roleUpdatedAt': FieldValue.serverTimestamp(),
      'roleUpdatedBy': AuthService.userId,
    }, SetOptions(merge: true));
  }

  static Future<void> setAdminPermissions({
    required String targetUserId,
    required Set<AdminPermission> permissions,
  }) async {
    final isSuperAdmin = await isCurrentUserSuperAdmin();
    if (!isSuperAdmin) {
      throw Exception('Bu işlem için super admin yetkisi gerekli.');
    }
    if (targetUserId.trim().isEmpty) {
      throw Exception('Geçersiz kullanıcı.');
    }
    await AuthService.firestore.collection('users').doc(targetUserId).set({
      _permissionsField: permissionsToMap(permissions),
      'permissionsUpdatedAt': FieldValue.serverTimestamp(),
      'permissionsUpdatedBy': AuthService.userId,
    }, SetOptions(merge: true));
  }

  static Future<List<AdminUserPreview>> getRecentUsers({int limit = 40}) async {
    final isAdmin = await isCurrentUserAdmin();
    if (!isAdmin) throw Exception('Bu işlem için admin yetkisi gerekli.');

    final snapshot = await AuthService.firestore
        .collection('users')
        .orderBy('lastSeenAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(AdminUserPreview.fromDoc).toList();
  }

  static Future<AdminUserPreview?> getUserById(String uid) async {
    final isAdmin = await isCurrentUserAdmin();
    if (!isAdmin) throw Exception('Bu işlem için admin yetkisi gerekli.');

    final doc =
        await AuthService.firestore.collection('users').doc(uid.trim()).get();
    if (!doc.exists) return null;
    return AdminUserPreview.fromDoc(doc);
  }
}
