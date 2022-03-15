// import 'package:flutter/widgets.dart';
// import 'package:flutter_chat_ui/flutter_chat_ui.dart';
//
//
// @immutable
// class PartialVideo {
//   /// Creates a partial video message with all variables video can have.
//   /// Use [VideoMessage] to create a full message.
//   /// You can use [VideoMessage.fromPartial] constructor to create a full
//   /// message from a partial one.
//   const PartialVideo({
//     required this.length,
//     this.mimeType,
//     required this.uri,
//     required this.thumbUri,
//   });
//
//   /// Creates a partial video message from a map (decoded JSON).
//   PartialVideo.fromJson(Map<String, dynamic> json)
//       : length = Duration(milliseconds: json['length'] as int),
//         mimeType = json['mimeType'] as String?,
//         thumbUri = json['thumbUri'] as String,
//         uri = json['uri'] as String;
//
//   /// Converts a partial video message to the map representation, encodable to JSON.
//   Map<String, dynamic> toJson() => {
//         'length': length,
//         'mimeType': mimeType,
//         'uri': uri,
//         'thumbUri': thumbUri,
//       };
//
//   /// The length of the video
//   final Duration length;
//
//   /// Media type
//   final String? mimeType;
//
//   /// The video file source (either a remote URL or a local resource)
//   final String uri;
//   final String thumbUri;
// }
//
// /// A class that represents video message.
// @immutable
// class VideoMessage extends Message {
//   /// Creates an video message.
//   const VideoMessage({
//     required String authorId,
//     required this.length,
//     required String id,
//     Map<String, dynamic>? metadata,
//     this.mimeType,
//     Status? status,
//     int? timestamp,
//     required this.uri,
//   }) : super(authorId, id, metadata, status, timestamp, MessageType.video);
//
//   /// Creates a full video message from a partial one.
//   VideoMessage.fromPartial({
//     required String authorId,
//     required String id,
//     Map<String, dynamic>? metadata,
//     required PartialVideo partialVideo,
//     Status? status,
//     int? timestamp,
//   })  : length = partialVideo.length,
//         mimeType = partialVideo.mimeType,
//         uri = partialVideo.uri,
//         super(
//           authorId,
//           id,
//           metadata,
//           status,
//           timestamp,
//           MessageType.video,
//         );
//
//   /// Creates an video message from a map (decoded JSON).
//   VideoMessage.fromJson(Map<String, dynamic> json)
//       : length = Duration(milliseconds: json['length'] as int),
//         mimeType = json['mimeType'] as String?,
//         uri = json['uri'] as String,
//         thumbUri = json['thumbUri'] as String,
//         super(
//           json['authorId'] as String,
//           json['id'] as String,
//           json['metadata'] as Map<String, dynamic>?,
//           getStatusFromString(json['status'] as String?),
//           json['timestamp'] as int?,
//           MessageType.video,
//         );
//
//   /// Converts an video message to the map representation, encodable to JSON.
//   @override
//   Map<String, dynamic> toJson() => {
//         'authorId': authorId,
//         'length': length.inMilliseconds,
//         'id': id,
//         'metadata': metadata,
//         'mimeType': mimeType,
//         'status': status,
//         'timestamp': timestamp,
//         'type': 'video',
//         'uri': uri,
//       };
//
//   /// Creates a copy of the video message with an updated data
//   @override
//   Message copyWith({
//     Map<String, dynamic>? metadata,
//     PreviewData? previewData,
//     Status? status,
//   }) {
//     return VideoMessage(
//       authorId: authorId,
//       length: length,
//       id: id,
//       metadata: metadata == null
//           ? null
//           : {
//               ...this.metadata ?? {},
//               ...metadata,
//             },
//       mimeType: mimeType,
//       status: status ?? this.status,
//       timestamp: timestamp,
//       uri: uri,
//     );
//   }
//
//   /// Equatable props
//   @override
//   List<Object?> get props => [
//         authorId,
//         length,
//         id,
//         metadata,
//         mimeType,
//         status,
//         timestamp,
//         uri,
//       ];
//
//   /// The length of the video
//   final Duration length;
//
//   /// Media type
//   final String? mimeType;
//
//   /// The video source (either a remote URL or a local resource)
//   final String uri;
// }
