# IMBoy Flutter Module Map

> Date: 2026-03-29
> Scope: client-side feature module boundaries, public entry rules, and plugin extension points
> Status: All domain modules have stable public.dart entries. dart analyze clean.

## Module Layout

- `lib/app_core`
  - cross-domain app services such as feature flags, route guards, app bootstrap, and shared runtime coordination
- `lib/modules/*`
  - feature modules grouped by business domain, with internal application/domain/infrastructure/presentation folders as needed
- `lib/plugins/contracts`
  - lightweight contracts for high-change extension points
- `lib/plugins/registry`
  - in-repo registries that wire built-in plugins and resolve active implementations

## Hard Rules

- External callers may only import `lib/modules/<domain>/public.dart`.
- New shared app runtime behavior should prefer `lib/app_core` over adding more global helpers under `service/`.
- Plugin contracts are for high-change extension points only. Core routing, auth, message consistency, and state synchronization remain normal module code.

## Initial Domain Targets

| Area | Current roots | Future public entry |
|---|---|---|
| App core | `lib/config/`, `lib/service/feature_registry.dart`, router guards, shared app bootstrap helpers | `lib/app_core/...` |
| Messaging | `lib/page/chat/`, `lib/page/conversation/`, `lib/service/message.dart`, `lib/service/message_actions.dart` | `lib/modules/messaging/public.dart` |
| Moment social | `lib/page/moment/`, related stores/services | `lib/modules/moment_social/public.dart` |
| Channel content | `lib/page/channel/`, `lib/service/channel_service.dart` | `lib/modules/channel_content/public.dart` |
| Group collaboration | `lib/page/group/`, group vote/schedule/task services | `lib/modules/group_collab/public.dart` |
| Identity | `lib/page/passport/`, auth/session bootstrap and related services | `lib/modules/identity/public.dart` |
| Social graph | `lib/page/contact/`, tag/contact relation pages and mention services | `lib/modules/social_graph/public.dart` |
| Security/privacy | `lib/service/e2ee/`, recovery/backup flows, privacy-related settings pages | `lib/modules/security_privacy/public.dart` |
| Ops/governance | feedback, version, feature gate, notification and settings support flows | `lib/modules/ops_governance/public.dart` |

## Migration Note

Existing `service/` and `page/` files may remain as compatibility wrappers during migration, but new imports should converge on module public entries rather than reaching into module internals.
