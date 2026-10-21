import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/modules/talk_record/talk_record_error.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/model/talk_record/talk_record_participant_model.dart';

import '../talk_record_auth.dart';
import 'talk_record_detail_request_fence.dart';

abstract class TalkRecordParticipantsService {
  Future<TalkRecordFetched<TalkRecordParticipants>> load(String id);
  Future<TalkRecordFetched<TalkRecordParticipants>> save(
    String id,
    List<TalkRecordParticipantInput> list,
    String etag,
  );
}

class ApiTalkRecordParticipantsService
    implements TalkRecordParticipantsService {
  ApiTalkRecordParticipantsService(this.api);
  final TalkRecordApi api;
  @override
  Future<TalkRecordFetched<TalkRecordParticipants>> load(String id) =>
      api.participants(id);
  @override
  Future<TalkRecordFetched<TalkRecordParticipants>> save(
    String id,
    List<TalkRecordParticipantInput> list,
    String etag,
  ) => api.putParticipants(id, participants: list, ifMatch: etag);
}

final talkRecordParticipantsServiceProvider =
    Provider<TalkRecordParticipantsService>(
      (ref) => ApiTalkRecordParticipantsService(TalkRecordApi()),
    );

enum ParticipantNotice { none, failed, conflict, saved, invalid }

class TalkRecordParticipantsState {
  const TalkRecordParticipantsState({
    this.recordId = '',
    this.etag = '',
    this.selected = const [],
    this.loading = false,
    this.saving = false,
    this.ready = false,
    this.notice = ParticipantNotice.none,
  });
  final String recordId, etag;
  final List<TalkRecordParticipantInput> selected;
  final bool loading, saving, ready;
  final ParticipantNotice notice;
}

final talkRecordParticipantsProvider =
    NotifierProvider.autoDispose<
      TalkRecordParticipantsNotifier,
      TalkRecordParticipantsState
    >(TalkRecordParticipantsNotifier.new);

class TalkRecordParticipantsNotifier
    extends Notifier<TalkRecordParticipantsState> {
  late TalkRecordDetailRequestFence _fence;
  @override
  TalkRecordParticipantsState build() {
    final fence = TalkRecordDetailRequestFence(() => ref.mounted);
    _fence = fence;
    final remove = ref.read(talkRecordAuthSubscribeProvider)(() {
      fence.reset();
      if (ref.mounted) {
        state = const TalkRecordParticipantsState();
      }
    });
    ref.onDispose(() {
      fence.reset();
      remove();
    });
    return const TalkRecordParticipantsState();
  }

  Future<void> bind(String id) async {
    _fence.reset();
    final request = _fence.begin();
    final service = ref.read(talkRecordParticipantsServiceProvider);
    state = TalkRecordParticipantsState(recordId: id, loading: true);
    try {
      final fetched = await service.load(id);
      if (request.current) {
        _accept(id, fetched);
      }
    } on Object {
      if (request.current) {
        state = TalkRecordParticipantsState(
          recordId: id,
          notice: ParticipantNotice.failed,
        );
      }
    }
  }

  void select(List<TalkRecordParticipantInput> list) {
    if (!state.ready || state.saving) {
      return;
    }
    state = TalkRecordParticipantsState(
      recordId: state.recordId,
      etag: state.etag,
      selected: List.unmodifiable(list),
      ready: true,
    );
  }

  Future<void> save() async {
    final before = state;
    if (!before.ready || before.saving || before.etag.isEmpty) {
      return;
    }
    final request = _fence.begin();
    final service = ref.read(talkRecordParticipantsServiceProvider);
    state = TalkRecordParticipantsState(
      recordId: before.recordId,
      etag: before.etag,
      selected: before.selected,
      ready: true,
      saving: true,
    );
    try {
      final result = await service.save(
        before.recordId,
        before.selected,
        before.etag,
      );
      if (request.current) {
        _accept(before.recordId, result, ParticipantNotice.saved);
      }
    } on Object catch (error) {
      if (!request.current) {
        return;
      }
      if (error is TalkRecordApiException &&
          (error.code == 401 || error.code == 403 || error.code == 404)) {
        state = TalkRecordParticipantsState(
          recordId: before.recordId,
          notice: ParticipantNotice.failed,
        );
        return;
      }
      await _reconcile(service, request, before, error);
    }
  }

  Future<void> _reconcile(
    TalkRecordParticipantsService service,
    TalkRecordDetailRequest request,
    TalkRecordParticipantsState before,
    Object error,
  ) async {
    final stale = error is TalkRecordApiException && error.isRevisionStale;
    try {
      final actual = await service.load(before.recordId);
      if (!request.current) {
        return;
      }
      if (actual.data.recordId != before.recordId || actual.etag.isEmpty) {
        _keep(before, '', error);
        return;
      }
      if (!stale &&
          !(error is TalkRecordApiException && error.code == 422) &&
          actual.data.matches(before.selected)) {
        _accept(before.recordId, actual, ParticipantNotice.saved);
      } else if (stale || actual.etag != before.etag) {
        // An uncertain PUT may race another editor. Never pair the old desired
        // list with a freshly read version: refresh both projection and ETag.
        _accept(before.recordId, actual, ParticipantNotice.conflict);
      } else {
        _keep(before, actual.etag, error);
      }
    } on Object catch (reconcileError) {
      if (!request.current) {
        return;
      }
      if (reconcileError is TalkRecordApiException &&
          (reconcileError.code == 401 ||
              reconcileError.code == 403 ||
              reconcileError.code == 404)) {
        state = TalkRecordParticipantsState(
          recordId: before.recordId,
          notice: ParticipantNotice.failed,
        );
      } else {
        _keep(before, '', error);
      }
    }
  }

  void _keep(TalkRecordParticipantsState before, String etag, Object error) {
    state = TalkRecordParticipantsState(
      recordId: before.recordId,
      etag: etag,
      selected: before.selected,
      ready: etag.isNotEmpty,
      notice: error is TalkRecordApiException && error.code == 422
          ? ParticipantNotice.invalid
          : ParticipantNotice.failed,
    );
  }

  void _accept(
    String id,
    TalkRecordFetched<TalkRecordParticipants> fetched, [
    ParticipantNotice notice = ParticipantNotice.none,
  ]) {
    if (fetched.data.recordId != id || fetched.etag.isEmpty) {
      state = TalkRecordParticipantsState(
        recordId: id,
        notice: ParticipantNotice.failed,
      );
      return;
    }
    state = TalkRecordParticipantsState(
      recordId: id,
      etag: fetched.etag,
      selected: List.unmodifiable(
        fetched.data.list.map(
          (item) => TalkRecordParticipantInput(
            userId: item.input.userId,
            displayName: item.displayName,
          ),
        ),
      ),
      ready: true,
      notice: notice,
    );
  }
}
