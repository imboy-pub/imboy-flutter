"""Step 9: 领域 capability 矩阵、隔离夹具合同与零交互 preflight 决策快照。

- generate_domain_matrix：从 ../imboy/config/product-feature-manifest.json 的
  selected_features + 计划 Step 9 必须覆盖 capability 集，生成
  test/auto_test/domain_coverage.json（只存声明性要求，不存运行 verdict）。
  app/backend targets 只收录生成当刻真实存在的文件（机器优先，宁缺标 BLOCKED）。
- validate_domain：DOM-002 面——启用 feature 无映射、capability 缺 target、
  证据等级低于类型最低值 / D 级填充均报错。
- validate_fixtures_contract：DOM-003 面——六匿名账号 + 互异设备身份 + 无凭证。
- collect_preflight_snapshot：route drift / 本地后端可用性 / D2 / 设备只读探测，
  把影响映射到具体 capability/shard，写 RUN_ROOT/steps/step9_preflight_snapshot.json。
"""
from __future__ import annotations

import datetime as _dt
import fnmatch
import json
import re
import subprocess
import sys
from pathlib import Path
from urllib.error import URLError
from urllib.request import urlopen

if __package__ in (None, ''):  # 允许直跑
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from auto_test_lib import discovery  # noqa: E402

DOMAIN_SCHEMA_VERSION = 1
FIXTURES_SCHEMA_VERSION = 1
DOMAIN_PATH = ('test', 'auto_test', 'domain_coverage.json')
FIXTURES_PATH = ('test', 'auto_test', 'fixtures_contract.json')
MANIFEST_REL = '../imboy/config/product-feature-manifest.json'
RUN_ID = 'hardening-20260918T151153Z'
LEVEL_RANK = {'D': 0, 'C': 1, 'B': 2, 'A': 3}

# ---------------------------------------------------------------------------
# capability 声明表（计划 Step 9 必须覆盖集 + location/bot_webhook 补充映射）
# level = 计划 §4.3 类型最低值：真客户端聊天/跨角色写/真机业务闭环 = A；
# App/Backend 合同 = B。spec 只能上调，不能下调。
# ---------------------------------------------------------------------------

_E2EE_A = '双端真客户端证据（Android 真机 + macOS）'
_E2EE_B = 'App/Backend 合同测试（当前 HEAD 可重放）'

CAPABILITY_SPECS: list[dict] = [
    # ---- E2EE（12）----
    dict(capability_id='e2ee.plaintext_rejection', feature_key='e2ee', domain='e2ee', min_level='B',
         positive='加密会话内正常收发密文消息', negative='明文帧/明文降级请求被服务端与对端 fail-closed 拒绝',
         recovery='降级被拒后重试仍走加密路径且不丢消息',
         app_globs=['test/unit_test/service/e2ee/plain_text_log_test.dart',
                    'test/unit_test/service/e2ee/retry_plaintext_guard_test.dart',
                    'test/unit_test/service/e2ee/retry_plaintext_guard_c2g_test.dart',
                    'integration_test/chat/c2c_plaintext_reject_test.dart'],
         backend_globs=['test/e2ee_safety_contract_tests.erl', 'test/logic/e2ee_logic_tests.erl'],
         fixture='iso:user_device_a+user_device_b', requirements=['backend.local', 'fixture.disposable_account']),
    dict(capability_id='e2ee.c2c_olm', feature_key='e2ee', domain='e2ee', min_level='A',
         positive='双端 C2C Olm 会话建立、发送与对端解密', negative='C2C 不误用 Megolm；错误设备帧被拒',
         recovery='会话中断后重进恢复并续传',
         app_globs=['test/unit_test/service/e2ee/c2c_olm_not_megolm_test.dart',
                    'test/unit_test/service/e2ee/olm_protocol_test.dart',
                    'integration_test/e2ee_olm_device_test.dart',
                    'integration_test/e2ee_c2c_outbound_frame_test.dart',
                    'integration_test/chat/c2c_e2ee_send_render_test.dart',
                    'integration_test/e2ee_cross_platform_interop_test.dart'],
         backend_globs=['make:e2ee-verify', 'test/ds/e2ee_v3_passthrough_contract_tests.erl',
                        'test/integration/e2ee_message_pipeline_integration_tests.erl'],
         fixture='iso:user_device_a+user_device_b', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account']),
    dict(capability_id='e2ee.c2g_megolm_roomkey', feature_key='e2ee', domain='e2ee', min_level='A',
         positive='C2G Megolm 群会话 + room-key 经 Olm 按设备分发', negative='非成员/被移除设备收不到 room key',
         recovery='重进群后重新拉取 room key 并解密',
         app_globs=['test/unit_test/service/e2ee/megolm_backup_section_test.dart',
                    'test/unit_test/service/e2ee/megolm_history_grant_test.dart',
                    'integration_test/e2ee_megolm_device_test.dart',
                    'integration_test/e2ee_group_outbound_frame_test.dart',
                    'integration_test/e2ee_cross_platform_group_interop_test.dart',
                    'integration_test/chat/c2g_e2ee_loop_sender_test.dart',
                    'integration_test/chat/c2g_e2ee_loop_receiver_test.dart'],
         backend_globs=['make:e2ee-verify', 'test/ds/e2ee_c2g_passthrough_contract_tests.erl',
                        'test/integration/e2ee_c2g_message_pipeline_integration_tests.erl'],
         fixture='iso:user_device_a+user_device_b', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account']),
    dict(capability_id='e2ee.multi_device_fanout', feature_key='e2ee', domain='e2ee', min_level='A',
         positive='同一账号多设备各自获得独立密文 fan-out', negative='离线/被吊销设备不再收到新帧',
         recovery='设备重新上线后按各自 session 恢复',
         app_globs=['test/unit_test/service/e2ee/fan_out_per_device_test.dart',
                    'test/unit_test/service/e2ee/device_manifest_test.dart',
                    'integration_test/e2ee_cross_platform_interop_test.dart',
                    'test/unit_test/integration/e2ee_integration_test.dart'],
         backend_globs=['make:e2ee-verify', 'test/ds/e2ee_sender_device_envelope_tests.erl',
                        'test/ds/e2ee_offline_sender_did_tests.erl'],
         fixture='iso:user_device_a+user_device_b', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account']),
    dict(capability_id='e2ee.otk_fallback_rotation', feature_key='e2ee', domain='e2ee', min_level='B',
         positive='OTK 领取与 fallback key 轮换按策略推进', negative='OTK 耗尽/签名错误被拒且限流',
         recovery='claim 幂等重试后恢复分发',
         app_globs=['test/unit_test/service/e2ee/otk_refill_policy_test.dart',
                    'test/unit_test/service/e2ee/fallback_rotation_policy_test.dart',
                    'test/unit_test/service/e2ee/fallback_key_rotation_characterization_test.dart',
                    'test/unit_test/service/e2ee/fallback_key_signature_test.dart'],
         backend_globs=['make:e2ee-verify', 'test/api/e2ee_otk_count_tests.erl',
                        'test/api/e2ee_otk_target_throttle_tests.erl',
                        'test/logic/e2ee_otk_claim_idempotency_tests.erl',
                        'test/logic/e2ee_fallback_signature_tests.erl',
                        'test/integration/e2ee_otk_claim_idempotency_integration_tests.erl'],
         fixture='shared:readonly', requirements=['backend.local']),
    dict(capability_id='e2ee.identity_trust_change', feature_key='e2ee', domain='e2ee', min_level='B',
         positive='safety number/trust event 变更被两端观测', negative='被替换身份的信任变更触发告警而非静默接受',
         recovery='信任重置后重新验证并恢复会话',
         app_globs=['test/unit_test/service/e2ee/safety_number_test.dart',
                    'test/unit_test/service/e2ee/safety_number_service_test.dart',
                    'test/unit_test/service/e2ee/tofu_identity_pin_test.dart',
                    'test/unit_test/service/e2ee/identity_verifier_test.dart',
                    'test/unit_test/service/e2ee/trust_event_client_test.dart',
                    'test/unit_test/service/e2ee/trust_event_canonical_test.dart'],
         backend_globs=['make:e2ee-verify', 'test/logic/e2ee_trust_logic_tests.erl',
                        'test/lib/e2ee_kt_merkle_tests.erl'],
         fixture='iso:user_device_a+user_device_b', requirements=['backend.local', 'fixture.disposable_account']),
    dict(capability_id='e2ee.replay_tamper_order', feature_key='e2ee', domain='e2ee', min_level='B',
         positive='合法消息按序送达且 ACK 对齐', negative='replay/tamper/乱序帧被拒，不产生可观察明文',
         recovery='拒收后重放窗口重置不影响后续消息',
         app_globs=['test/unit_test/service/e2ee/replay_counter_epoch_test.dart',
                    'test/unit_test/service/e2ee/inbound_ack_ordering_test.dart',
                    'test/unit_test/service/e2ee/production_inbound_frame_gate_test.dart',
                    'test/unit_test/service/e2ee/mutation_matrix_test.dart'],
         backend_globs=['make:e2ee-verify', 'test/e2ee_safety_contract_tests.erl',
                        'test/ds/e2ee_sender_device_envelope_tests.erl'],
         fixture='shared:readonly', requirements=['backend.local']),
    dict(capability_id='e2ee.attachment', feature_key='e2ee', domain='e2ee', min_level='A',
         positive='附件端侧加密上传，对端解密打开', negative='MIME 绑定不符/未封印附件被拒',
         recovery='分片中断后续传并重新校验封印',
         app_globs=['test/unit_test/service/e2ee/attachment_encryptor_test.dart',
                    'test/unit_test/service/e2ee/attachment_open_e2e_test.dart',
                    'test/unit_test/service/e2ee/attachment_seal_wiring_test.dart',
                    'test/unit_test/service/e2ee/attachment_thumb_seal_test.dart',
                    'test/unit_test/store/attachment_upload_presign_test.dart'],
         backend_globs=['make:e2ee-verify', 'test/lib/e2ee_presign_mime_binding_tests.erl'],
         fixture='iso:user_device_a+user_device_b', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account']),
    dict(capability_id='e2ee.backup_recovery', feature_key='e2ee', domain='e2ee', min_level='A',
         positive='备份导出后在新设备恢复会话密钥', negative='口令/密钥错误的恢复被拒且不泄露数据',
         recovery='恢复失败后原设备数据完好可重试',
         app_globs=['integration_test/settings/e2ee_backup_recovery_acceptance_test.dart',
                    'integration_test/settings/e2ee_backup_import_acceptance_test.dart',
                    'integration_test/settings/e2ee_key_recovery_acceptance_test.dart',
                    'integration_test/settings/e2ee_backup_setup_wizard_test.dart',
                    'test/unit_test/service/e2ee_backup_restore_test.dart',
                    'test/unit_test/service/e2ee_local_backup_boundary_test.dart'],
         backend_globs=['make:e2ee-verify', 'test/logic/e2ee_backup_logic_tests.erl',
                        'test/logic/e2ee_recovery_logic_tests.erl', 'test/repo/e2ee_backup_repo_tests.erl'],
         fixture='iso:user_device_a+user_device_b', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account']),
    dict(capability_id='e2ee.history_member_boundary', feature_key='e2ee', domain='e2ee', min_level='A',
         positive='在册成员可解密进群前授权历史', negative='非成员/退群设备拿不到历史 room key（不穿越成员边界）',
         recovery='重新入群后按新授权范围恢复可见性',
         app_globs=['test/unit_test/service/e2ee/megolm_history_grant_test.dart',
                    'integration_test/chat/c2g_e2ee_loop_receiver_test.dart'],
         backend_globs=['make:e2ee-verify', 'test/logic/group_history_boundary_tests.erl',
                        'test/ds/group_member_workspace_subset_tests.erl'],
         fixture='iso:user_device_a+user_device_b', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account']),
    dict(capability_id='e2ee.policy_gate', feature_key='e2ee', domain='e2ee', min_level='B',
         positive='未启用 E2EE 的会话按策略显式放行', negative='无设备信封/未 onboard 对端被 gate 拒绝发送',
         recovery='gate 拒绝后按引导补齐设备再发',
         app_globs=['test/unit_test/service/e2ee/policy_gate_test.dart',
                    'test/unit_test/service/e2ee/policy_gate_retry_test.dart',
                    'test/unit_test/service/e2ee/capability_guard_test.dart',
                    'test/unit_test/service/e2ee/capability_negotiator_test.dart',
                    'integration_test/settings/e2ee_boundary_no_device_envelope_test.dart'],
         backend_globs=['make:e2ee-verify', 'test/api/e2ee_handler_capability_tests.erl',
                        'test/e2ee_safety_contract_tests.erl'],
         fixture='shared:readonly', requirements=['backend.local']),
    dict(capability_id='e2ee.log_metadata_privacy', feature_key='e2ee', domain='e2ee', min_level='B',
         positive='正常路径日志不含明文/密钥元数据', negative='错误路径日志/错误码不泄露密钥与明文',
         recovery='审计日志自检发现泄露即 fail',
         app_globs=['test/unit_test/service/e2ee/logging_privacy_guard_test.dart',
                    'test/unit_test/service/e2ee/crypto_audit_log_test.dart',
                    'test/unit_test/service/e2ee/plain_text_log_test.dart',
                    'test/unit_test/service/e2ee/decrypt_error_taxonomy_test.dart'],
         backend_globs=['make:e2ee-verify', 'test/logic/e2ee_error_privacy_tests.erl',
                        'test/lib/e2ee_error_code_tests.erl'],
         fixture='shared:readonly', requirements=['backend.local']),
    # ---- Organization / Enterprise / Customer Service（6）----
    dict(capability_id='org.lifecycle', feature_key='enterprise_business', domain='organization', min_level='B',
         positive='创建组织->查询->（ suspends 见 ent.* ）基本生命周期 API 合同', negative='非法 owner/重名/越权创建被拒',
         recovery='失败回滚后可重试创建',
         app_globs=['test/organization/organization_api_contract_test.dart',
                    'test/organization/organization_models_parse_test.dart',
                    'test/organization/organization_home_page_widget_test.dart'],
         backend_globs=['test/lib/organization/organization_lifecycle_tests.erl',
                        'test/logic/organization_logic_tests.erl',
                        'test/api/organization_handler_tests.erl',
                        'test/repo/organization_repo_tests.erl'],
         fixture='iso:orgA_owner', requirements=['backend.local', 'fixture.disposable_account', 'authorization.business_write']),
    dict(capability_id='org.owner_member_department_invitation', feature_key='enterprise_business', domain='organization', min_level='B',
         positive='owner/member/部门/邀请全链路角色合同', negative='普通成员访问治理端点=403；owner 单例不可移除自身',
         recovery='角色变更失败后旧 token 不再具备已撤销权限',
         app_globs=['test/organization/organization_api_contract_test.dart',
                    'test/organization/organization_cache_scope_test.dart'],
         backend_globs=['test/lib/organization/organization_owner_invariant_tests.erl',
                        'test/lib/organization/organization_owner_transfer_tests.erl',
                        'test/lib/organization/organization_department_tests.erl',
                        'test/lib/organization/organization_department_app_gate_tests.erl',
                        'test/lib/organization/organization_invitation_tests.erl',
                        'test/api/organization_member_handler_tests.erl',
                        'test/logic/organization_member_logic_tests.erl',
                        'test/repo/organization_member_repo_tests.erl'],
         fixture='iso:orgA_owner+orgA_member', requirements=['backend.local', 'fixture.disposable_account', 'authorization.business_write']),
    dict(capability_id='org.default_workspace', feature_key='enterprise_business', domain='organization', min_level='B',
         positive='建组织自动产生默认 workspace 且可解析', negative='非成员不可解析他人默认 workspace',
         recovery='默认 workspace 缺失时 fail-closed 而非空解析',
         app_globs=['test/organization/organization_home_page_widget_test.dart'],
         backend_globs=['test/lib/organization/organization_default_workspace_tests.erl',
                        'test/ds/workspace_org_default_relation_tests.erl',
                        'test/lib/workspace_resolver_tests.erl'],
         fixture='iso:orgA_owner', requirements=['backend.local', 'fixture.disposable_account']),
    dict(capability_id='ent.identity_contact_conversation_message_asset', feature_key='enterprise_business', domain='enterprise', min_level='B',
         positive='企业身份/联系人/会话/消息/资产 API 合同', negative='跨企业身份/资产隔离被拒',
         recovery='企业态退化（suspend）时只读降级而非报错泄漏',
         app_globs=['test/enterprise/enterprise_api_contract_test.dart',
                    'test/enterprise/enterprise_store_isolation_test.dart',
                    'test/enterprise/enterprise_tsid_precision_test.dart'],
         backend_globs=['test/features/enterprise_business/enterprise_business_facade_tests.erl',
                        'test/features/enterprise_business/application/identity/eb_identity_projection_tests.erl'],
         fixture='iso:orgA_owner+orgB_owner', requirements=['backend.local', 'fixture.disposable_account', 'authorization.business_write']),
    dict(capability_id='cs.queue_claim_transfer_close_rating', feature_key='customer_service', domain='customer_service', min_level='B',
         positive='排队->接单->转接->关闭->评价状态机', negative='非坐席/越权接单与转接被拒',
         recovery='坐席掉线后会话回队列可被重新认领',
         app_globs=['test/customer_service/cs_state_machine_test.dart',
                    'test/customer_service/cs_session_flow_test.dart',
                    'test/customer_service/cs_session_actions_test.dart',
                    'test/customer_service/cs_session_page_test.dart',
                    'test/customer_service/cs_workspace_state_test.dart',
                    'test/customer_service/cs_api_contract_test.dart',
                    'test/customer_service/cs_seat_gate_test.dart',
                    'test/customer_service/cs_degradation_test.dart'],
         backend_globs=['test/features/customer_service/application/cs_application_tests.erl',
                        'test/features/customer_service/application/cs_list_contract_tests.erl',
                        'test/features/customer_service/application/cs_closure_tests.erl',
                        'test/features/customer_service/application/cs_widget_app_tests.erl',
                        'test/features/customer_service/application/cs_org_compat_tests.erl',
                        'test/features/customer_service/infrastructure/cs_pg_tests.erl',
                        'test/features/agent/agent_cs_adapter_acceptance_tests.erl'],
         fixture='iso:orgA_owner', requirements=['backend.local', 'fixture.disposable_account']),
    dict(capability_id='ent.suspend_offboarding_retention_audit', feature_key='enterprise_business', domain='enterprise', min_level='B',
         positive='企业暂停/离职流程/留存/审计路径合同', negative='暂停企业写操作被拒、离职成员数据按留存策略不可再访问',
         recovery='恢复企业后留存数据按审计记录恢复可见',
         app_globs=['test/enterprise/enterprise_store_isolation_test.dart',
                    'test/enterprise/enterprise_api_contract_test.dart'],
         backend_globs=['test/lib/organization/organization_agent_boundary_tests.erl',
                        'test/lib/organization/organization_agent_membership_tests.erl',
                        'test/features/enterprise_business/enterprise_business_facade_tests.erl'],
         fixture='iso:orgA_owner+orgA_member', requirements=['backend.local', 'fixture.disposable_account', 'authorization.business_write']),
    # ---- Workspace / Group（6）----
    dict(capability_id='ws.create_switch_archive_isolation', feature_key='core', domain='workspace', min_level='B',
         positive='创建/切换/归档 workspace 且互不串数据', negative='归档 workspace 拒绝写入；跨 workspace 数据隔离',
         recovery='归档解除后恢复可用且数据完好',
         app_globs=['integration_test/workspace/workspace_acceptance_batch154_test.dart',
                    'integration_test/workspace/workspace_acceptance_batch155_test.dart',
                    'integration_test/workspace/workspace_shell_acceptance_test.dart',
                    'integration_test/workspace/workspace_overview_empty_members_test.dart',
                    'test/unit_test/page/workspace/workspace_join_page_test.dart',
                    'test/unit_test/page/workspace_shell/workspace_shell_provider_test.dart'],
         backend_globs=['test/api/workspace_create_handler_tests.erl',
                        'test/api/workspace_boundary_tests.erl',
                        'test/logic/workspace_archive_tests.erl',
                        'test/logic/workspace_admin_tests.erl',
                        'test/ds/workspace_archive_closure_tests.erl'],
         fixture='iso:orgA_owner+orgB_owner', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account', 'authorization.business_write']),
    dict(capability_id='ws.member_role_invite', feature_key='core', domain='workspace', min_level='B',
         positive='成员/角色/邀请链路正向合同', negative='降权后旧 token/越权邀请被拒',
         recovery='邀请失效后可重新发起',
         app_globs=['integration_test/workspace/workspace_invite_relations_test.dart',
                    'integration_test/workspace/workspace_members_empty_test.dart',
                    'test/unit_test/page/workspace/workspace_invite_controller_test.dart',
                    'test/unit_test/page/workspace/workspace_invite_code_controller_test.dart',
                    'test/unit_test/page/workspace/workspace_members_page_test.dart'],
         backend_globs=['test/repo/workspace_invite_repo_tests.erl',
                        'test/logic/workspace_admin_archive_fk_tests.erl',
                        'test/api/workspace_boundary_tests.erl'],
         fixture='iso:orgA_owner+orgA_member', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account', 'authorization.business_write']),
    dict(capability_id='group.create_join_remove_transfer_mute', feature_key='core', domain='group', min_level='B',
         positive='建群/入群/移除/转让/禁言正向路径', negative='非 owner 转让/移除被拒；被移除成员立即失去访问',
         recovery='转让中断后 owner 不变量保持',
         app_globs=['integration_test/group/group_creation_readonly_test.dart',
                    'integration_test/group/group_member_acceptance_test.dart',
                    'integration_test/group/group_management_readonly_test.dart',
                    'integration_test/chat/group_chat_test.dart',
                    'integration_test/demo_flow/group_creation_management_flow_test.dart'],
         backend_globs=['test/logic/group_logic_tests.erl',
                        'test/logic/group_member_logic_tests.erl',
                        'test/api/group_member_handler_tests.erl',
                        'test/api/group_member_join_auth_tests.erl',
                        'test/api/group_member_transfer_tests.erl',
                        'test/integration/group_member_role_integration_tests.erl'],
         fixture='iso:orgA_owner+orgA_member+orgA_nonmember', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account', 'authorization.business_write']),
    dict(capability_id='group.e2ee', feature_key='core', domain='group', min_level='A',
         positive='群 E2EE（Megolm+Olm room key）真客户端收发', negative='非成员设备拿不到 room key；明文降级被拒',
         recovery='重进群/重启后恢复解密',
         app_globs=['integration_test/e2ee_cross_platform_group_interop_test.dart',
                    'integration_test/chat/c2g_e2ee_loop_sender_test.dart',
                    'integration_test/chat/c2g_e2ee_loop_receiver_test.dart',
                    'integration_test/e2ee_group_outbound_frame_test.dart'],
         backend_globs=['make:e2ee-verify', 'test/logic/group_e2ee_logic_tests.erl',
                        'test/ds/e2ee_c2g_passthrough_contract_tests.erl'],
         fixture='iso:user_device_a+user_device_b', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account']),
    dict(capability_id='group.notice_task_vote_schedule_file_album_tag_category', feature_key='core', domain='group', min_level='B',
         positive='公告/任务/投票/日程/文件/相册/标签/分类协作功能合同', negative='无权限成员写被拒；跨群数据不可见',
         recovery='协作项删除后聚合视图一致回退',
         app_globs=['integration_test/group/group_collaboration_readonly_test.dart',
                    'integration_test/group/group_detail_readonly_test.dart',
                    'integration_test/demo_flow/group_collaboration_flow_test.dart'],
         backend_globs=['test/logic/group_notice_logic_tests.erl',
                        'test/logic/group_task_logic_tests.erl',
                        'test/logic/group_vote_logic_tests.erl',
                        'test/logic/group_schedule_logic_tests.erl',
                        'test/logic/group_file_logic_tests.erl',
                        'test/logic/group_album_logic_tests.erl',
                        'test/logic/group_tag_logic_tests.erl',
                        'test/logic/group_category_logic_tests.erl',
                        'test/group_notice_SUITE.erl', 'test/group_vote_SUITE.erl'],
         fixture='iso:orgA_owner+orgA_member', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account', 'authorization.business_write']),
    dict(capability_id='group.cross_tenant_idor', feature_key='core', domain='group', min_level='B',
         positive='正常成员按 scope 读写本群资源', negative='跨 org/workspace/群 IDOR 与反向悬空引用 fail-closed',
         recovery='边界拒绝不产生半写状态',
         app_globs=['test/enterprise/enterprise_store_isolation_test.dart',
                    'integration_test/group/group_detail_readonly_test.dart'],
         backend_globs=['test/logic/group_scope_tests.erl',
                        'test/ds/group_member_workspace_subset_tests.erl',
                        'test/ds/group_ds_member_uids_strict_tests.erl',
                        'test/api/workspace_boundary_tests.erl'],
         fixture='iso:orgA_member+orgB_member', requirements=['backend.local', 'fixture.disposable_account']),
    # ---- Channel（6）----
    dict(capability_id='channel.create_edit_delete', feature_key='channel', domain='channel', min_level='A',
         positive='创建->编辑->删除频道真机闭环 + 持久化', negative='非管理员编辑/删除被拒',
         recovery='删除后恢复入口与缓存一致回退',
         app_globs=['test/unit_test/page/channel/channel_create_page_test.dart',
                    'test/unit_test/page/channel/channel_edit_page_test.dart',
                    'integration_test/channel/channel_e2e_test.dart',
                    'integration_test/channel/channel_edit_persistence_test.dart'],
         backend_globs=['test/logic/channel_logic_tests.erl', 'test/repo/channel_repo_tests.erl',
                        'test/api/channel_handler_tests.erl', 'test/ds/channel_ds_tests.erl'],
         fixture='iso:orgA_owner', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account', 'authorization.business_write']),
    dict(capability_id='channel.admin_subscriber_invitation', feature_key='channel_invitation', domain='channel', min_level='A',
         positive='管理员/订阅者/邀请链路真机闭环', negative='未授权角色订阅/邀请被拒',
         recovery='邀请过期后可重新生成',
         app_globs=['test/unit_test/page/channel/channel_admin_page_test.dart',
                    'test/unit_test/page/channel/channel_subscriber_page_test.dart',
                    'test/unit_test/page/channel/channel_invitation_page_test.dart',
                    'integration_test/channel/channel_subscriber_acceptance_test.dart',
                    'integration_test/channel/channel_subscriber_invite_acceptance_batch170_test.dart'],
         backend_globs=['test/repo/channel_invitation_repo_tests.erl',
                        'test/repo/channel_subscription_repo_tests.erl',
                        'test/logic/channel_logic_subscription_tests.erl'],
         fixture='iso:orgA_owner+orgA_member+orgA_nonmember', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account', 'authorization.business_write']),
    dict(capability_id='channel.publish_edit_revoke_pin_reaction_comment', feature_key='channel', domain='channel', min_level='A',
         positive='发布->编辑->撤回->置顶->反应->评论真机闭环', negative='非授权角色发布/置顶被拒；撤回后不可再见',
         recovery='发布失败出箱重试幂等',
         app_globs=['test/unit_test/page/channel/channel_compose_page_test.dart',
                    'test/unit_test/page/channel/channel_message_feed_test.dart',
                    'test/unit_test/page/channel/channel_detail_actions_test.dart',
                    'integration_test/channel/channel_publish_test.dart',
                    'integration_test/channel/channel_message_like_acceptance_test.dart'],
         backend_globs=['test/logic/channel_logic_message_tests.erl',
                        'test/logic/channel_logic_message_reactions_tests.erl',
                        'test/logic/channel_comment_logic_tests.erl',
                        'test/logic/channel_publish_idempotency_tests.erl',
                        'test/repo/channel_message_idempotency_tests.erl',
                        'test/repo/channel_message_repo_tests.erl'],
         fixture='iso:orgA_owner+orgA_member', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account', 'authorization.business_write']),
    dict(capability_id='channel.discover_search_sync_unread', feature_key='channel_discover', domain='channel', min_level='A',
         positive='发现/搜索/同步/未读真机闭环', negative='越权频道不出现在发现/搜索结果',
         recovery='同步失败后增量重试不重复计数',
         app_globs=['test/unit_test/page/channel/channel_discover_page_test.dart',
                    'test/unit_test/page/channel/channel_list_state_sync_test.dart',
                    'test/unit_test/store/repository/channel_repo_unread_atomic_test.dart',
                    'integration_test/channel/channel_discover_readonly_test.dart',
                    'integration_test/channel/channel_subscribed_detail_consistency_test.dart'],
         backend_globs=['test/logic/channel_discovery_logic_tests.erl',
                        'test/api/channel_discovery_handler_tests.erl',
                        'test/integration/channel_discovery_e2e_tests.erl'],
         fixture='iso:orgA_member', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account']),
    dict(capability_id='channel.workspace_binding', feature_key='channel', domain='channel', min_level='A',
         positive='频道绑定 workspace 后在正确的 workspace 内可见', negative='跨 workspace 访问未绑定频道被拒',
         recovery='解绑后两边视图一致回退',
         app_globs=['test/unit_test/page/workspace/workspace_channel_detail_page_test.dart',
                    'test/unit_test/page/channel/channel_detail_rules_test.dart'],
         backend_globs=['test/logic/channel_scope_tests.erl',
                        'test/api/channel_handler_tests.erl'],
         fixture='iso:orgA_owner+orgB_owner', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account', 'authorization.business_write']),
    dict(capability_id='channel.paid_order_mock', feature_key='channel_order', domain='channel', min_level='A',
         positive='付费频道订单仅走隔离 mock/本地 fixture 完成订阅闭环', negative='真实支付通道不可达；退款/管理员退款走合同负向',
         recovery='订单失败后可重试且不重复扣费（mock 计数幂等）',
         app_globs=['test/unit_test/page/channel/channel_order_list_provider_test.dart',
                    'test/unit_test/page/channel/channel_order_list_page_error_retry_test.dart',
                    'test/unit_test/page/channel/channel_order_cancel_provider_test.dart',
                    'test/unit_test/page/channel/channel_order_refund_provider_test.dart',
                    'test/unit_test/page/channel/channel_purchase_provider_test.dart',
                    'test/unit_test/store/model/channel_order_model_test.dart',
                    'integration_test/channel/channel_order_list_acceptance_batch171_test.dart',
                    'integration_test/channel/paid_channel_acceptance_test.dart'],
         backend_globs=['test/logic/channel_logic_order_tests.erl',
                        'test/logic/channel_logic_order_pay_tests.erl',
                        'test/logic/channel_logic_order_refund_tests.erl',
                        'test/logic/channel_logic_order_admin_refund_tests.erl',
                        'test/logic/channel_logic_order_guard_tests.erl',
                        'test/repo/channel_order_repo_tests.erl'],
         fixture='iso:orgA_member', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account']),
    # ---- Moment（6）----
    dict(capability_id='moment.create_feed_detail_delete', feature_key='moment', domain='moment', min_level='A',
         positive='发布->feed->详情->删除真机闭环', negative='删除后 feed 立即不可见；草稿不误发',
         recovery='删除失败重试幂等',
         app_globs=['test/unit_test/integration/moment/moment_publish_ui_flow_test.dart',
                    'test/unit_test/integration/moment/moment_feed_ui_flow_test.dart',
                    'test/unit_test/integration/moment/moment_e2e_flow_test.dart',
                    'test/unit_test/page/moment/moment_confirm_dialog_test.dart',
                    'test/unit_test/page/moment/moment_remove_by_id_test.dart'],
         backend_globs=['test/logic/moment_logic_tests.erl', 'test/repo/moment_repo_tests.erl',
                        'test/api/moment_handler_tests.erl'],
         fixture='iso:orgA_member', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account', 'authorization.business_write']),
    dict(capability_id='moment.visibility', feature_key='moment', domain='moment', min_level='A',
         positive='公开/私密可见性设置生效', negative='私密/非朋友内容对非授权者不可见',
         recovery='可见性切换后双方视图一致',
         app_globs=['test/unit_test/page/moment/moment_visibility_test.dart',
                    'test/unit_test/page/moment/moment_visibility_check_test.dart',
                    'test/unit_test/page/moment/moment_visibility_display_test.dart'],
         backend_globs=['test/logic/moment_logic_tests.erl', 'test/api/moment_handler_tests.erl'],
         fixture='iso:orgA_member+orgA_nonmember', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account', 'authorization.business_write']),
    dict(capability_id='moment.like_comment_reply_mention', feature_key='moment', domain='moment', min_level='A',
         positive='点赞/评论/回复/@ 互动真机闭环', negative='对不可见 moment 的互动被拒',
         recovery='评论删除后计数一致回退',
         app_globs=['test/unit_test/page/moment/moment_like_toggle_test.dart',
                    'test/unit_test/page/moment/moment_comment_count_delta_test.dart',
                    'test/unit_test/page/moment/moment_comments_merge_test.dart',
                    'test/unit_test/page/moment/moment_reply_format_test.dart',
                    'test/unit_test/page/moment/moment_comment_mentions_payload_test.dart'],
         backend_globs=['test/logic/moment_logic_tests.erl', 'test/api/moment_handler_tests.erl'],
         fixture='iso:orgA_member+orgA_nonmember', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account', 'authorization.business_write']),
    dict(capability_id='moment.media_draft_retry', feature_key='moment', domain='moment', min_level='A',
         positive='媒体发布/草稿保存/失败重试闭环', negative='超限媒体被拒且草稿不丢',
         recovery='失败草稿重新编辑后可发布',
         app_globs=['test/unit_test/page/moment/moment_draft_test.dart',
                    'test/unit_test/page/moment/moment_failed_draft_key_test.dart',
                    'test/unit_test/page/moment/moment_validate_media_selection_test.dart',
                    'test/unit_test/page/moment/moment_media_preview_test.dart',
                    'test/unit_test/page/moment/moment_normalize_media_test.dart'],
         backend_globs=['test/logic/moment_logic_tests.erl', 'test/repo/moment_repo_tests.erl'],
         fixture='iso:orgA_member', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account']),
    dict(capability_id='moment.notify_report', feature_key='moment', domain='moment', min_level='A',
         positive='互动通知去重触达与举报入口', negative='重复互动不重复通知；被举报内容按策略隐藏',
         recovery='通知重拉后不重复',
         app_globs=['test/unit_test/page/moment/moment_notify_state_test.dart',
                    'test/unit_test/store/repository/moment_notify_dedup_index_test.dart',
                    'test/unit_test/store/model/moment_notify_model_test.dart'],
         backend_globs=['test/logic/moment_logic_tests.erl', 'test/api/moment_handler_tests.erl'],
         fixture='iso:orgA_member', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account']),
    dict(capability_id='moment.friend_boundary', feature_key='moment', domain='moment', min_level='A',
         positive='朋友关系内 moment 正常可见', negative='非朋友/拉黑后不可见（边界 fail-closed）',
         recovery='好友关系恢复后可见性恢复',
         app_globs=['test/unit_test/page/moment/moment_permissions_test.dart',
                    'test/unit_test/page/moment/friend_picker_rules_test.dart',
                    'integration_test/contact/friend_management_test.dart'],
         backend_globs=['test/logic/moment_logic_tests.erl', 'test/api/moment_handler_tests.erl'],
         fixture='iso:orgA_member+orgA_nonmember', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account']),
    # ---- Project（6）----
    dict(capability_id='project.create_update_status', feature_key='core', domain='project', min_level='A',
         positive='项目创建/更新/状态流转真机闭环', negative='非成员创建到他人 workspace 被拒',
         recovery='状态回退后聚合一致',
         app_globs=['test/unit_test/page/workspace/project/project_page_test.dart',
                    'test/unit_test/store/model/project_w2_model_test.dart'],
         backend_globs=['test/logic/project_logic_tests.erl', 'test/logic/project_admin_tests.erl',
                        'test/repo/project_repo_page_tests.erl'],
         fixture='iso:orgA_owner', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account', 'authorization.business_write']),
    dict(capability_id='project.member_invite_remove_owner_transfer', feature_key='core', domain='project', min_level='A',
         positive='成员邀请/移除/owner 转让闭环', negative='非 owner 管理 member 被拒；并发转让保持 owner 不变量',
         recovery='转让中断后 owner 不变量保持',
         app_globs=['test/unit_test/page/workspace/project/project_w2_members_page_test.dart',
                    'test/unit_test/page/workspace/project/project_w2_entry_section_test.dart'],
         backend_globs=['test/logic/project_member_logic_tests.erl',
                        'test/api/project_member_handler_tests.erl',
                        'test/repo/project_member_repo_tests.erl',
                        'test/integration/project_member_concurrency_tests.erl'],
         fixture='iso:orgA_owner+orgA_member', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account', 'authorization.business_write']),
    dict(capability_id='project.task_assign_status', feature_key='core', domain='project', min_level='A',
         positive='任务创建/指派/状态流转闭环', negative='指派给非项目成员被拒',
         recovery='指派失败后任务保持可重派',
         app_globs=['test/unit_test/page/workspace/project/project_task_flow_test.dart'],
         backend_globs=['test/logic/project_task_logic_tests.erl',
                        'test/repo/group_task_assignment_repo_tests.erl'],
         fixture='iso:orgA_owner+orgA_member', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account', 'authorization.business_write']),
    dict(capability_id='project.milestone', feature_key='core', domain='project', min_level='A',
         positive='里程碑创建/达成/并发更新闭环', negative='非法状态跃迁被拒',
         recovery='并发冲突后重试一致',
         app_globs=['test/unit_test/page/workspace/project/project_w2_milestones_page_test.dart'],
         backend_globs=['test/logic/project_milestone_logic_tests.erl',
                        'test/api/project_milestone_handler_tests.erl',
                        'test/repo/project_milestone_repo_tests.erl',
                        'test/integration/project_milestone_integration_tests.erl',
                        'test/integration/project_milestone_concurrency_tests.erl'],
         fixture='iso:orgA_owner', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account', 'authorization.business_write']),
    dict(capability_id='project.channel_link', feature_key='core', domain='project', min_level='A',
         positive='项目-频道关联/解绑闭环', negative='跨 workspace 频道不可被关联',
         recovery='解绑后两侧聚合回退',
         app_globs=['test/unit_test/page/workspace/project/project_w2_channels_page_test.dart'],
         backend_globs=['test/logic/project_channel_logic_tests.erl',
                        'test/integration/project_channel_rel_integration_tests.erl'],
         fixture='iso:orgA_owner', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account', 'authorization.business_write']),
    dict(capability_id='project.aggregations_workspace_boundary', feature_key='core', domain='project', min_level='A',
         positive='pinned/resources/activity/related-posts 聚合正确呈现', negative='workspace 边界外数据不进聚合；count fail-closed',
         recovery='归档/scope 变更后聚合同步收敛',
         app_globs=['test/unit_test/page/workspace/project/project_w2_insights_page_test.dart'],
         backend_globs=['test/integration/project_channel_agg_integration_tests.erl',
                        'test/repo/project_count_failclosed_tests.erl'],
         fixture='iso:orgA_owner+orgB_owner', requirements=['device.android', 'device.macos', 'backend.local', 'fixture.disposable_account', 'authorization.business_write']),
    # ---- 补充：manifest 启用 feature 的 capability 映射 ----
    dict(capability_id='location.share', feature_key='location', domain='location', min_level='B',
         positive='位置分享 API/组件合同（消息位置构建）', negative='未授权定位请求被拒',
         recovery='定位失败降级不发半成品消息',
         app_globs=['test/unit_test/api/location_api_test.dart',
                    'test/unit_test/page/moment/moment_location_at_uids_test.dart'],
         backend_globs=['test/logic/location_logic_tests.erl', 'test/api/location_handler_tests.erl'],
         fixture='shared:readonly', requirements=['backend.local']),
    dict(capability_id='bot.webhook_delivery', feature_key='bot_webhook', domain='bot', min_level='B',
         positive='bot webhook 投递/群内 @ bot 回复合同', negative='非法签名/未注册 webhook 被拒',
         recovery='投递失败退避重试且幂等',
         app_globs=['test/unit_test/component/ui/bot_badge_test.dart'],
         backend_globs=['test/logic/bot_webhook_logic_tests.erl',
                        'test/logic/bot_webhook_delivery_logic_tests.erl',
                        'test/logic/bot_webhook_delivery_worker_tests.erl',
                        'test/logic/bot_group_mention_tests.erl',
                        'test/logic/ai_agent_group_reply_tests.erl',
                        'test/ds/channel_webhook_ds_tests.erl'],
         fixture='shared:readonly', requirements=['backend.local']),
]

# 每个 manifest 启用 feature -> capability_id 列表（DOM-002 双向追溯）
FEATURE_CAPABILITY_MAP: dict[str, list[str]] = {
    'e2ee': [c for c in (
        'e2ee.plaintext_rejection', 'e2ee.c2c_olm', 'e2ee.c2g_megolm_roomkey', 'e2ee.multi_device_fanout',
        'e2ee.otk_fallback_rotation', 'e2ee.identity_trust_change', 'e2ee.replay_tamper_order',
        'e2ee.attachment', 'e2ee.backup_recovery', 'e2ee.history_member_boundary',
        'e2ee.policy_gate', 'e2ee.log_metadata_privacy')],
    'channel': ['channel.create_edit_delete', 'channel.publish_edit_revoke_pin_reaction_comment',
                'channel.workspace_binding'],
    'channel_discover': ['channel.discover_search_sync_unread'],
    'channel_invitation': ['channel.admin_subscriber_invitation'],
    'channel_order': ['channel.paid_order_mock'],
    'location': ['location.share'],
    'moment': ['moment.create_feed_detail_delete', 'moment.visibility', 'moment.like_comment_reply_mention',
               'moment.media_draft_retry', 'moment.notify_report', 'moment.friend_boundary'],
    'group_vote': ['group.notice_task_vote_schedule_file_album_tag_category'],
    'group_schedule': ['group.notice_task_vote_schedule_file_album_tag_category'],
    'group_task': ['group.notice_task_vote_schedule_file_album_tag_category'],
    'bot_webhook': ['bot.webhook_delivery'],
    'enterprise_business': ['org.lifecycle', 'org.owner_member_department_invitation', 'org.default_workspace',
                            'ent.identity_contact_conversation_message_asset',
                            'ent.suspend_offboarding_retention_audit'],
    'customer_service': ['cs.queue_claim_transfer_close_rating'],
}

# A 级（真客户端 / 真机业务闭环）capability 前缀：preflight 影响映射用
A_LEVEL_PREFIXES = ('e2ee.c2c_olm', 'e2ee.c2g_megolm_roomkey', 'e2ee.multi_device_fanout',
                    'e2ee.attachment', 'e2ee.backup_recovery', 'e2ee.history_member_boundary',
                    'group.e2ee', 'ws.', 'channel.', 'moment.', 'project.')


def load_selected_features(root: Path) -> list[str]:
    manifest = json.loads((root / MANIFEST_REL).read_text(encoding='utf-8'))
    return list(manifest['selected_features'])


def _existing_files(root: Path, base: str) -> list[str]:
    """base 目录下全部 *_test.dart，返回仓相对路径（与 app_globs 前缀一致）。"""
    return sorted(p.relative_to(root).as_posix() for p in (root / base).rglob('*.dart')
                  if '_test.dart' in p.name)


def _match(existing: list[str], globs: list[str]) -> list[str]:
    out = []
    for glob in globs:
        for path in existing:
            if fnmatch.fnmatch(path, glob):
                out.append(path)
    return sorted(set(out))


def _backend_targets(root: Path, globs: list[str]) -> list[str]:
    backend_root = Path(root).resolve().parent / 'imboy'
    existing = sorted(p.relative_to(backend_root).as_posix() for p in (backend_root / 'test').rglob('*.erl'))
    matched = _match(existing, globs)
    for special in globs:
        if special.startswith('make:'):
            target = special.split(':', 1)[1]
            makefile = backend_root / 'Makefile'
            if makefile.is_file() and re.search(rf'^{re.escape(target)}:', makefile.read_text(encoding='utf-8'), re.M):
                matched.append(special)
    return sorted(set(matched))


def generate_domain_matrix(root: Path) -> dict:
    root = Path(root).resolve()
    app_files = sorted(_existing_files(root, 'test') + _existing_files(root, 'integration_test'))
    selected = load_selected_features(root)
    specs_by_id = {spec['capability_id']: spec for spec in CAPABILITY_SPECS}

    capabilities = []
    blocked_notes = []
    for spec in CAPABILITY_SPECS:
        app_targets = _match(app_files, spec['app_globs'])
        backend_targets = _backend_targets(root, spec['backend_globs'])
        entry = {
            'capability_id': spec['capability_id'],
            'feature_key': spec['feature_key'],
            'domain': spec['domain'],
            'positive': spec['positive'],
            'negative': spec['negative'],
            'recovery': spec['recovery'],
            'app_targets': app_targets,
            'backend_targets': backend_targets,
            'required_evidence_level': spec['min_level'],
            'level_basis': ('真客户端聊天/跨角色写/真机业务闭环' if spec['min_level'] == 'A'
                            else 'App/Backend 合同'),
            'requirements': spec['requirements'],
            'fixture': spec['fixture'],
            'disposition': 'required',
            'exclusion_code': None,
            'blocked_code': None,
            'details': '',
        }
        if not app_targets:
            entry['blocked_code'] = 'BLOCKED_NO_APP_TARGET'
            entry['details'] = '静态模式未匹配到存在的 App target：' + ';'.join(spec['app_globs'])
            blocked_notes.append(spec['capability_id'])
        if not backend_targets:
            entry['blocked_code'] = entry['blocked_code'] or 'BLOCKED_NO_BACKEND_TARGET'
            entry['details'] += ' 静态模式未匹配到存在的 Backend target：' + ';'.join(spec['backend_globs'])
            blocked_notes.append(spec['capability_id'])
        capabilities.append(entry)

    feature_mapping = {}
    for feature in selected:
        caps = FEATURE_CAPABILITY_MAP.get(feature, [])
        feature_mapping[feature] = {
            'capabilities': caps,
            'disposition': 'mapped' if caps else 'unmapped',
            'exclusion_code': None,
            'details': '' if caps else '启用 feature 无 capability 映射',
        }

    matrix = {
        'schema_version': DOMAIN_SCHEMA_VERSION,
        'generated_from': {
            'app_head': discovery.git_head(root),
            'backend_head': discovery.git_head(root.parent / 'imboy'),
            'manifest_profile': 'full-selected',
            'selected_features': selected,
            'capability_count': len(capabilities),
            'backend_target_base': '../imboy（路径相对 imboy 仓；make:* 指 Makefile target）',
            'note': 'matrix 只保存声明性要求；运行 verdict 只写 ignored RUN_ROOT/results/**',
        },
        'capabilities': capabilities,
        'feature_mapping': feature_mapping,
    }
    return matrix


# ----------------------------------------------------------------- 校验

_SPEC_MIN = {spec['capability_id']: spec['min_level'] for spec in CAPABILITY_SPECS}


def validate_domain(root: Path, matrix: dict) -> list[str]:
    """DOM-002 面：feature 无映射 / 缺 target / 等级不足或 D 级。"""
    root = Path(root)
    errors: list[str] = []
    selected = load_selected_features(root)

    mapping = matrix.get('feature_mapping', {})
    for feature in selected:
        item = mapping.get(feature)
        if not item:
            errors.append(f'启用 feature 无 capability 映射: {feature}')
            continue
        if not item.get('capabilities') and item.get('disposition') != 'excluded':
            errors.append(f'启用 feature 既无映射也无排除: {feature}')
        for cap in item.get('capabilities', []):
            if cap not in {c['capability_id'] for c in matrix.get('capabilities', [])}:
                errors.append(f'feature_mapping 指向不存在 capability: {feature} -> {cap}')

    backend_root = root.parent / 'imboy'
    ids = set()
    for cap in matrix.get('capabilities', []):
        cid = cap.get('capability_id', '?')
        ids.add(cid)
        if not cap.get('app_targets') and not cap.get('blocked_code'):
            errors.append(f'capability 缺 app target 且未 BLOCKED 标注: {cid}')
        if not cap.get('backend_targets') and not cap.get('blocked_code'):
            errors.append(f'capability 缺 backend target 且未 BLOCKED 标注: {cid}')
        for target in cap.get('app_targets', []):
            if not (root / target).is_file():
                errors.append(f'capability app target 不存在: {cid} -> {target}')
        for target in cap.get('backend_targets', []):
            if target.startswith('make:'):
                continue  # make target 在生成期对 Makefile 校验
            if not (backend_root / target).is_file():
                errors.append(f'capability backend target 不存在: {cid} -> {target}')
        level = cap.get('required_evidence_level')
        if level not in LEVEL_RANK:
            errors.append(f'非法证据等级: {cid}: {level}')
            continue
        if level == 'D':
            errors.append(f'D 级不得作为要求等级: {cid}')
        min_level = _SPEC_MIN.get(cid)
        if min_level and LEVEL_RANK[level] < LEVEL_RANK[min_level]:
            errors.append(f'证据等级低于类型最低值: {cid}: {level} < {min_level}')
        if cap.get('disposition') not in ('required', 'excluded'):
            errors.append(f'非法 disposition: {cid}: {cap.get("disposition")}')
    for cid in sorted(_SPEC_MIN.keys() - ids):
        errors.append(f'matrix 缺少必须覆盖 capability: {cid}')
    return errors


# ------------------------------------------------------ 隔离 fixture 合同

_ACCOUNT_ALIASES = ('orgA_owner', 'orgA_admin', 'orgA_member', 'orgA_nonmember', 'orgB_owner', 'orgB_member')
_CREDENTIAL_KEY_RE = re.compile(r'(password|passwd|secret|token|api[_-]?key|private[_-]?key|credential|phone)', re.I)


def validate_fixtures_contract(doc: dict) -> list[str]:
    """DOM-003 面：六账号、互异设备身份、namespace/marker 规则、无凭证字段。"""
    errors: list[str] = []
    accounts = doc.get('accounts') or []
    aliases = [a.get('alias') for a in accounts]
    if sorted(a or '' for a in aliases) != sorted(_ACCOUNT_ALIASES):
        errors.append(f'账号别名集合不等于六匿名账号: {sorted(a or "" for a in aliases)}')
    for account in accounts:
        for field in ('alias', 'role', 'org', 'scope'):
            value = account.get(field)
            if field == 'scope':
                if not isinstance(value, list):
                    errors.append(f"账号 scope 必须为数组: {account.get('alias')}")
            elif not value:
                errors.append(f"账号缺 {field}: {account.get('alias')}")

    devices = doc.get('device_identities') or []
    device_accounts = [d.get('account_alias') for d in devices]
    if sorted(d or '' for d in device_accounts) != ['orgA_member', 'orgA_owner']:
        errors.append(f'device_identities 必须是互异的 orgA_owner/orgA_member: {device_accounts}')
    if len({d.get('device_alias') for d in devices}) != len(devices):
        errors.append('device_identities 设备别名必须互异')
    for device in devices:
        if not device.get('device_alias') or not device.get('platform'):
            errors.append(f"设备身份缺 device_alias/platform: {device}")

    for field in ('shard_namespace_rule', 'run_marker_rule', 'account_shortfall_policy'):
        if not doc.get(field):
            errors.append(f'fixture 合同缺 {field}')
    if doc.get('run_marker_rule') != f'at_{RUN_ID}':
        errors.append(f"run_marker_rule 必须为 at_{RUN_ID}")

    def _walk(node, path=''):
        if isinstance(node, dict):
            for key, value in node.items():
                # *_policy 是策略声明字段名，不是凭证载体
                if _CREDENTIAL_KEY_RE.search(str(key)) and not str(key).endswith('_policy'):
                    errors.append(f'fixture 合同含凭证字段: {path}/{key}')
                _walk(value, f'{path}/{key}')
        elif isinstance(node, list):
            for i, item in enumerate(node):
                _walk(item, f'{path}[{i}]')

    _walk(doc)
    return errors


# ------------------------------------------------- preflight 决策快照

def _run(cmd: list[str], cwd: Path | None = None, timeout: int = 120) -> dict:
    try:
        proc = subprocess.run(cmd, cwd=str(cwd) if cwd else None, capture_output=True, text=True, timeout=timeout)
        return {'command': ' '.join(cmd), 'exit_code': proc.returncode,
                'stdout_tail': proc.stdout.strip().splitlines()[-12:],
                'stderr_tail': proc.stderr.strip().splitlines()[-12:]}
    except (subprocess.TimeoutExpired, OSError) as exc:
        return {'command': ' '.join(cmd), 'exit_code': None, 'error': repr(exc)}


def _probe_http(url: str, timeout: float = 2.0) -> dict:
    try:
        with urlopen(url, timeout=timeout) as resp:
            body = resp.read(512).decode('utf-8', errors='replace')
            return {'url': url, 'reachable': True, 'status': resp.status, 'body_head': body[:200]}
    except URLError as exc:
        return {'url': url, 'reachable': False, 'error': str(exc)}
    except Exception as exc:  # noqa: BLE001 只读探活，任何失败都记录
        return {'url': url, 'reachable': False, 'error': repr(exc)}


def collect_preflight_snapshot(root: Path, run_root: Path) -> dict:
    """零交互只读探测：route drift / 后端 / D2 / 设备 -> capability/shard 影响映射。"""
    root = Path(root)
    imboy = root.parent / 'imboy'

    drift = _run(['python3', 'scripts/generate_product_features.py',
                  '--check', '--require-profile', 'full-selected'], cwd=imboy)
    drift_stale = drift['exit_code'] != 0

    probes = [_probe_http('http://127.0.0.1:9800/api/v1/health'),
              _probe_http('http://127.0.0.1:9700/api/v1/health')]
    lsof = _run(['lsof', '-i', ':9700', '-sTCP:LISTEN'], timeout=10)
    backend_reachable = any(p['reachable'] for p in probes)
    # 只读探活无法验证 Backend HEAD/profile/账号归属 => 身份不可验证 => D2=false
    identity_verified = False
    d2 = bool(backend_reachable and identity_verified)

    devices = _run(['flutter', 'devices'], timeout=90)
    device_lines = devices.get('stdout_tail') or []
    android_visible = any(('android' in ln.lower() and 'emulator' not in ln.lower()) for ln in device_lines)
    macos_visible = any('macos' in ln.lower() for ln in device_lines)

    matrix = generate_domain_matrix(root)
    a_caps = [c['capability_id'] for c in matrix['capabilities']
              if c['required_evidence_level'] == 'A']
    fixture_write_caps = [c['capability_id'] for c in matrix['capabilities']
                          if c.get('fixture', '').startswith('iso:')]

    capability_blocks: dict[str, list[str]] = {}
    for cap in fixture_write_caps:
        capability_blocks[cap] = ['BLOCKED_BACKEND_IDENTITY'] if not d2 else []
    if not android_visible or not macos_visible:
        missing = []
        if not android_visible:
            missing.append('device.android')
        if not macos_visible:
            missing.append('device.macos')
        for cap in a_caps:
            capability_blocks.setdefault(cap, [])
            capability_blocks[cap].append('BLOCKED_DEVICE_UNAVAILABLE:' + '+'.join(missing))

    snapshot = {
        'schema_version': 1,
        'run_id': RUN_ID,
        'captured_at_utc': _dt.datetime.now(tz=_dt.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'route_drift': {
            'command': drift['command'], 'exit_code': drift['exit_code'],
            'stale': drift_stale,
            'output_tail': (drift.get('stdout_tail') or []) + (drift.get('stderr_tail') or []),
            'impact': 'BLOCKED_PRODUCT_DRIFT: profile-dependent targets（generated_product_feature_routes 相关）',
        },
        'backend': {
            'probes': probes, 'lsof_9700': lsof,
            'backend_reachable': backend_reachable,
            'identity_verified': identity_verified,
            'note': '只读 GET 探活；无法验证身份时不自行启动/迁移后端',
        },
        'd2': {
            'value': d2,
            'reason': '后端身份（HEAD/profile/专用账号归属/可销毁 fixture）未验证 => D2=false'
                      if not d2 else '全部前置已验证',
            'blocked_capabilities': sorted(
                cap for cap, codes in capability_blocks.items() if 'BLOCKED_BACKEND_IDENTITY' in codes
            ) if not d2 else [],
            'safe_alternative': 'B/C 级合同与纯函数测试不依赖 D2，继续执行；A 级真客户端路径留 BLOCKED',
        },
        'devices': {
            'flutter_devices_exit': devices['exit_code'],
            'android_physical_visible': android_visible,
            'macos_visible': macos_visible,
            'output_tail': device_lines,
        },
        'impact': {
            'capability_blocks': {cap: codes for cap, codes in sorted(capability_blocks.items()) if codes},
            'shard_blocks': {
                'e2ee_device': (['BLOCKED_BACKEND_IDENTITY'] if not d2 else [])
                + ([] if android_visible and macos_visible else ['BLOCKED_DEVICE_UNAVAILABLE']),
                'workspace_group': (['BLOCKED_BACKEND_IDENTITY'] if not d2 else [])
                + ([] if android_visible and macos_visible else ['BLOCKED_DEVICE_UNAVAILABLE']),
                'channel_moment_project': (['BLOCKED_BACKEND_IDENTITY'] if not d2 else [])
                + ([] if android_visible and macos_visible else ['BLOCKED_DEVICE_UNAVAILABLE']),
                'pages_device': ([] if android_visible and macos_visible else ['BLOCKED_DEVICE_UNAVAILABLE']),
                'profile_dependent_targets': ['BLOCKED_PRODUCT_DRIFT'] if drift_stale else [],
            },
            'a_level_capability_ids': a_caps,
        },
        'decisions': [
            '零交互：以上全部为只读探测，不向用户提问，不暂停会话',
            'D2=false 期间所有 iso:* fixture 写 capability 保持 BLOCKED，合同测试继续',
            'route drift 不阻断静态 inventory/框架实现与不依赖 profile 的测试',
        ],
    }
    path = Path(run_root) / 'steps' / 'step9_preflight_snapshot.json'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(snapshot, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    return snapshot


# ----------------------------------------------------------------- IO

def render_json(payload: dict) -> str:
    return json.dumps(payload, ensure_ascii=False, indent=2) + '\n'


def write_matrix(root: Path, matrix: dict) -> Path:
    path = root.joinpath(*DOMAIN_PATH)
    path.write_text(render_json(matrix), encoding='utf-8')
    return path


def check_domain(root: Path) -> list[str]:
    root = Path(root)
    matrix = generate_domain_matrix(root)
    errors = validate_domain(root, matrix)
    if errors:
        return errors
    path = root.joinpath(*DOMAIN_PATH)
    if not path.is_file():
        return ['domain_coverage.json 缺失']
    if path.read_text(encoding='utf-8') != render_json(matrix):
        return ['domain_coverage.json 与再生结果不一致（stale）']
    return []


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    root = Path(__file__).resolve().parents[2]
    if '--preflight-snapshot' in argv:
        run_root = root / 'test' / 'auto_test' / 'reports' / RUN_ID
        snapshot = collect_preflight_snapshot(root, run_root)
        path = run_root / 'steps' / 'step9_preflight_snapshot.json'
        print(f"wrote {path.relative_to(root)}: d2={snapshot['d2']['value']} "
              f"drift_stale={snapshot['route_drift']['stale']} "
              f"android={snapshot['devices']['android_physical_visible']} "
              f"macos={snapshot['devices']['macos_visible']}")
        return 0
    if '--check' in argv:
        errors = check_domain(root)
        for err in errors:
            print(f'ERROR: {err}', file=sys.stderr)
        if errors:
            return 2
        matrix = json.loads(root.joinpath(*DOMAIN_PATH).read_text(encoding='utf-8'))
        print(f"domain --check OK: capabilities={len(matrix['capabilities'])} "
              f"features_mapped={len(matrix['feature_mapping'])}")
        return 0
    matrix = generate_domain_matrix(root)
    errors = validate_domain(root, matrix)
    if errors:
        for err in errors:
            print(f'ERROR: {err}', file=sys.stderr)
        return 64
    path = write_matrix(root, matrix)
    blocked = [c['capability_id'] for c in matrix['capabilities'] if c['blocked_code']]
    print(f'wrote {path.relative_to(root)}: capabilities={len(matrix["capabilities"])} blocked={len(blocked)}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
