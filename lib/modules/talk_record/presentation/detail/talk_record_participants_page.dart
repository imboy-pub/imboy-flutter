import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_spacing.dart';

import '../talk_record_entry_context.dart';
import '../talk_record_participant_picker.dart';
import 'talk_record_detail_providers.dart';
import 'talk_record_participants_provider.dart';

class TalkRecordParticipantsPage extends ConsumerStatefulWidget {
  const TalkRecordParticipantsPage({super.key, required this.recordId});
  final String recordId;
  @override
  ConsumerState<TalkRecordParticipantsPage> createState() =>
      _ParticipantsPageState();
}

class _ParticipantsPageState extends ConsumerState<TalkRecordParticipantsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          ref
              .read(talkRecordParticipantsProvider.notifier)
              .bind(widget.recordId),
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant TalkRecordParticipantsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recordId != widget.recordId) {
      Future.microtask(() {
        if (mounted) {
          ref
              .read(talkRecordParticipantsProvider.notifier)
              .bind(widget.recordId);
        }
      });
    }
  }

  Future<void> _edit(TalkRecordEntryContext entry) async {
    final notifier = ref.read(talkRecordParticipantsProvider.notifier);
    final initial = ref.read(talkRecordParticipantsProvider);
    final selected = await showTalkRecordParticipantPicker(
      context,
      entryContext: entry,
      selected: initial.selected,
    );
    if (!mounted || selected == null) {
      return;
    }
    final current = ref.read(talkRecordParticipantsProvider);
    if (current.recordId != initial.recordId || !current.ready) {
      return;
    }
    notifier.select(selected);
  }

  String _notice(ParticipantNotice notice) => switch (notice) {
    ParticipantNotice.conflict => t.talkRecord.participantsConflict,
    ParticipantNotice.saved => t.common.saveSuccess,
    ParticipantNotice.invalid => t.talkRecord.participantsInvalid,
    ParticipantNotice.failed => t.talkRecord.participantsSaveFailed,
    ParticipantNotice.none => '',
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(talkRecordParticipantsProvider);
    final record = ref.watch(talkRecordDetailProvider).record;
    final valid = record != null && record.id == widget.recordId;
    final ready = valid && state.recordId == widget.recordId && state.ready;
    final canEdit = ready && record.capabilitiesForActor.edit;
    final entry = valid
        ? TalkRecordEntryContext(
            scope: record.scope,
            organizationId: record.organizationId,
            workspaceId: record.workspaceId,
          )
        : null;
    return IosPageTemplate(
      title: t.talkRecord.collabParticipantsLabel,
      actions: !canEdit
          ? null
          : [
              TextButton(
                onPressed: state.saving
                    ? null
                    : () => ref
                          .read(talkRecordParticipantsProvider.notifier)
                          .save(),
                child: state.saving
                    ? const CupertinoActivityIndicator()
                    : Text(t.common.buttonSave),
              ),
            ],
      body: !valid
          ? Center(child: Text(t.talkRecord.invalidBody))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.regular),
              children: [
                Text(t.talkRecord.participantsInfoHint),
                const SizedBox(height: AppSpacing.medium),
                if (state.loading)
                  const Center(child: CupertinoActivityIndicator())
                else if (!ready)
                  TextButton(
                    onPressed: () => ref
                        .read(talkRecordParticipantsProvider.notifier)
                        .bind(widget.recordId),
                    child: Text(t.talkRecord.loadFailedAction),
                  ),
                if (ready && state.selected.isEmpty)
                  Text(t.talkRecord.collabParticipantsEmpty),
                if (state.recordId == widget.recordId && !state.loading)
                  for (final item in state.selected)
                    ListTile(
                      leading: Icon(
                        item.userId.isEmpty
                            ? CupertinoIcons.person
                            : CupertinoIcons.person_crop_circle,
                      ),
                      title: Text(item.displayName),
                    ),
                if (canEdit)
                  TextButton.icon(
                    onPressed: state.saving ? null : () => _edit(entry!),
                    icon: const Icon(CupertinoIcons.person_badge_plus),
                    label: Text(t.common.edit),
                  ),
                if (state.notice != ParticipantNotice.none)
                  Text(_notice(state.notice)),
              ],
            ),
    );
  }
}
