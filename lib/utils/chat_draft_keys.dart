/// Ownerless legacy drafts are deliberately excluded from this namespace.
/// Capture these keys when creating a composer so delayed writes keep its owner.
({String text, String cursor})? chatDraftKeys(
  String accountId,
  String type,
  String peerId,
) {
  if (accountId.isEmpty) return null;
  final scope = [accountId, type, peerId].map(Uri.encodeComponent).join(':');
  return (text: 'draft_v2:$scope', cursor: 'draftCursor_v2:$scope');
}
