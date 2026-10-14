import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/widgets/auth_scaffold.dart';
import '../../settings/application/config_providers.dart';
import '../../settings/domain/client_config.dart';
import '../application/admin_providers.dart';

/// FR-069 (plus the FR-066 review switch and FR-071 follower notifications).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(adminSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: AsyncValueView<ClientConfig>(
        value: settings,
        onRetry: () => ref.invalidate(adminSettingsProvider),
        data: (c) => _SettingsForm(initial: c),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.initial});
  final ClientConfig initial;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late ClientConfig _config = widget.initial;
  late final _maxSize = TextEditingController(
    text: '${widget.initial.maxUploadSizeMb}',
  );
  bool _saving = false;

  @override
  void dispose() {
    _maxSize.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final max = int.tryParse(_maxSize.text);
    if (max == null ||
        max < 1 ||
        max > ClientConfig.maxUploadSizeLimitMb ||
        _config.allowedExtensions.isEmpty) {
      AppFeedback.error(context, context.l10n.errorValidation);
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(adminRepositoryProvider)
          .saveSettings(_config.copyWith(maxUploadSizeMb: max));
      ref.invalidate(clientConfigProvider);
      if (!mounted) return;
      setState(() => _config = saved);
      AppFeedback.success(context, context.l10n.settingsSaved);
    } catch (e) {
      if (mounted) AppFeedback.error(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListView(
      padding: AppSpacing.page,
      children: [
        InfoBanner(message: l.settingsAppliesNote),
        SectionHeader(title: l.file),
        TextField(
          controller: _maxSize,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: l.maxUploadSize,
            prefixIcon: const Icon(Icons.sd_storage_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l.allowedExtensions,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final ext in ClientConfig.supportedExtensions)
              FilterChip(
                label: Text('.$ext'),
                selected: _config.allowedExtensions.contains(ext),
                onSelected: (on) => setState(() {
                  final next = {..._config.allowedExtensions};
                  on ? next.add(ext) : next.remove(ext);
                  _config = _config.copyWith(allowedExtensions: next.toList());
                }),
              ),
          ],
        ),
        SectionHeader(title: l.preferencesSection),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.fact_check_outlined),
                title: Text(l.requireReview),
                subtitle: Text(l.requireReviewHint),
                value: _config.requireContentReview,
                onChanged: (v) => setState(
                  () => _config = _config.copyWith(requireContentReview: v),
                ),
              ),
              const Divider(indent: 56),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: Text(l.notifyFollowers),
                subtitle: Text(l.notifyFollowersHint),
                value: _config.notifyFollowersOnPublish,
                onChanged: (v) => setState(
                  () => _config = _config.copyWith(notifyFollowersOnPublish: v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        GradientButton(label: l.save, loading: _saving, onPressed: _save),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}
