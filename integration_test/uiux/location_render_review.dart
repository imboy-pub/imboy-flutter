/// Match only observations explicitly supplied for this exact native capture.
bool matchesLocationRenderReview(
  Object? value, {
  required String runTag,
  required String stage,
  required String screenshotSha256,
  bool requireSceneChanged = false,
}) =>
    value is Map<String, dynamic> &&
    value['run_tag'] == runTag &&
    value['stage'] == stage &&
    value['screenshot_sha256'] == screenshotSha256 &&
    value['map_visible'] == true &&
    value['placeholder_absent'] == true &&
    (!requireSceneChanged || value['scene_changed'] == true);
