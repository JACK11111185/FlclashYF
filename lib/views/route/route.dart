import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/route_input.dart' as route_input;
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class RouteView extends ConsumerWidget {
  const RouteView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    if (profile == null) {
      return CommonScaffold(
        title: context.appLocalizations.route,
        body: Center(child: Text(context.appLocalizations.routeNoProfile)),
      );
    }
    final groups = ref.watch(routeGroupsProvider(profile.id));
    final rules = ref.watch(routeRulesProvider(profile.id));
    final providers = ref.watch(routeRuleProviderItemsProvider(profile.id));
    return CommonScaffold(
      title: context.appLocalizations.route,
      floatingActionButton: FloatingActionButton(
        tooltip: context.appLocalizations.add,
        onPressed: () => _showAddMenu(context, ref, profile.id),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section<ProxyGroup>(
            title: context.appLocalizations.routeGroups,
            value: groups,
            titleOf: (item) => item.name,
            subtitleOf: (item) =>
                '${item.type.value} · ${item.proxies?.length ?? 0}',
            onDelete: (item) =>
                ref.read(routeStoreProvider(profile.id)).removeGroup(item.id),
          ),
          const SizedBox(height: 16),
          _Section<Rule>(
            title: context.appLocalizations.routeRules,
            value: rules,
            titleOf: (item) => item.rawValue,
            onDelete: (item) =>
                ref.read(routeStoreProvider(profile.id)).removeRule(item.id),
          ),
          const SizedBox(height: 16),
          _Section<RouteRuleProvider>(
            title: context.appLocalizations.routeProviders,
            value: providers,
            titleOf: (item) => item.name,
            subtitleOf: (item) => item.url,
            onDelete: (item) => ref
                .read(routeStoreProvider(profile.id))
                .removeProvider(item.id),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _showAddMenu(
    BuildContext context,
    WidgetRef ref,
    int profileId,
  ) async {
    final choice = await showDialog<_RouteAddKind>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.appLocalizations.add),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _RouteAddKind.rule),
            child: Text(context.appLocalizations.routeRules),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _RouteAddKind.group),
            child: Text(context.appLocalizations.routeGroups),
          ),
        ],
      ),
    );
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case _RouteAddKind.rule:
        await _showRuleDialog(context, ref, profileId);
      case _RouteAddKind.group:
        await _showGroupDialog(context, ref, profileId);
    }
  }

  Future<void> _showRuleDialog(
    BuildContext context,
    WidgetRef ref,
    int profileId,
  ) async {
    final config = await ref.read(clashConfigProvider(profileId).future);
    if (!context.mounted) return;
    final input = TextEditingController();
    final providerName = TextEditingController();
    final targets = <String>{
      'DIRECT',
      'REJECT',
      ...config.proxyGroups.map((group) => group.name),
      ...config.proxies.map((proxy) => proxy.name),
    }.toList();
    var target = 'DIRECT';
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.appLocalizations.routeRules),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: input,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: context.appLocalizations.routeInputHint,
                  helperText: context.appLocalizations.routeInputHelp,
                  errorText: error,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: target,
                decoration: InputDecoration(
                  labelText: context.appLocalizations.routeTarget,
                ),
                items: targets
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => target = value!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: providerName,
                decoration: InputDecoration(
                  labelText: context.appLocalizations.name,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.appLocalizations.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (route_input.parseRouteInputs(input.text) == null) {
                  setState(() {
                    error = context.appLocalizations.routeInvalidInput;
                  });
                  return;
                }
                Navigator.pop(context, true);
              },
              child: Text(context.appLocalizations.save),
            ),
          ],
        ),
      ),
    );
    if (saved != true) {
      input.dispose();
      providerName.dispose();
      return;
    }
    final List<route_input.RouteInput> routeInputs = route_input
        .parseRouteInputs(input.text)!;
    final List<Rule> rules = <Rule>[];
    final List<RouteRuleProvider> providers = <RouteRuleProvider>[];
    final baseName = providerName.text.trim();
    for (var index = 0; index < routeInputs.length; index++) {
      final route_input.RouteInput routeInput = routeInputs[index];
      final id = snowflake.id;
      if (routeInput.url != null) {
        final derivedName = Uri.parse(
          routeInput.url!,
        ).host.replaceAll('.', '-');
        final name = baseName.isEmpty
            ? routeInputs.length == 1
                  ? derivedName
                  : '$derivedName-${index + 1}'
            : routeInputs.length == 1
            ? baseName
            : '$baseName-${index + 1}';
        providers.add(
          RouteRuleProvider(
            id: id,
            name: name,
            profileId: profileId,
            url: routeInput.url!,
            behavior: 'domain',
            format: 'yaml',
            interval: 86400,
          ),
        );
        rules.add(
          Rule(
            id: id,
            ruleAction: RuleAction.RULE_SET,
            ruleProvider: name,
            ruleTarget: target,
          ),
        );
      } else {
        rules.add(
          Rule(
            id: id,
            ruleAction: routeInput.action!,
            content: routeInput.content,
            ruleTarget: target,
          ),
        );
      }
    }
    await ref
        .read(routeStoreProvider(profileId))
        .putRoutes(rules: rules, providers: providers);
    input.dispose();
    providerName.dispose();
  }

  Future<void> _showGroupDialog(
    BuildContext context,
    WidgetRef ref,
    int profileId,
  ) async {
    final config = await ref.read(clashConfigProvider(profileId).future);
    if (!context.mounted) return;
    final name = TextEditingController();
    final interval = TextEditingController(text: '300');
    var type = GroupType.Selector;
    final choices = {
      ...config.proxies.map((proxy) => proxy.name),
      ...config.proxyGroups.map((group) => group.name),
    }.toList();
    final selected = <String>{};
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.appLocalizations.routeGroups),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: name,
                    decoration: InputDecoration(
                      labelText: context.appLocalizations.name,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<GroupType>(
                    initialValue: type,
                    decoration: InputDecoration(
                      labelText: context.appLocalizations.routeGroupType,
                    ),
                    items:
                        const [
                              GroupType.Selector,
                              GroupType.URLTest,
                              GroupType.LoadBalance,
                            ]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Row(
                                  children: [
                                    Text(value.value),
                                    const SizedBox(width: 8),
                                    Text(
                                      switch (value) {
                                        GroupType.Selector =>
                                          context
                                              .appLocalizations
                                              .routeGroupManual,
                                        GroupType.URLTest =>
                                          context
                                              .appLocalizations
                                              .routeGroupAuto,
                                        GroupType.LoadBalance =>
                                          context
                                              .appLocalizations
                                              .routeGroupBalance,
                                        _ => '',
                                      },
                                      style: context.textTheme.labelSmall
                                          ?.copyWith(
                                            color: context
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (value) => setState(() => type = value!),
                  ),
                  if (type == GroupType.URLTest) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: interval,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.appLocalizations.routeHealthInterval,
                        suffixText: context.appLocalizations.seconds,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(context.appLocalizations.routeMembers),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final choice in choices)
                        FilterChip(
                          label: Text(choice),
                          selected: selected.contains(choice),
                          onSelected: (value) => setState(() {
                            value
                                ? selected.add(choice)
                                : selected.remove(choice);
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.appLocalizations.cancel),
            ),
            FilledButton(
              onPressed: name.text.trim().isEmpty || selected.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: Text(context.appLocalizations.save),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await ref
          .read(routeStoreProvider(profileId))
          .putGroup(
            ProxyGroup(
              id: snowflake.id,
              name: name.text.trim(),
              type: type,
              proxies: selected.toList(),
              url: type == GroupType.Selector
                  ? null
                  : 'https://www.gstatic.com/generate_204',
              interval: type == GroupType.Selector
                  ? null
                  : int.tryParse(interval.text) ?? 300,
              routeManaged: true,
            ),
          );
    }
    name.dispose();
    interval.dispose();
  }
}

class _Section<T> extends StatelessWidget {
  const _Section({
    required this.title,
    required this.value,
    required this.titleOf,
    required this.onDelete,
    this.subtitleOf,
  });

  final String title;
  final AsyncValue<List<T>> value;
  final String Function(T item) titleOf;
  final String Function(T item)? subtitleOf;
  final void Function(T item) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        value.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Text(userFacingErrorMessage(error, context.appLocalizations)),
          data: (items) => items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(context.appLocalizations.noData),
                )
              : Card(
                  child: Column(
                    children: [
                      for (final item in items)
                        ListTile(
                          title: Text(titleOf(item)),
                          subtitle: subtitleOf == null
                              ? null
                              : Text(subtitleOf!(item)),
                          trailing: IconButton(
                            tooltip: context.appLocalizations.delete,
                            onPressed: () => onDelete(item),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

enum _RouteAddKind { rule, group }
