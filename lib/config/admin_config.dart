/// Admin yetkilendirme ayarları.
abstract class AdminConfig {
  /// Legacy admin password field kept for compatibility.
  /// Prefer email/role based admin authorization.
  static const String password = '';

  /// Sadece bu listedeki mailler "super admin" olur.
  /// Super admin: rol verebilir, izin dağıtabilir.
  static const Set<String> superAdminEmails = {
    'mariposa.u78@gmail.com',
  };

  /// Otomatik admin atanacak mailler (super admin olmayan adminler).
  static const Set<String> bootstrapAdminEmails = {};
}
