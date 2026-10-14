import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/paged_list.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/state_views.dart';
import '../application/admin_providers.dart';
import '../domain/admin_models.dart';

/// FR-068: who did what, when, to which entity.
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.auditLog)),
      body: Column(
        children: [
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                for (final c in [null, ...AuditCategories.all]) ...[
                  ChoiceChip(
                    label: Text(c == null ? l.all : l.auditCategoryLabel(c)),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
          Expanded(
            child: PagedListView<AuditLogEntry>(
              provider: auditLogProvider(_category),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              empty: EmptyView(
                icon: Icons.receipt_long_rounded,
                title: l.emptyAudit,
              ),
              itemBuilder: (context, e) => Card(
                child: ListTile(
                  leading: const IconBadge(icon: Icons.bolt_rounded, size: 42),
                  title: Text(e.entityLabel),
                  subtitle: Text(
                    '${e.action} · ${l.auditCategoryLabel(e.category)}\n'
                    '${[?e.actor, context.formatDateTime(e.createdAt)].join(' · ')}',
                    style: theme.textTheme.bodySmall,
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
