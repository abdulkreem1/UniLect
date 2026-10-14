import '../features/academic/domain/academic_models.dart';
import '../features/content/domain/content.dart';

/// All route paths in one place.
abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const deviceBlocked = '/device-blocked';

  /// Target of the emailed reset link `unilect://app/reset-password?uid&token`.
  static const resetPassword = '/reset-password';

  /// Mandatory password change after an admin-set password.
  static const changePassword = '/change-password';

  // Student
  static const studentBrowse = '/s/browse';
  static const studentSearch = '/s/search';
  static const studentFavorites = '/s/favorites';
  static const studentNotifications = '/s/notifications';
  static const studentProfile = '/s/profile';

  static String faculties(String universityId, String title) =>
      '$studentBrowse/u/$universityId?t=${Uri.encodeComponent(title)}';
  static String years(String facultyId, String title) =>
      '$studentBrowse/f/$facultyId?t=${Uri.encodeComponent(title)}';
  static String subjects(String facultyId, String yearId, String title) =>
      '$studentBrowse/f/$facultyId/y/$yearId?t=${Uri.encodeComponent(title)}';
  static String subject(String subjectId, String title) =>
      '$studentBrowse/subject/$subjectId?t=${Uri.encodeComponent(title)}';
  static String doctorLectures(
    String subjectId,
    String doctorId,
    String title,
  ) =>
      '$studentBrowse/subject/$subjectId/doctor/$doctorId'
      '?t=${Uri.encodeComponent(title)}';

  static String content(String id) => '/content/$id';
  static String viewer(String id, {bool manage = false}) =>
      '/view/$id${manage ? '?manage=1' : ''}';

  // Library
  static const libraryHome = '/l/home';
  static const libraryContent = '/l/content';
  static const libraryNotifications = '/l/notifications';
  static const libraryProfile = '/l/profile';

  static String newContent(ContentType type) => '/manage/new?type=${type.name}';
  static String editContent(String id) => '/manage/edit/$id';
  static const batchUpload = '/manage/batch';

  // Admin
  static const adminHome = '/a/home';
  static const adminUsers = '/a/users';
  static const adminStructure = '/a/structure';
  static const adminDevices = '/a/devices';
  static const adminMore = '/a/more';
  static const adminNewUser = '/a/users/new';
  static String adminUser(String id) => '/a/users/edit/$id';
  static String adminStructureKind(StructureKind kind) =>
      '/a/structure/${kind.name}';
  static const adminLibraries = '/a/structure/libraries';
  static const adminContent = '/a/more/content';
  static const adminAudit = '/a/more/audit';
  static const adminSettings = '/a/more/settings';
  static const adminReports = '/a/more/reports';
  static const adminNotifications = '/a/more/notifications';
  static const adminProfile = '/a/more/profile';
}
