import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/talk_record/talk_record_participant_model.dart';
import 'package:imboy/theme/default/app_spacing.dart';

import 'talk_record_auth.dart';
import 'talk_record_entry_context.dart';
import 'talk_record_providers.dart';
import 'talk_record_services.dart';

/// Informational selection only: neither sharing nor speaker verification.
Future<List<TalkRecordParticipantInput>?> showTalkRecordParticipantPicker(
  BuildContext context, {
  required TalkRecordEntryContext entryContext,
  required List<TalkRecordParticipantInput> selected,
}) => Navigator.of(context).push<List<TalkRecordParticipantInput>>(
  CupertinoPageRoute(
    builder: (_) => TalkRecordParticipantPicker(
      entryContext: entryContext,
      selected: selected,
    ),
  ),
);

class TalkRecordParticipantPicker extends ConsumerStatefulWidget {
  const TalkRecordParticipantPicker({
    super.key,
    required this.entryContext,
    required this.selected,
  });
  final TalkRecordEntryContext entryContext;
  final List<TalkRecordParticipantInput> selected;
  @override
  ConsumerState<TalkRecordParticipantPicker> createState() => _PickerState();
}

class _PickerState extends ConsumerState<TalkRecordParticipantPicker> {
  final _query = TextEditingController(), _guest = TextEditingController();
  late List<TalkRecordParticipantInput> _selected;
  List<TalkRecordParticipantOption> _options = [];
  Timer? _timer;
  void Function()? _remove;
  int _request = 0;
  bool _loading = true, _failed = false, _blocked = false, _invalid = false;
  bool _showSelected = false;

  @override
  void initState() {
    super.initState();
    _selected = List.of(widget.selected);
    _remove = ref.read(talkRecordAuthSubscribeProvider)(() {
      _request++;
      _timer?.cancel();
      if (!mounted) {
        return;
      }
      setState(() {
        _blocked = true;
        _selected = [];
        _options = [];
      });
      _query.clear();
      _guest.clear();
    });
    unawaited(_search());
  }

  @override
  void dispose() {
    _request++;
    _timer?.cancel();
    _remove?.call();
    _query.dispose();
    _guest.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_blocked) {
      return;
    }
    final request = ++_request;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final directory = ref.read(talkRecordParticipantDirectoryProvider);
      if (!directory.isAvailable) {
        throw StateError('Directory unavailable');
      }
      final options = await directory.searchContext(
        widget.entryContext,
        _query.text,
      );
      if (mounted && !_blocked && request == _request) {
        setState(() {
          _options = options;
          _loading = false;
        });
      }
    } on Object {
      if (mounted && !_blocked && request == _request) {
        setState(() {
          _failed = true;
          _options = [];
          _loading = false;
        });
      }
    }
  }

  void _changeQuery(String _) {
    _request++;
    _timer?.cancel();
    setState(() {
      _options = [];
      _loading = true;
    });
    _timer = Timer(const Duration(milliseconds: 300), _search);
  }

  void _toggle(TalkRecordParticipantInput input) {
    final found = _selected.any(
      (item) => item.identityKey == input.identityKey,
    );
    if (!found && _selected.length >= 100) {
      setState(() => _invalid = true);
      return;
    }
    setState(() {
      _invalid = false;
      _selected = found
          ? _selected
                .where((item) => item.identityKey != input.identityKey)
                .toList()
          : [..._selected, input];
    });
  }

  void _addGuest() {
    final name = _guest.text.trim();
    if (name.isEmpty ||
        name.runes.length > 120 ||
        name.runes.any((r) => r < 32 || r == 127)) {
      setState(() => _invalid = true);
      return;
    }
    final input = TalkRecordParticipantInput(displayName: name);
    if (_selected.any((item) => item.identityKey == input.identityKey)) {
      setState(() => _invalid = true);
      return;
    }
    _toggle(input);
    _guest.clear();
  }

  @override
  Widget build(BuildContext context) => IosPageTemplate(
    title: t.talkRecord.collabParticipantsLabel,
    actions: [
      TextButton(
        onPressed: _blocked
            ? null
            : () => Navigator.of(
                context,
              ).pop(List<TalkRecordParticipantInput>.unmodifiable(_selected)),
        child: Text(t.common.buttonAccomplish),
      ),
    ],
    body: _blocked
        ? Center(child: Text(t.talkRecord.invalidBody))
        : ListView(
            padding: const EdgeInsets.all(AppSpacing.regular),
            children: [
              Text(t.talkRecord.participantsInfoHint),
              const SizedBox(height: AppSpacing.medium),
              CupertinoSearchTextField(
                controller: _query,
                onChanged: _changeQuery,
              ),
              const SizedBox(height: AppSpacing.medium),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _showSelected = !_showSelected),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.talkRecord.collabParticipantsCount(
                          count: _selected.length,
                        ),
                      ),
                    ),
                    Icon(
                      _showSelected
                          ? CupertinoIcons.chevron_up
                          : CupertinoIcons.chevron_down,
                    ),
                  ],
                ),
              ),
              if (_showSelected)
                for (final item in _selected)
                  ListTile(
                    title: Text(
                      item.displayName.isNotEmpty
                          ? item.displayName
                          : item.userId,
                    ),
                    trailing: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _toggle(item),
                      child: Semantics(
                        label: t.talkRecord.participantsRemove,
                        child: const Icon(CupertinoIcons.minus_circle),
                      ),
                    ),
                  ),
              const Divider(),
              TextField(
                controller: _guest,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: t.talkRecord.participantsGuestLabel,
                ),
                onSubmitted: (_) => _addGuest(),
              ),
              TextButton(
                onPressed: _addGuest,
                child: Text(t.talkRecord.participantsAddGuest),
              ),
              if (_invalid) Text(t.talkRecord.participantsInvalid),
              const Divider(),
              if (_loading)
                const Center(child: CupertinoActivityIndicator())
              else if (_failed)
                TextButton(
                  onPressed: _search,
                  child: Text(t.talkRecord.loadFailedAction),
                )
              else if (_options.isEmpty)
                Text(t.talkRecord.participantsNoResults)
              else
                for (final option in _options)
                  CupertinoListTile(
                    trailing: CupertinoCheckbox(
                      value: _selected.any(
                        (item) => item.userId == option.userId,
                      ),
                      onChanged: (_) => _toggle(
                        TalkRecordParticipantInput(
                          userId: option.userId,
                          displayName: option.displayName,
                        ),
                      ),
                    ),
                    title: Text(option.displayName),
                    onTap: () => _toggle(
                      TalkRecordParticipantInput(
                        userId: option.userId,
                        displayName: option.displayName,
                      ),
                    ),
                  ),
            ],
          ),
  );
}
