/// Ephemeral UI request ownership. It never deletes local recordings or audio.
library;

class TalkRecordDetailRequestFence {
  TalkRecordDetailRequestFence(this.mounted);
  final bool Function() mounted;
  int _epoch = 0;
  int _request = 0;

  void reset() {
    _epoch++;
    _request++;
  }

  TalkRecordDetailRequest begin() =>
      TalkRecordDetailRequest._(this, _epoch, ++_request);
  TalkRecordDetailRequest snapshot() =>
      TalkRecordDetailRequest._(this, _epoch, _request);
}

class TalkRecordDetailRequest {
  TalkRecordDetailRequest._(this._fence, this._epoch, this._request);
  final TalkRecordDetailRequestFence _fence;
  final int _epoch;
  final int _request;
  bool get scopeCurrent => _fence.mounted() && _fence._epoch == _epoch;
  bool get current => scopeCurrent && _fence._request == _request;
}
