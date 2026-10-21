/// UI state projections for account-isolated record details.
library;

import 'package:imboy/store/model/workspace_model.dart' show EntityId;
import 'package:imboy/store/model/talk_record/talk_record_mark_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_segment_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_speaker_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_summary_model.dart';

enum TalkRecordDetailPhase { idle, loading, ready, failed }

enum TalkRecordNotesPhase { idle, saving, saved, conflict, failed }

class TalkRecordDetailState {
  final EntityId recordId;
  final TalkRecordDetailPhase phase;
  final TalkRecordModel? record;
  final String recordEtag;
  final TalkRecordSummaryModel? summary;
  final List<TalkRecordMarkModel> marks;
  final TalkRecordNotesPhase notesPhase;

  const TalkRecordDetailState({
    this.recordId = '',
    this.phase = TalkRecordDetailPhase.idle,
    this.record,
    this.recordEtag = '',
    this.summary,
    this.marks = const [],
    this.notesPhase = TalkRecordNotesPhase.idle,
  });

  TalkRecordDetailState copyWith({
    EntityId? recordId,
    TalkRecordDetailPhase? phase,
    TalkRecordModel? record,
    String? recordEtag,
    TalkRecordSummaryModel? summary,
    List<TalkRecordMarkModel>? marks,
    TalkRecordNotesPhase? notesPhase,
  }) {
    return TalkRecordDetailState(
      recordId: recordId ?? this.recordId,
      phase: phase ?? this.phase,
      record: record ?? this.record,
      recordEtag: recordEtag ?? this.recordEtag,
      summary: summary ?? this.summary,
      marks: marks ?? this.marks,
      notesPhase: notesPhase ?? this.notesPhase,
    );
  }
}

enum TalkRecordSegmentsPhase { idle, loading, ready, failed }

class TalkRecordSegmentsState {
  final EntityId recordId;
  final TalkRecordSegmentsPhase phase;
  final List<TalkRecordSegmentModel> segments;

  /// 本地搜索词（服务端已返回全量片段；高亮/过滤在视图层，§4 q 命中
  /// 返回高亮位置——组件阶段以本地包含匹配近似）。
  final String query;

  const TalkRecordSegmentsState({
    this.recordId = '',
    this.phase = TalkRecordSegmentsPhase.idle,
    this.segments = const [],
    this.query = '',
  });

  TalkRecordSegmentsState copyWith({
    EntityId? recordId,
    TalkRecordSegmentsPhase? phase,
    List<TalkRecordSegmentModel>? segments,
    String? query,
  }) {
    return TalkRecordSegmentsState(
      recordId: recordId ?? this.recordId,
      phase: phase ?? this.phase,
      segments: segments ?? this.segments,
      query: query ?? this.query,
    );
  }
}

enum TalkRecordSpeakersPhase { idle, loading, ready, failed }

class TalkRecordSpeakersState {
  final EntityId recordId;
  final TalkRecordSpeakersPhase phase;
  final List<TalkRecordSpeakerModel> speakers;

  /// 最近一次认领冲突（409：已被他人认领，走 owner 人工纠正）。
  final bool claimConflict;

  const TalkRecordSpeakersState({
    this.recordId = '',
    this.phase = TalkRecordSpeakersPhase.idle,
    this.speakers = const [],
    this.claimConflict = false,
  });

  TalkRecordSpeakersState copyWith({
    EntityId? recordId,
    TalkRecordSpeakersPhase? phase,
    List<TalkRecordSpeakerModel>? speakers,
    bool? claimConflict,
  }) {
    return TalkRecordSpeakersState(
      recordId: recordId ?? this.recordId,
      phase: phase ?? this.phase,
      speakers: speakers ?? this.speakers,
      claimConflict: claimConflict ?? this.claimConflict,
    );
  }
}

class TalkRecordPlayerState {
  final EntityId recordId;
  final int durationMs;
  final int positionMs;
  final bool playing;

  /// 已载入受控源（票据 URL 生效）。
  final bool loaded;

  /// 当前主体无回放能力或票据持续失败（如实禁用，不假装可播）。
  final bool unavailable;

  /// 最近一次动作失败（如续签被拒——撤权语义），可重试。
  final bool failure;

  const TalkRecordPlayerState({
    this.recordId = '',
    this.durationMs = 0,
    this.positionMs = 0,
    this.playing = false,
    this.loaded = false,
    this.unavailable = false,
    this.failure = false,
  });

  TalkRecordPlayerState copyWith({
    EntityId? recordId,
    int? durationMs,
    int? positionMs,
    bool? playing,
    bool? loaded,
    bool? unavailable,
    bool? failure,
  }) {
    return TalkRecordPlayerState(
      recordId: recordId ?? this.recordId,
      durationMs: durationMs ?? this.durationMs,
      positionMs: positionMs ?? this.positionMs,
      playing: playing ?? this.playing,
      loaded: loaded ?? this.loaded,
      unavailable: unavailable ?? this.unavailable,
      failure: failure ?? this.failure,
    );
  }
}
