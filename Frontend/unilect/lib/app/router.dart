import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/academic/domain/academic_models.dart';
import '../features/academic/presentation/browse_home_screen.dart';
import '../features/academic/presentation/browse_screens.dart';
import '../features/academic/presentation/subject_screen.dart';
import '../features/admin/presentation/admin_dashboard_screen.dart';
import '../features/admin/presentation/admin_more_screen.dart';
import '../features/admin/presentation/audit_log_screen.dart';
import '../features/admin/presentation/libraries_screen.dart';
import '../features/admin/presentation/reports_screen.dart';
import '../features/admin/presentation/settings_screen.dart';
import '../features/admin/presentation/structure_screens.dart';
import '../features/admin/presentation/user_form_screen.dart';
import '../features/admin/presentation/users_screen.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/domain/user.dart';
import '../features/auth/presentation/change_password_required_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/content/domain/content.dart';
import '../features/content/presentation/content_details_screen.dart';
import '../features/content/presentation/favorites_screen.dart';
import '../features/content/presentation/search_screen.dart';
import '../features/devices/domain/device_models.dart';
import '../features/devices/presentation/admin_devices_screen.dart';
import '../features/devices/presentation/device_blocked_screen.dart';
import '../features/library/presentation/batch_upload_screen.dart';
import '../features/library/presentation/content_editor_screen.dart';
import '../features/library/presentation/library_dashboard_screen.dart';
import '../features/library/presentation/manage_content_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/viewer/presentation/secure_viewer_screen.dart';
import 'role_shell.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

String homeFor(UserRole role) => switch (role) {
  UserRole.student => Routes.studentBrowse,
  UserRole.library => Routes.libraryHome,
  UserRole.admin => Routes.adminHome,
};

/// Client-side route guard (UX only — every permission is also enforced by
/// the server, FR-077). Protected pages are unreachable when signed out
/// (FR-003) and each role is confined to its own area (FR-006). A user with a
/// temporary password can only change it.
String? guard(SessionState session, String location) {
  const public = {
    Routes.login,
    Routes.forgotPassword,
    Routes.resetPassword,
    Routes.deviceBlocked,
  };
  final isPublic = public.contains(location);
  switch (session) {
    case SessionLoading() || SessionRestoreFailed():
      return location == Routes.splash ? null : Routes.splash;
    case SignedOut():
      return isPublic ? null : Routes.login;
    case SignedIn(:final user) when user.mustChangePassword:
      return location == Routes.changePassword ? null : Routes.changePassword;
    case SignedIn(:final user):
      if (isPublic ||
          location == Routes.splash ||
          location == Routes.changePassword) {
        return homeFor(user.role);
      }
      final allowed = switch (user.role) {
        UserRole.student => ['/s/', '/content/', '/view/'],
        UserRole.library => ['/l/', '/manage/', '/view/'],
        UserRole.admin => ['/a/', '/manage/', '/view/'],
      };
      return allowed.any(location.startsWith) ? null : homeFor(user.role);
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionControllerProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) =>
        guard(ref.read(sessionControllerProvider), state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.resetPassword,
        builder: (_, s) =>
            ForgotPasswordScreen(link: ResetLink.tryParse(s.uri.toString())),
      ),
      GoRoute(
        path: Routes.changePassword,
        builder: (_, _) => const ChangePasswordRequiredScreen(),
      ),
      GoRoute(
        path: Routes.deviceBlocked,
        redirect: (_, state) =>
            state.extra is DeviceMismatch ? null : Routes.login,
        builder: (_, state) =>
            DeviceBlockedScreen(mismatch: state.extra! as DeviceMismatch),
      ),

      // ── Student ──
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) =>
            RoleShell(shell: shell, role: UserRole.student),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.studentBrowse,
                builder: (_, _) => const BrowseHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'u/:universityId',
                    builder: (_, s) => FacultiesScreen(
                      universityId: s.pathParameters['universityId']!,
                      title: s.uri.queryParameters['t'] ?? '',
                    ),
                  ),
                  GoRoute(
                    path: 'f/:facultyId',
                    builder: (_, s) => YearsScreen(
                      facultyId: s.pathParameters['facultyId']!,
                      title: s.uri.queryParameters['t'] ?? '',
                    ),
                    routes: [
                      GoRoute(
                        path: 'y/:yearId',
                        builder: (_, s) => SubjectsScreen(
                          facultyId: s.pathParameters['facultyId']!,
                          yearId: s.pathParameters['yearId']!,
                          title: s.uri.queryParameters['t'] ?? '',
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'subject/:subjectId',
                    builder: (_, s) => SubjectScreen(
                      subjectId: s.pathParameters['subjectId']!,
                      title: s.uri.queryParameters['t'] ?? '',
                    ),
                    routes: [
                      GoRoute(
                        path: 'doctor/:doctorId',
                        builder: (_, s) => DoctorLecturesScreen(
                          subjectId: s.pathParameters['subjectId']!,
                          doctorId: s.pathParameters['doctorId']!,
                          title: s.uri.queryParameters['t'] ?? '',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          _branch(Routes.studentSearch, const SearchScreen()),
          _branch(Routes.studentFavorites, const FavoritesScreen()),
          _branch(Routes.studentNotifications, const NotificationsScreen()),
          _branch(Routes.studentProfile, const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/content/:id',
        builder: (_, s) => ContentDetailsScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/view/:id',
        builder: (_, s) => SecureViewerScreen(
          id: s.pathParameters['id']!,
          manage: s.uri.queryParameters['manage'] == '1',
        ),
      ),

      // ── Library ──
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) =>
            RoleShell(shell: shell, role: UserRole.library),
        branches: [
          _branch(Routes.libraryHome, const LibraryDashboardScreen()),
          _branch(Routes.libraryContent, const ManageContentScreen()),
          _branch(Routes.libraryNotifications, const NotificationsScreen()),
          _branch(Routes.libraryProfile, const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/manage/new',
        builder: (_, s) => ContentEditorScreen(
          type: s.uri.queryParameters['type'] == 'exam'
              ? ContentType.exam
              : ContentType.lecture,
        ),
      ),
      GoRoute(
        path: '/manage/edit/:id',
        builder: (_, s) => ContentEditorScreen(
          contentId: s.pathParameters['id'],
          type: ContentType.lecture,
        ),
      ),
      GoRoute(
        path: Routes.batchUpload,
        builder: (_, _) => const BatchUploadScreen(),
      ),

      // ── Admin ──
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => RoleShell(shell: shell, role: UserRole.admin),
        branches: [
          _branch(Routes.adminHome, const AdminDashboardScreen()),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adminUsers,
                builder: (_, _) => const UsersScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const UserFormScreen(),
                  ),
                  GoRoute(
                    path: 'edit/:id',
                    parentNavigatorKey: _rootKey,
                    builder: (_, s) =>
                        UserFormScreen(userId: s.pathParameters['id']),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adminStructure,
                builder: (_, _) => const StructureHubScreen(),
                routes: [
                  GoRoute(
                    path: 'libraries',
                    builder: (_, _) => const LibrariesScreen(),
                  ),
                  GoRoute(
                    path: ':kind',
                    builder: (_, s) => StructureKindScreen(
                      kind: StructureKind.values.byName(
                        s.pathParameters['kind']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          _branch(Routes.adminDevices, const AdminDevicesScreen()),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adminMore,
                builder: (_, _) => const AdminMoreScreen(),
                routes: [
                  GoRoute(
                    path: 'content',
                    builder: (_, _) =>
                        const ManageContentScreen(adminMode: true),
                  ),
                  GoRoute(
                    path: 'audit',
                    builder: (_, _) => const AuditLogScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (_, _) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: 'reports',
                    builder: (_, _) => const ReportsScreen(),
                  ),
                  GoRoute(
                    path: 'notifications',
                    builder: (_, _) => const NotificationsScreen(),
                  ),
                  GoRoute(
                    path: 'profile',
                    builder: (_, _) => const ProfileScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

StatefulShellBranch _branch(String path, Widget screen) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (_, _) => screen)],
);
