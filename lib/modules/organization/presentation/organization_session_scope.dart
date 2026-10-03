/// Local organization UI scope follows the authoritative login session.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

typedef OrganizationSessionScope = ({String uid, int generation});
final organizationSessionScopeProvider = Provider<OrganizationSessionScope>((
  ref,
) {
  ref.watch(currentUserProvider);
  final repo = ref.watch(userRepoProvider);
  return (uid: repo.currentUid, generation: repo.sessionGeneration);
});

class OrganizationSessionBoundary extends ConsumerWidget {
  const OrganizationSessionBoundary({super.key, required this.builder});
  final Widget Function(String accountKey) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(organizationSessionScopeProvider);
    if (session.uid.isEmpty) return const SizedBox.shrink();
    return KeyedSubtree(key: ValueKey(session), child: builder(session.uid));
  }
}
