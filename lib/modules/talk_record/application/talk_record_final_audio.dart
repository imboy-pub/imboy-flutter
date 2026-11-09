part of 'talk_record_attachment_upload_gateway.dart';

/// 成品合成与 direct 直传编排（no-backend-ffmpeg V1 T2）。
///
/// 合同（PLAN §T2）：
/// * 合成字节严格等于有序原段明文；同源必得同 hash（确定性拼接）。
/// * 逐段解密→核明文 SHA/size→段级 ADTS 自检→按 seq append→原子 rename；
///   绝不把整份成品 readAsBytes（段级 30 秒明文有界，成品只走流式 append
///   与流式 hash）。
/// * 成品身份（稳定 client_upload_id、object_key、sha256/size/样本轴、
///   confirmed）冻结进 checkpoint；不存时效 URL 或凭据。
/// * 恢复先查服务端 status：CONFIRMED 短路（不因本地明文已删除而重新合成
///   或换新身份）；RESERVED/DECLARED/GRANTED/FINALIZING 沿原 client_upload_id
///   幂等补齐（同源字节重合成得同 hash，declare 同值幂等，不冲突）。
/// * final 仅在真实 CONFIRMED 后送 complete；FINALIZING/隔离态不发布。
extension _TalkRecordFinalAudio on TalkRecordAttachmentUploadGateway {
  /// 确保成品已合成并 direct CONFIRMED，冻结声明（wire 形态，
  /// 'confirmed' == true）入 checkpoint。幂等：可任意次重入。
  Future<void> _finalAudio(
    TalkRecordLocalBinding b,
    TalkRecordManifest manifest,
    Directory directory,
    TalkRecordKeyStore keys,
    TalkRecordUploadCheckpoint cp,
    TalkRecordUploadCheckpointStore store,
    void Function() guard,
    CancelToken? cancelToken,
  ) async {
    // 1. 已冻结且 CONFIRMED：直接发布冻结身份（密文段/明文均无需在场）。
    if (cp.finalAudio['confirmed'] == true) {
      _requireWellFormed(cp.finalAudio);
      return;
    }

    // 2. 沿原身份恢复：checkpoint 已有会话 → 先查服务端权威状态。
    if (_hasIdentity(cp.finalAudio)) {
      final objectKey = '${cp.finalAudio['object_key']}';
      guard();
      final status = await directStatus(objectKey, cancelToken: cancelToken);
      guard();
      if (status.state == DirectAttachmentApi.stateConfirmed) {
        cp.finalAudio = Map<String, dynamic>.from(cp.finalAudio)
          ..['confirmed'] = true;
        await store.save(cp);
        _requireWellFormed(cp.finalAudio);
        return;
      }
      // RESERVED/DECLARED/GRANTED/FINALIZING：走下方全链幂等补齐。
    }

    // 3. 合成成品：逐段解密→核 sha/size→段级 ADTS 自检→按 seq append→
    //    原子 rename。任何失败保留加密原段，临时明文由 finally 收敛。
    final plaintextDir = Directory('${directory.path}/.upload_plain');
    await _clearPlaintext(plaintextDir);
    try {
      await plaintextDir.create(recursive: true);
      final tmp = File('${plaintextDir.path}/final.aac.tmp');
      final sink = tmp.openWrite();
      var closed = false;
      try {
        var samples = 0;
        int? rate, channels;
        for (final segment in manifest.segments) {
          guard();
          final plain = File('${plaintextDir.path}/part-${segment.seq}.aac');
          await _decrypt(b, segment, directory, plain, keys, guard);
          guard();
          final bytes = await plain.readAsBytes();
          final summary = talkRecordAdtsScan(bytes);
          if (rate != null &&
              (rate != summary.sampleRateHz ||
                  channels != summary.numChannels)) {
            throw StateError('Final audio parameter drift across parts');
          }
          rate = summary.sampleRateHz;
          channels = summary.numChannels;
          samples += summary.sampleCount;
          sink.add(bytes);
          await plain.delete();
        }
        await sink.flush();
        await sink.close();
        closed = true;
        guard();
        final finalFile = File('${plaintextDir.path}/final.aac');
        await tmp.rename(finalFile.path);
        final sha = await sha256OfFile(finalFile);
        final size = await finalFile.length();

        // 冻结声明（先落盘再上传：grant/PUT/任何回包丢失后都沿同身份恢复，
        // 不产生第二条会话）。
        final identity = Map<String, dynamic>.from(cp.finalAudio);
        identity['client_upload_id'] ??= TalkRecordIds.newUuidV4();
        cp.finalAudio = identity
          ..['sha256'] = sha
          ..['byte_size'] = size
          ..['sample_rate'] = rate
          ..['channels'] = channels
          ..['sample_count'] = samples
          ..['duration_ms'] = msOfSamples(samples, rate!)
          ..remove('confirmed');
        await store.save(cp);

        // 4. register 单步（同 client_upload_id 幂等）：object_key 在任何
        //    PUT/finalize 之前产生并立即落盘——恢复链上 status 查询以
        //    object_key 为键，崩溃窗口不丢单。
        if (!identity.containsKey('object_key') ||
            '${identity['object_key']}'.isEmpty) {
          guard();
          final objectKey = await directRegister(
            identity['client_upload_id'] as String,
            b.recordId,
            cancelToken: cancelToken,
          );
          guard();
          cp.finalAudio = Map<String, dynamic>.from(cp.finalAudio)
            ..['object_key'] = objectKey;
          await store.save(cp);
          // register 幂等找回的可能是已 CONFIRMED 的旧会话（finalize 成功
          // 而 confirmed 落盘前崩溃的窗口）：status 复查，短路不重传。
          guard();
          final status = await directStatus(
            objectKey,
            cancelToken: cancelToken,
          );
          guard();
          if (status.state == DirectAttachmentApi.stateConfirmed) {
            cp.finalAudio = Map<String, dynamic>.from(cp.finalAudio)
              ..['confirmed'] = true;
            await store.save(cp);
            _requireWellFormed(cp.finalAudio);
            return;
          }
        }

        // 5. direct 上传（register 同声明幂等；scope talk_record + recordId
        //    供服务端 complete 反查准入事实）。
        guard();
        final uploaded = await directUpload(
          finalFile,
          clientUploadId: cp.finalAudio['client_upload_id'] as String,
          scopeRef: b.recordId,
          cancelToken: cancelToken,
        );
        guard();
        if (uploaded.state != DirectAttachmentApi.stateConfirmed) {
          // FINALIZING/UNKNOWN_QUARANTINED：不发布（PLAN：final 仅在真实
          // CONFIRMED 后送 complete），服务端收敛后恢复链再试。
          throw StateError('Final audio verification pending');
        }
        cp.finalAudio = Map<String, dynamic>.from(cp.finalAudio)
          ..['confirmed'] = true;
        await store.save(cp);
        _requireWellFormed(cp.finalAudio);
      } finally {
        if (!closed) {
          await sink.close();
        }
      }
    } finally {
      await _clearPlaintext(plaintextDir);
    }
  }

  bool _hasIdentity(Map<String, dynamic> frozen) =>
      frozen['client_upload_id'] is String &&
      (frozen['client_upload_id'] as String).isNotEmpty &&
      frozen['object_key'] is String &&
      (frozen['object_key'] as String).isNotEmpty;

  void _requireWellFormed(Map<String, dynamic> frozen) {
    if (!TalkRecordFinalAudioDecl.fromJson(frozen).isWellFormed ||
        frozen['confirmed'] != true) {
      throw StateError('Frozen final identity is corrupt');
    }
  }
}
