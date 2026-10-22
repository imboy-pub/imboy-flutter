import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_credentials.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'talk_record_ai_providers.dart';
import 'talk_record_ai_widgets.dart';

class TalkRecordAiProviderPage extends ConsumerStatefulWidget {
  const TalkRecordAiProviderPage({super.key, required this.provider});
  final TalkRecordAiProvider provider;
  @override
  ConsumerState<TalkRecordAiProviderPage> createState() => _ProviderPageState();
}

class _ProviderPageState extends ConsumerState<TalkRecordAiProviderPage>
    with WidgetsBindingObserver {
  final _input = TextEditingController();
  TalkRecordAiIdentity? _boundIdentity;
  bool _busy = false, _expired = false;
  String? _message;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _boundIdentity = ref.read(talkRecordAiSessionProvider);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _input.clear();
    _input.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _input.clear();
  }

  bool get _current =>
      mounted &&
      !_expired &&
      (_boundIdentity?.matches(
            ref.read(talkRecordAiIdentityReaderProvider)(),
          ) ??
          false);

  void _expire() {
    _input.clear();
    if (mounted) {
      setState(() {
        _expired = true;
        _busy = false;
        _message = null;
      });
    }
  }

  Future<bool> _confirm(bool deleting) async {
    final accepted = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(
          deleting ? t.talkRecord.aiDeleteTitle : t.talkRecord.aiReplaceTitle,
        ),
        content: Text(
          deleting ? t.talkRecord.aiDeleteNotice : t.talkRecord.aiReplaceNotice,
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.talkRecord.aiCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: deleting,
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              deleting
                  ? t.talkRecord.aiDeleteAction
                  : t.talkRecord.aiReplaceAction,
            ),
          ),
        ],
      ),
    );
    return accepted == true && _current;
  }

  Future<void> _save(bool replacing) async {
    if (_busy || !_current) return;
    final value = _input.text;
    setState(() => _busy = true);
    if (replacing && !await _confirm(false)) {
      if (_current) setState(() => _busy = false);
      return;
    }
    if (!_current) return;
    _input.clear();
    await _operate(
      (credentials) => credentials.save(widget.provider, value),
      t.talkRecord.aiSaved,
    );
  }

  Future<void> _delete() async {
    if (_busy || !_current) return;
    setState(() => _busy = true);
    if (!await _confirm(true)) {
      if (_current) setState(() => _busy = false);
      return;
    }
    _input.clear();
    await _operate(
      (credentials) => credentials.remove(widget.provider),
      t.talkRecord.aiDeleted,
    );
  }

  Future<void> _operate(
    Future<void> Function(TalkRecordAiCredentials) operation,
    String success,
  ) async {
    if (!_current) return;
    final credentials = ref.read(talkRecordAiCredentialsProvider);
    if (credentials == null) return _expire();
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await operation(credentials);
      if (!_current) return;
      ref.invalidate(talkRecordAiStatusProvider(widget.provider));
      setState(() {
        _message = success;
        _error = false;
      });
    } catch (error) {
      if (!_current) return;
      setState(() {
        _message = talkRecordAiError(error);
        _error = true;
      });
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(talkRecordAiSessionProvider, (_, next) {
      if (!(_boundIdentity?.matches(next) ?? false)) _expire();
    });
    final status = ref.watch(talkRecordAiStatusProvider(widget.provider));
    final configured = !_expired && status.asData?.value.configured == true;
    final enabled = _current && !status.isLoading && !_busy;
    return IosPageTemplate(
      title: talkRecordAiProviderTitle(widget.provider),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.regular),
          children: [
            TalkRecordAiText(
              widget.provider == TalkRecordAiProvider.doubao
                  ? t.talkRecord.aiDoubaoPendingNotice
                  : widget.provider.isTranscription
                  ? t.talkRecord.aiMinimaxPurpose
                  : t.talkRecord.aiZhipuPurpose,
            ),
            const SizedBox(height: AppSpacing.regular),
            if (_expired || _boundIdentity == null)
              TalkRecordAiText(t.talkRecord.aiAccountChanged, error: true)
            else
              ..._configuration(status, configured, enabled),
            ..._privacyNotices(),
          ],
        ),
      ),
    );
  }

  List<Widget> _privacyNotices() => [
    const SizedBox(height: AppSpacing.regular),
    TalkRecordAiText(t.talkRecord.aiDeviceOnlyNotice),
    const SizedBox(height: AppSpacing.regular),
    TalkRecordAiText(switch (widget.provider) {
      TalkRecordAiProvider.doubao => t.talkRecord.aiDoubaoPendingNotice,
      TalkRecordAiProvider.zhipu => t.talkRecord.aiMaxNotice,
      TalkRecordAiProvider.minimax => t.talkRecord.aiAudioExternalNotice,
    }),
    const SizedBox(height: AppSpacing.regular),
    TalkRecordAiText(t.talkRecord.aiValidationNotice),
  ];

  List<Widget> _configuration(
    AsyncValue<TalkRecordAiCredentialStatus> status,
    bool configured,
    bool enabled,
  ) => [
    _keyCard(status, configured, enabled),
    const SizedBox(height: AppSpacing.regular),
    if (_message != null) ...[
      TalkRecordAiText(_message!, error: _error),
      const SizedBox(height: AppSpacing.small),
    ],
    ..._actions(configured, enabled, status.hasError),
  ];

  Widget _keyCard(
    AsyncValue<TalkRecordAiCredentialStatus> status,
    bool configured,
    bool enabled,
  ) => TalkRecordAiCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.provider.model,
          style: context.textStyle(
            FontSizeType.body,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        TalkRecordAiText(widget.provider.endpoint),
        const SizedBox(height: AppSpacing.regular),
        if (configured)
          TalkRecordAiText('${t.talkRecord.aiConfigured} · ••••••••'),
        if (status.hasError)
          TalkRecordAiText(talkRecordAiError(status.error), error: true),
        if (status.isLoading) const CupertinoActivityIndicator(),
        const SizedBox(height: AppSpacing.small),
        _keyInput(configured, enabled, status.hasError),
      ],
    ),
  );

  Widget _keyInput(bool configured, bool enabled, bool statusError) =>
      CupertinoTextField(
        key: const ValueKey('talk_record_ai_key_input'),
        controller: _input,
        enabled: enabled,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        autofillHints: const [],
        maxLength: 4096,
        placeholder: configured
            ? t.talkRecord.aiReplacePlaceholder
            : t.talkRecord.aiKeyPlaceholder,
        padding: const EdgeInsets.all(AppSpacing.regular),
        style: context.textStyle(FontSizeType.body),
        onSubmitted: (_) => enabled ? _save(configured || statusError) : null,
      );

  List<Widget> _actions(bool configured, bool enabled, bool statusError) => [
    CupertinoButton.filled(
      key: const ValueKey('talk_record_ai_save'),
      minimumSize: const Size.fromHeight(AppSpacing.xxxLarge + AppSpacing.tiny),
      onPressed: enabled ? () => _save(configured || statusError) : null,
      child: Text(
        _busy
            ? t.talkRecord.aiSaving
            : configured
            ? t.talkRecord.aiReplaceAction
            : t.talkRecord.aiSaveAction,
      ),
    ),
    if (configured)
      CupertinoButton(
        key: const ValueKey('talk_record_ai_delete'),
        minimumSize: const Size.fromHeight(AppSpacing.xxxLarge),
        onPressed: enabled ? _delete : null,
        child: Text(
          t.talkRecord.aiDeleteAction,
          style: context.textStyle(
            FontSizeType.body,
            color: AppColors.getIosRed(Theme.of(context).brightness),
          ),
        ),
      ),
  ];
}
