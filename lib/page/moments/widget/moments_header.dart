import 'package:flutter/material.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/theme/default/app_radius.dart';

class MomentsHeader extends StatelessWidget {
  const MomentsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Cover Photo
        Container(
          margin: const EdgeInsets.only(bottom: 30),
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.grey,
            image: DecorationImage(
              image: NetworkImage(
                'https://picsum.photos/800/600', // Placeholder cover
              ),
              fit: BoxFit.cover,
            ),
          ),
        ),
        // Avatar
        Positioned(
          bottom: 10,
          right: 20,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, right: 10),
                child: Text(
                  UserRepoLocal.to.current.nickname,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 2,
                        color: Colors.black,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: AppRadius.borderRadiusSmall,
                ),
                child: Avatar(
                  imgUri: UserRepoLocal.to.current.avatar,
                  width: 70,
                  height: 70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
