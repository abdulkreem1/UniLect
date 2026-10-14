import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/application/paged_list.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/models/json.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/filter_chip_picker.dart';
import '../../../core/widgets/picker_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/domain/user.dart';
import '../application/admin_providers.dart';
import '../data/admin_repository.dart';

/// FR-005: account management list.
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  UserQuery _query = const UserQuery();

  void _set(UserQuery query) => setState(() => _query = query);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.usersTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.adminNewUser),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(l.newUser),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: TextField(
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => _set(_query.copyWith(text: v)),
              decoration: InputDecoration(
                hintText: l.searchUsers,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                FilterChipPicker<UserRole>(
                  label: l.role,
                  value: _query.role,
                  options: [
                    for (final r in UserRole.values)
                      PickerOption(r, l.roleLabel(r)),
                  ],
                  onChanged: (v) => _set(_query.copyWith(role: Nullable(v))),
                ),
                const SizedBox(width: 8),
                FilterChipPicker<AccountStatus>(
                  label: l.statusLabel,
                  value: _query.status,
                  options: [
                    PickerOption(AccountStatus.active, l.statusActive),
                    PickerOption(AccountStatus.disabled, l.statusDisabled),
                  ],
                  onChanged: (v) => _set(_query.copyWith(status: Nullable(v))),
                ),
              ],
            ),
          ),
          Expanded(
            child: PagedListView<AppUser>(
              provider: usersListProvider(_query),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
              empty: EmptyView(
                icon: Icons.person_search_rounded,
                title: l.emptyUsers,
              ),
              itemBuilder: (context, u) => UserTile(
                user: u,
                onTap: () => context.push(Routes.adminUser(u.id)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UserTile extends StatelessWidget {
  const UserTile({super.key, required this.user, required this.onTap});

  final AppUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).extension<StatusColors>()!;
    final roleColor = switch (user.role) {
      UserRole.student => AppColors.blue600,
      UserRole.library => AppColors.sky500,
      UserRole.admin => AppColors.navy800,
    };
    return NavCard(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: roleColor.withValues(alpha: 0.14),
        child: Text(
          user.initials,
          style: TextStyle(color: roleColor, fontWeight: FontWeight.w700),
        ),
      ),
      title: user.fullName,
      subtitle: [
        user.email,
        ?user.studentNumber,
        ?user.libraryName,
      ].join(' · '),
      onTap: onTap,
      badge: Wrap(
        spacing: 8,
        children: [
          Pill(label: l.roleLabel(user.role), color: roleColor),
          Pill(
            label: user.isActive ? l.statusActive : l.statusDisabled,
            color: user.isActive ? colors.success : colors.danger,
          ),
        ],
      ),
    );
  }
}
