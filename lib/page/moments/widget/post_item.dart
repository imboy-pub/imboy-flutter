import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';

class PostItem extends StatefulWidget {
  final int index;

  const PostItem({super.key, required this.index});

  @override
  State<PostItem> createState() => _PostItemState();
}

class _PostItemState extends State<PostItem> {
  bool isLiked = false;

  void _showImageGallery(BuildContext context, int initialIndex, int count) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            alignment: Alignment.bottomRight,
            children: [
              PhotoViewGallery.builder(
                scrollPhysics: const BouncingScrollPhysics(),
                builder: (BuildContext context, int index) {
                  return PhotoViewGalleryPageOptions(
                    imageProvider: const NetworkImage(
                      'https://picsum.photos/800/800',
                    ), // Placeholder
                    initialScale: PhotoViewComputedScale.contained,
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 2,
                  );
                },
                itemCount: count,
                loadingBuilder: (context, event) =>
                    const Center(child: CircularProgressIndicator()),
                pageController: PageController(initialPage: initialIndex),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCommentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: t.commentPlaceholder,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.borderRadiusSmall,
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: Send comment
                },
                child: Text(
                  context.t.momentsSend,
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleLike() {
    setState(() {
      isLiked = !isLiked;
    });
  }

  Widget _buildImageGrid(BuildContext context) {
    int imageCount = (widget.index % 9) + 1;

    // 1 Image
    if (imageCount == 1) {
      return GestureDetector(
        onTap: () => _showImageGallery(context, 0, 1),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
          child: Image.network(
            'https://picsum.photos/400/400',
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 200,
                height: 200,
                color: Colors.grey[300],
                child: const Center(child: CircularProgressIndicator()),
              );
            },
          ),
        ),
      );
    }

    // 4 Images (2x2)
    if (imageCount == 4) {
      return SizedBox(
        width: 200, // 2 * (80 + 5) approx
        child: Wrap(
          spacing: 5,
          runSpacing: 5,
          children: List.generate(
            4,
            (imgIndex) => GestureDetector(
              onTap: () => _showImageGallery(context, imgIndex, 4),
              child: Container(
                width: 90,
                height: 90,
                color: Colors.grey[300],
                child: Image.network(
                  'https://picsum.photos/200/200?random=$imgIndex',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Other (Grid of 3 columns)
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: List.generate(
        imageCount,
        (imgIndex) => GestureDetector(
          onTap: () => _showImageGallery(context, imgIndex, imageCount),
          child: Container(
            width: 80,
            height: 80,
            color: Colors.grey[300],
            child: Image.network(
              'https://picsum.photos/200/200?random=$imgIndex',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Avatar(
            imgUri:
                'https://api.dicebear.com/7.x/avataaars/svg?seed=${widget.index}',
            width: 45,
            height: 45,
          ),
          const SizedBox(width: 10),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  'User ${widget.index}',
                  style: const TextStyle(
                    color: Color(0xFF576b95), // WeChat nickname color
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                // Text Content
                const Text(
                  'This is a sample post content to demonstrate the layout of the Moments feed. It can support multiple lines of text.',
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 10),

                // Image Grid
                _buildImageGrid(context),

                const SizedBox(height: 10),
                // Time and Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '2 hours ago',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: AppRadius.borderRadiusTiny,
                      ),
                      child: GestureDetector(
                        onTap: () => _showCommentSheet(context),
                        child: const Icon(
                          Icons.more_horiz,
                          size: 18,
                          color: Color(0xFF576b95),
                        ),
                      ),
                    ),
                  ],
                ),
                // Likes and Comments area (Placeholder)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: AppRadius.borderRadiusTiny,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Likes
                      GestureDetector(
                        onTap: _toggleLike,
                        child: Row(
                          children: [
                            isLiked
                                ? const Icon(
                                    Icons.favorite,
                                    size: 14,
                                    color: Colors.red,
                                  ).animate().scale(
                                    duration: 300.ms,
                                    curve: Curves.elasticOut,
                                  )
                                : const Icon(
                                    Icons.favorite_border,
                                    size: 14,
                                    color: Color(0xFF576b95),
                                  ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                isLiked
                                    ? 'Me, User A, User B, User C'
                                    : 'User A, User B, User C',
                                style: const TextStyle(
                                  color: Color(0xFF576b95),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 10, color: Colors.black12),
                      // Comments
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 2,
                        itemBuilder: (context, commentIndex) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'User ${commentIndex + 1}: ',
                                    style: const TextStyle(
                                      color: Color(0xFF576b95),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const TextSpan(text: 'Nice post!'),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
