import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/paged_list.dart';
import '../../../core/models/json.dart';
import '../../../core/providers.dart';
import '../../academic/domain/academic_models.dart';
import '../../auth/domain/user.dart';
import '../../devices/domain/device_models.dart';
import '../../reports/domain/content_report.dart';
import '../../settings/domain/client_config.dart';
import '../data/admin_repository.dart';
import '../domain/admin_models.dart';

final adminDashboardProvider = FutureProvider.autoDispose<AdminDashboard>(
  (ref) => ref.watch(adminRepositoryProvider).dashboard(),
);

class UsersListController extends PagedListNotifier<AppUser> {
  UsersListController(this.query);
  final UserQuery query;

  @override
  Future<Paged<AppUser>> fetchPage(int page) =>
      ref.read(adminRepositoryProvider).users(query, page: page);
}

final usersListProvider = AsyncNotifierProvider.autoDispose
    .family<UsersListController, Paged<AppUser>, UserQuery>(
      UsersListController.new,
    );

final adminUserProvider = FutureProvider.autoDispose.family<AppUser, String>(
  (ref, id) => ref.watch(adminRepositoryProvider).user(id),
);

final deviceRequestsProvider = FutureProvider.autoDispose
    .family<
      List<DeviceChangeRequest>,
      ({DeviceChangeStatus? status, bool newestFirst})
    >(
      (ref, a) => ref
          .watch(adminRepositoryProvider)
          .deviceRequests(status: a.status, newestFirst: a.newestFirst),
    );

class DeviceLogController extends PagedListNotifier<DeviceLogEntry> {
  @override
  Future<Paged<DeviceLogEntry>> fetchPage(int page) =>
      ref.read(adminRepositoryProvider).deviceLogs(page: page);
}

final deviceLogProvider =
    AsyncNotifierProvider.autoDispose<
      DeviceLogController,
      Paged<DeviceLogEntry>
    >(DeviceLogController.new);

class AuditLogController extends PagedListNotifier<AuditLogEntry> {
  AuditLogController(this.category);
  final String? category;

  @override
  Future<Paged<AuditLogEntry>> fetchPage(int page) => ref
      .read(adminRepositoryProvider)
      .auditLogs(category: category, page: page);
}

final auditLogProvider = AsyncNotifierProvider.autoDispose
    .family<AuditLogController, Paged<AuditLogEntry>, String?>(
      AuditLogController.new,
    );

final adminSettingsProvider = FutureProvider.autoDispose<ClientConfig>(
  (ref) => ref.watch(adminRepositoryProvider).settings(),
);

final reportsProvider = FutureProvider.autoDispose
    .family<List<ContentReport>, ReportStatus?>(
      (ref, status) =>
          ref.watch(adminRepositoryProvider).reports(status: status),
    );

/// Libraries and their scope (FR-059, FR-060).
final librariesProvider = FutureProvider.autoDispose<List<Library>>(
  (ref) => ref.watch(academicRepositoryProvider).libraries(),
);

/// Courses of one university, to link instructors to.
final adminUniversitySubjectsProvider = FutureProvider.autoDispose
    .family<List<Subject>, String>(
      (ref, universityId) => ref
          .watch(academicRepositoryProvider)
          .adminUniversitySubjects(universityId),
    );

/// Admin structure lists (include inactive items).
final adminStructureProvider = FutureProvider.autoDispose
    .family<List<AcademicItem>, ({StructureKind kind, String? parentId})>(
      (ref, a) => ref
          .watch(academicRepositoryProvider)
          .adminList(a.kind, parentId: a.parentId),
    );
