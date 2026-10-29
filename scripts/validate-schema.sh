#!/usr/bin/env bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

load_local_env
require_command psql

URL="$(database_url)"

schema_migrations_exists="$(psql_command "${URL}" -tA -c "SELECT to_regclass('public.schema_migrations') IS NOT NULL;")"

if [[ "${schema_migrations_exists}" != "t" ]]; then
  echo "Schema validation failed: public.schema_migrations does not exist. Run scripts/migrate.sh first." >&2
  exit 1
fi

duplicate_migrations="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (SELECT version FROM public.schema_migrations GROUP BY version HAVING COUNT(*) > 1) duplicates;")"

if [[ "${duplicate_migrations}" != "0" ]]; then
  echo "Schema validation failed: duplicate migration versions were found." >&2
  exit 1
fi

applied_count="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM public.schema_migrations;")"

core_tenant_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '001_create_core_tenant_schema.sql');")"

if [[ "${core_tenant_applied}" == "t" ]]; then
  missing_core_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.tenants'), ('public.company_profiles'), ('public.billing_info'), ('public.payment_info')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_core_tables}" != "0" ]]; then
    echo "Schema validation failed: core tenant tables are missing." >&2
    exit 1
  fi

  missing_core_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('tenants_public_id_unique'), ('tenants_slug_unique'), ('tenants_status_check'), ('tenants_active_requires_activation_check'), ('company_profiles_tenant_id_unique'), ('billing_info_tenant_id_unique'), ('payment_info_tenant_id_unique'), ('payment_info_status_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_core_constraints}" != "0" ]]; then
    echo "Schema validation failed: core tenant constraints are missing." >&2
    exit 1
  fi
fi

identity_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '002_create_identity_schema.sql');")"

if [[ "${identity_applied}" == "t" ]]; then
  missing_identity_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.users'), ('public.tenant_memberships'), ('public.user_invitations'), ('public.user_settings'), ('public.user_verified_contacts'), ('public.user_credentials')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_identity_tables}" != "0" ]]; then
    echo "Schema validation failed: identity tables are missing." >&2
    exit 1
  fi

  missing_identity_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('users_primary_email_normalized_unique'), ('users_active_requires_verified_email_check'), ('tenant_memberships_public_id_unique'), ('tenant_memberships_user_tenant_unique'), ('tenant_memberships_status_check'), ('tenant_memberships_joined_timestamp_check'), ('user_invitations_token_hash_unique'), ('user_settings_user_id_unique'), ('user_verified_contacts_user_contact_unique'), ('user_credentials_type_identifier_unique'), ('user_credentials_secret_hash_length_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_identity_constraints}" != "0" ]]; then
    echo "Schema validation failed: identity constraints are missing." >&2
    exit 1
  fi

  missing_identity_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('user_invitations_tenant_pending_email_unique_idx'), ('tenant_memberships_tenant_status_created_at_idx'), ('tenant_memberships_user_status_idx'), ('users_tenant_status_created_at_idx'), ('user_verified_contacts_user_verified_at_idx'), ('user_credentials_user_id_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_identity_indexes}" != "0" ]]; then
    echo "Schema validation failed: identity indexes are missing." >&2
    exit 1
  fi
fi

auth_lifecycle_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '003_create_auth_lifecycle_schema.sql');")"

if [[ "${auth_lifecycle_applied}" == "t" ]]; then
  missing_auth_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.sessions'), ('public.refresh_tokens'), ('public.password_resets'), ('public.otp_challenges'), ('public.mfa_factors'), ('public.mfa_recovery_requests')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_auth_tables}" != "0" ]]; then
    echo "Schema validation failed: auth lifecycle tables are missing." >&2
    exit 1
  fi

  missing_auth_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('sessions_access_token_jti_unique'), ('sessions_expiry_check'), ('refresh_tokens_token_hash_unique'), ('refresh_tokens_token_hash_length_check'), ('password_resets_reset_token_hash_unique'), ('password_resets_token_hash_length_check'), ('otp_challenges_code_hash_unique'), ('otp_challenges_code_hash_length_check'), ('mfa_factors_secret_ref_not_blank_check'), ('mfa_recovery_requests_reason_not_blank_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_auth_constraints}" != "0" ]]; then
    echo "Schema validation failed: auth lifecycle constraints are missing." >&2
    exit 1
  fi

  plaintext_like_columns="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = 'public' AND table_name IN ('refresh_tokens', 'password_resets', 'otp_challenges', 'mfa_factors') AND column_name IN ('token', 'refresh_token', 'reset_token', 'otp_code', 'code', 'secret', 'service_key');")"

  if [[ "${plaintext_like_columns}" != "0" ]]; then
    echo "Schema validation failed: plaintext-like secret columns found in auth lifecycle tables." >&2
    exit 1
  fi
fi

rbac_audit_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '004_create_rbac_audit_schema.sql');")"

if [[ "${rbac_audit_applied}" == "t" ]]; then
  missing_rbac_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.roles'), ('public.permissions'), ('public.role_permissions'), ('public.user_roles'), ('public.audit_logs')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_rbac_tables}" != "0" ]]; then
    echo "Schema validation failed: RBAC/audit tables are missing." >&2
    exit 1
  fi

  missing_rbac_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('roles_tenant_code_unique'), ('permissions_code_unique'), ('role_permissions_role_permission_unique'), ('user_roles_user_role_unique'), ('audit_logs_scope_tenant_check'), ('audit_logs_metadata_object_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_rbac_constraints}" != "0" ]]; then
    echo "Schema validation failed: RBAC/audit constraints are missing." >&2
    exit 1
  fi

  audit_mutation_trigger_exists="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'audit_logs_prevent_mutation' AND NOT tgisinternal);")"

  if [[ "${audit_mutation_trigger_exists}" != "t" ]]; then
    echo "Schema validation failed: audit append-only trigger is missing." >&2
    exit 1
  fi
fi

billing_usage_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '005_create_billing_usage_schema.sql');")"

if [[ "${billing_usage_applied}" == "t" ]]; then
  missing_billing_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.pricing_plans'), ('public.usage_events'), ('public.invoices'), ('public.invoice_items'), ('public.payment_transactions')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_billing_tables}" != "0" ]]; then
    echo "Schema validation failed: billing/usage tables are missing." >&2
    exit 1
  fi

  missing_billing_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('pricing_plans_code_unique'), ('usage_events_public_id_unique'), ('invoices_tenant_invoice_no_unique'), ('invoices_tenant_period_unique'), ('invoice_items_invoice_line_unique'), ('payment_transactions_invoice_attempt_unique'), ('invoices_total_consistency_check'), ('invoice_items_line_total_consistency_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_billing_constraints}" != "0" ]]; then
    echo "Schema validation failed: billing/usage constraints are missing." >&2
    exit 1
  fi

  missing_billing_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('usage_events_tenant_period_occurred_at_idx'), ('invoices_tenant_period_idx'), ('payment_transactions_invoice_attempt_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_billing_indexes}" != "0" ]]; then
    echo "Schema validation failed: billing/usage indexes are missing." >&2
    exit 1
  fi

  invoice_item_mutation_trigger_exists="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'invoice_items_prevent_when_finalized' AND NOT tgisinternal);")"

  if [[ "${invoice_item_mutation_trigger_exists}" != "t" ]]; then
    echo "Schema validation failed: finalized invoice item protection trigger is missing." >&2
    exit 1
  fi
fi

voice_setup_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '006_create_voice_setup_schema.sql');")"

if [[ "${voice_setup_applied}" == "t" ]]; then
  missing_voice_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.ai_agents'), ('public.phone_numbers'), ('public.routing_rules')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_voice_tables}" != "0" ]]; then
    echo "Schema validation failed: voice setup tables are missing." >&2
    exit 1
  fi

  missing_voice_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('ai_agents_status_check'), ('phone_numbers_tenant_phone_unique'), ('phone_numbers_phone_number_e164_check'), ('routing_rules_fallback_action_check'), ('routing_rules_phone_tenant_fk'), ('routing_rules_agent_tenant_fk')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_voice_constraints}" != "0" ]]; then
    echo "Schema validation failed: voice setup constraints are missing." >&2
    exit 1
  fi

  missing_voice_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('phone_numbers_tenant_status_idx'), ('routing_rules_tenant_phone_status_priority_idx'), ('routing_rules_tenant_agent_status_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_voice_indexes}" != "0" ]]; then
    echo "Schema validation failed: voice setup indexes are missing." >&2
    exit 1
  fi
fi

call_read_model_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '007_create_call_read_model_schema.sql');")"

if [[ "${call_read_model_applied}" == "t" ]]; then
  missing_call_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.calls'), ('public.call_events'), ('public.call_transcripts'), ('public.call_recordings')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_call_tables}" != "0" ]]; then
    echo "Schema validation failed: call read model tables are missing." >&2
    exit 1
  fi

  missing_call_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('calls_tenant_provider_call_unique'), ('calls_ended_after_started_check'), ('call_events_call_tenant_fk'), ('call_transcripts_call_segment_unique'), ('call_transcripts_segment_positive_check'), ('call_recordings_call_tenant_fk')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_call_constraints}" != "0" ]]; then
    echo "Schema validation failed: call read model constraints are missing." >&2
    exit 1
  fi

  missing_call_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('calls_tenant_status_started_at_idx'), ('call_events_call_occurred_at_idx'), ('call_events_tenant_event_type_occurred_at_idx'), ('call_transcripts_call_segment_idx'), ('call_recordings_call_status_created_at_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_call_indexes}" != "0" ]]; then
    echo "Schema validation failed: call read model indexes are missing." >&2
    exit 1
  fi
fi

customer_case_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '008_create_customer_case_schema.sql');")"

if [[ "${customer_case_applied}" == "t" ]]; then
  missing_customer_case_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.customers'), ('public.customer_contacts'), ('public.customer_interactions'), ('public.cases'), ('public.case_events')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_customer_case_tables}" != "0" ]]; then
    echo "Schema validation failed: customer/case tables are missing." >&2
    exit 1
  fi

  missing_customer_case_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('users_id_tenant_id_unique'), ('customers_tenant_customer_no_unique'), ('cases_tenant_case_no_unique'), ('customer_contacts_customer_contact_unique'), ('customer_interactions_case_tenant_fk'), ('case_events_case_tenant_fk')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_customer_case_constraints}" != "0" ]]; then
    echo "Schema validation failed: customer/case constraints are missing." >&2
    exit 1
  fi

  missing_customer_case_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('customers_tenant_status_created_at_idx'), ('cases_tenant_status_priority_opened_at_idx'), ('customer_interactions_customer_occurred_at_idx'), ('case_events_case_occurred_at_idx'), ('case_events_tenant_event_type_occurred_at_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_customer_case_indexes}" != "0" ]]; then
    echo "Schema validation failed: customer/case indexes are missing." >&2
    exit 1
  fi
fi

lead_follow_up_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '009_create_lead_follow_up_schema.sql');")"

if [[ "${lead_follow_up_applied}" == "t" ]]; then
  missing_lead_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.leads'), ('public.lead_events'), ('public.follow_up_tasks')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_lead_tables}" != "0" ]]; then
    echo "Schema validation failed: lead/follow-up tables are missing." >&2
    exit 1
  fi

  missing_lead_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('leads_tenant_lead_no_unique'), ('leads_source_case_tenant_fk'), ('lead_events_lead_tenant_fk'), ('follow_up_tasks_lead_tenant_fk'), ('follow_up_tasks_link_required_check'), ('follow_up_tasks_status_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_lead_constraints}" != "0" ]]; then
    echo "Schema validation failed: lead/follow-up constraints are missing." >&2
    exit 1
  fi

  missing_lead_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('leads_tenant_status_owner_created_at_idx'), ('lead_events_lead_occurred_at_idx'), ('lead_events_tenant_event_type_occurred_at_idx'), ('follow_up_tasks_tenant_status_due_at_idx'), ('follow_up_tasks_tenant_assigned_status_due_at_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_lead_indexes}" != "0" ]]; then
    echo "Schema validation failed: lead/follow-up indexes are missing." >&2
    exit 1
  fi
fi

integration_automation_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '010_create_integration_automation_schema.sql');")"

if [[ "${integration_automation_applied}" == "t" ]]; then
  missing_integration_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.integrations'), ('public.integration_mappings'), ('public.automation_rules')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_integration_tables}" != "0" ]]; then
    echo "Schema validation failed: integration/automation tables are missing." >&2
    exit 1
  fi

  missing_integration_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('integrations_tenant_provider_name_unique'), ('integration_mappings_integration_entity_source_unique'), ('integration_mappings_integration_tenant_fk'), ('automation_rules_tenant_name_unique'), ('automation_rules_integration_tenant_fk'), ('automation_rules_status_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_integration_constraints}" != "0" ]]; then
    echo "Schema validation failed: integration/automation constraints are missing." >&2
    exit 1
  fi

  missing_integration_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('integrations_tenant_status_updated_at_idx'), ('integration_mappings_tenant_integration_status_idx'), ('integration_mappings_tenant_entity_status_idx'), ('automation_rules_tenant_status_trigger_idx'), ('automation_rules_tenant_integration_status_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_integration_indexes}" != "0" ]]; then
    echo "Schema validation failed: integration/automation indexes are missing." >&2
    exit 1
  fi

  plaintext_secret_columns="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = 'public' AND table_name IN ('integrations', 'integration_mappings', 'automation_rules') AND column_name ~* '(secret|password|token|key)';")"

  if [[ "${plaintext_secret_columns}" != "0" ]]; then
    echo "Schema validation failed: plaintext-like secret columns found in integration/automation tables." >&2
    exit 1
  fi
fi

artifact_metadata_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '011_create_artifact_metadata_schema.sql');")"

if [[ "${artifact_metadata_applied}" == "t" ]]; then
  missing_artifact_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.artifacts'), ('public.artifact_access_events'), ('public.artifact_redaction_jobs'), ('public.artifact_deletion_jobs')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_artifact_tables}" != "0" ]]; then
    echo "Schema validation failed: artifact metadata tables are missing." >&2
    exit 1
  fi

  missing_artifact_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('artifacts_storage_ref_not_blank_check'), ('artifacts_content_type_not_blank_check'), ('artifact_access_events_artifact_tenant_fk'), ('artifact_redaction_jobs_artifact_tenant_fk'), ('artifact_deletion_jobs_artifact_tenant_fk')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_artifact_constraints}" != "0" ]]; then
    echo "Schema validation failed: artifact metadata constraints are missing." >&2
    exit 1
  fi

  missing_artifact_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('artifacts_tenant_owner_entity_created_at_idx'), ('artifacts_tenant_status_created_at_idx'), ('artifact_access_events_artifact_occurred_at_idx'), ('artifact_access_events_tenant_action_occurred_at_idx'), ('artifact_redaction_jobs_tenant_status_requested_at_idx'), ('artifact_deletion_jobs_tenant_status_requested_at_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_artifact_indexes}" != "0" ]]; then
    echo "Schema validation failed: artifact metadata indexes are missing." >&2
    exit 1
  fi

  storage_ref_nullable="$(psql_command "${URL}" -tA -c "SELECT is_nullable FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'artifacts' AND column_name = 'storage_ref';")"

  if [[ "${storage_ref_nullable}" != "NO" ]]; then
    echo "Schema validation failed: artifacts.storage_ref must be NOT NULL." >&2
    exit 1
  fi

  artifact_binary_columns="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = 'public' AND table_name IN ('artifacts', 'artifact_access_events', 'artifact_redaction_jobs', 'artifact_deletion_jobs') AND udt_name = 'bytea';")"

  if [[ "${artifact_binary_columns}" != "0" ]]; then
    echo "Schema validation failed: artifact metadata tables must not store binary payload columns." >&2
    exit 1
  fi
fi

runtime_access_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '012_create_runtime_access_schema.sql');")"

if [[ "${runtime_access_applied}" == "t" ]]; then
  missing_runtime_access_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.tenant_environments'), ('public.service_accounts'), ('public.service_account_scopes'), ('public.service_account_keys'), ('public.idempotency_keys')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_runtime_access_tables}" != "0" ]]; then
    echo "Schema validation failed: runtime access tables are missing." >&2
    exit 1
  fi

  missing_runtime_access_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('tenant_environments_tenant_code_unique'), ('service_accounts_environment_tenant_fk'), ('service_account_scopes_service_scope_unique'), ('service_account_keys_key_hash_unique'), ('idempotency_keys_tenant_scope_key_unique')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_runtime_access_constraints}" != "0" ]]; then
    echo "Schema validation failed: runtime access constraints are missing." >&2
    exit 1
  fi

  missing_runtime_access_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('tenant_environments_single_default_idx'), ('service_accounts_tenant_environment_status_idx'), ('service_account_keys_service_status_created_at_idx'), ('idempotency_keys_tenant_scope_expires_at_idx'), ('idempotency_keys_tenant_state_created_at_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_runtime_access_indexes}" != "0" ]]; then
    echo "Schema validation failed: runtime access indexes are missing." >&2
    exit 1
  fi

  plaintext_runtime_key_columns="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = 'public' AND table_name IN ('service_account_keys', 'idempotency_keys') AND column_name IN ('secret', 'service_key', 'private_key', 'api_key', 'token');")"

  if [[ "${plaintext_runtime_key_columns}" != "0" ]]; then
    echo "Schema validation failed: plaintext-like key columns found in runtime access tables." >&2
    exit 1
  fi
fi

agent_config_versioning_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '013_create_agent_config_version_schema.sql');")"

if [[ "${agent_config_versioning_applied}" == "t" ]]; then
  missing_agent_config_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.agent_config_versions'), ('public.agent_config_publish_requests'), ('public.agent_config_bindings')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_agent_config_tables}" != "0" ]]; then
    echo "Schema validation failed: agent config versioning tables are missing." >&2
    exit 1
  fi

  missing_agent_config_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('agent_config_versions_env_agent_version_unique'), ('agent_config_versions_snapshot_object_check'), ('agent_config_publish_requests_version_tenant_fk'), ('agent_config_publish_requests_status_check'), ('agent_config_bindings_tenant_env_agent_unique')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_agent_config_constraints}" != "0" ]]; then
    echo "Schema validation failed: agent config versioning constraints are missing." >&2
    exit 1
  fi

  missing_agent_config_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('agent_config_versions_tenant_env_agent_status_updated_idx'), ('agent_config_publish_requests_tenant_status_requested_at_idx'), ('agent_config_publish_requests_pending_per_agent_idx'), ('agent_config_bindings_tenant_environment_updated_at_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_agent_config_indexes}" != "0" ]]; then
    echo "Schema validation failed: agent config versioning indexes are missing." >&2
    exit 1
  fi

  immutable_snapshot_trigger_exists="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'agent_config_versions_prevent_published_snapshot_mutation' AND NOT tgisinternal);")"

  if [[ "${immutable_snapshot_trigger_exists}" != "t" ]]; then
    echo "Schema validation failed: published snapshot immutability trigger is missing." >&2
    exit 1
  fi
fi

tool_execution_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '014_create_tool_execution_schema.sql');")"

if [[ "${tool_execution_applied}" == "t" ]]; then
  missing_tool_execution_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.tool_definitions'), ('public.tool_versions'), ('public.tenant_tool_bindings'), ('public.tool_execution_runs')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_tool_execution_tables}" != "0" ]]; then
    echo "Schema validation failed: tool execution tables are missing." >&2
    exit 1
  fi

  missing_tool_execution_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('tool_definitions_tenant_code_unique'), ('tool_versions_definition_version_unique'), ('tenant_tool_bindings_scope_agent_requires_agent_check'), ('tool_execution_runs_tenant_execution_key_unique'), ('tool_execution_runs_actor_required_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_tool_execution_constraints}" != "0" ]]; then
    echo "Schema validation failed: tool execution constraints are missing." >&2
    exit 1
  fi

  missing_tool_execution_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('tool_definitions_tenant_status_updated_at_idx'), ('tool_versions_tenant_status_updated_at_idx'), ('tenant_tool_bindings_tenant_env_status_priority_idx'), ('tool_execution_runs_tenant_status_created_at_idx'), ('tool_execution_runs_tenant_tool_version_status_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_tool_execution_indexes}" != "0" ]]; then
    echo "Schema validation failed: tool execution indexes are missing." >&2
    exit 1
  fi
fi

workflow_external_refs_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '015_create_workflow_external_reference_schema.sql');")"

if [[ "${workflow_external_refs_applied}" == "t" ]]; then
  missing_workflow_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.workflow_templates'), ('public.workflow_template_versions'), ('public.tenant_workflow_bindings'), ('public.workflow_runs'), ('public.workflow_step_runs'), ('public.external_object_references')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_workflow_tables}" != "0" ]]; then
    echo "Schema validation failed: workflow/external reference tables are missing." >&2
    exit 1
  fi

  missing_workflow_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('workflow_templates_tenant_code_unique'), ('workflow_template_versions_template_version_unique'), ('tenant_workflow_bindings_scope_agent_requires_agent_check'), ('workflow_step_runs_run_step_attempt_unique'), ('external_object_references_external_object_id_not_blank_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_workflow_constraints}" != "0" ]]; then
    echo "Schema validation failed: workflow/external reference constraints are missing." >&2
    exit 1
  fi

  missing_workflow_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('workflow_templates_tenant_status_updated_at_idx'), ('workflow_template_versions_tenant_status_updated_at_idx'), ('tenant_workflow_bindings_tenant_env_status_priority_idx'), ('workflow_runs_tenant_status_created_at_idx'), ('workflow_step_runs_run_status_step_idx'), ('external_object_references_tenant_source_entity_occurred_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_workflow_indexes}" != "0" ]]; then
    echo "Schema validation failed: workflow/external reference indexes are missing." >&2
    exit 1
  fi
fi

call_session_runtime_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '016_create_call_session_runtime_schema.sql');")"

if [[ "${call_session_runtime_applied}" == "t" ]]; then
  missing_call_session_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.call_sessions'), ('public.call_session_events'), ('public.call_tool_executions')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_call_session_tables}" != "0" ]]; then
    echo "Schema validation failed: call session runtime tables are missing." >&2
    exit 1
  fi

  missing_call_session_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('call_sessions_tenant_runtime_ref_unique'), ('call_session_events_session_tenant_fk'), ('call_tool_executions_tenant_session_request_unique'), ('call_tool_executions_execution_run_tenant_fk')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_call_session_constraints}" != "0" ]]; then
    echo "Schema validation failed: call session runtime constraints are missing." >&2
    exit 1
  fi

  missing_call_session_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('call_sessions_tenant_status_started_at_idx'), ('call_session_events_session_idempotency_unique_idx'), ('call_session_events_tenant_event_type_occurred_idx'), ('call_tool_executions_session_status_requested_at_idx'), ('call_tool_executions_tenant_status_requested_at_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_call_session_indexes}" != "0" ]]; then
    echo "Schema validation failed: call session runtime indexes are missing." >&2
    exit 1
  fi
fi

async_jobs_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '017_create_async_job_schema.sql');")"

if [[ "${async_jobs_applied}" == "t" ]]; then
  missing_async_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.outbox_events'), ('public.inbox_events'), ('public.background_jobs'), ('public.job_attempts')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_async_tables}" != "0" ]]; then
    echo "Schema validation failed: async job tables are missing." >&2
    exit 1
  fi

  missing_async_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('outbox_events_tenant_topic_key_unique'), ('inbox_events_tenant_source_event_unique'), ('background_jobs_status_check'), ('job_attempts_job_attempt_unique'), ('job_attempts_background_job_tenant_fk')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_async_constraints}" != "0" ]]; then
    echo "Schema validation failed: async job constraints are missing." >&2
    exit 1
  fi

  missing_async_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('outbox_events_tenant_status_available_at_idx'), ('inbox_events_tenant_status_received_at_idx'), ('background_jobs_tenant_status_available_at_idx'), ('background_jobs_tenant_queue_dedupe_unique_idx'), ('job_attempts_job_status_started_at_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_async_indexes}" != "0" ]]; then
    echo "Schema validation failed: async job indexes are missing." >&2
    exit 1
  fi
fi

webhook_delivery_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '018_create_webhook_delivery_schema.sql');")"

if [[ "${webhook_delivery_applied}" == "t" ]]; then
  missing_webhook_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.webhook_subscriptions'), ('public.webhook_deliveries')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_webhook_tables}" != "0" ]]; then
    echo "Schema validation failed: webhook delivery tables are missing." >&2
    exit 1
  fi

  missing_webhook_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('webhook_subscriptions_tenant_env_name_unique'), ('webhook_subscriptions_auth_config_pair_check'), ('webhook_deliveries_subscription_tenant_fk'), ('webhook_deliveries_tenant_subscription_event_attempt_unique'), ('webhook_deliveries_delivery_status_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_webhook_constraints}" != "0" ]]; then
    echo "Schema validation failed: webhook delivery constraints are missing." >&2
    exit 1
  fi

  missing_webhook_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('webhook_subscriptions_tenant_status_updated_at_idx'), ('webhook_subscriptions_tenant_env_status_idx'), ('webhook_deliveries_tenant_subscription_event_latest_unique_idx'), ('webhook_deliveries_tenant_status_next_attempt_idx'), ('webhook_deliveries_subscription_status_created_at_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_webhook_indexes}" != "0" ]]; then
    echo "Schema validation failed: webhook delivery indexes are missing." >&2
    exit 1
  fi

  plaintext_webhook_secret_columns="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = 'public' AND table_name IN ('webhook_subscriptions', 'webhook_deliveries') AND column_name IN ('secret', 'password', 'token', 'api_key', 'private_key', 'signing_secret', 'auth_secret');")"

  if [[ "${plaintext_webhook_secret_columns}" != "0" ]]; then
    echo "Schema validation failed: plaintext-like secret columns found in webhook tables." >&2
    exit 1
  fi
fi

secret_reference_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '019_create_secret_reference_schema.sql');")"

if [[ "${secret_reference_applied}" == "t" ]]; then
  missing_secret_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.secret_references'), ('public.secret_rotation_events')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_secret_tables}" != "0" ]]; then
    echo "Schema validation failed: secret reference tables are missing." >&2
    exit 1
  fi

  missing_secret_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('secret_references_tenant_env_name_unique'), ('secret_references_secret_ref_not_blank_check'), ('secret_rotation_events_secret_tenant_fk'), ('secret_rotation_events_status_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_secret_constraints}" != "0" ]]; then
    echo "Schema validation failed: secret reference constraints are missing." >&2
    exit 1
  fi

  missing_secret_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('secret_references_tenant_status_updated_at_idx'), ('secret_references_tenant_env_type_status_idx'), ('secret_rotation_events_secret_status_requested_at_idx'), ('secret_rotation_events_tenant_status_requested_at_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_secret_indexes}" != "0" ]]; then
    echo "Schema validation failed: secret reference indexes are missing." >&2
    exit 1
  fi

  plaintext_secret_columns="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = 'public' AND table_name IN ('secret_references', 'secret_rotation_events') AND column_name IN ('secret', 'password', 'token', 'api_key', 'private_key');")"

  if [[ "${plaintext_secret_columns}" != "0" ]]; then
    echo "Schema validation failed: plaintext-like secret columns found in secret reference tables." >&2
    exit 1
  fi
fi

knowledge_vector_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '020_create_knowledge_vector_schema.sql');")"

if [[ "${knowledge_vector_applied}" == "t" ]]; then
  vector_extension_exists="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'vector');")"

  if [[ "${vector_extension_exists}" != "t" ]]; then
    echo "Schema validation failed: vector extension is missing." >&2
    exit 1
  fi

  missing_knowledge_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.knowledge_collections'), ('public.knowledge_sources'), ('public.knowledge_source_versions'), ('public.knowledge_ingestion_jobs'), ('public.knowledge_chunks'), ('public.agent_knowledge_bindings')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_knowledge_tables}" != "0" ]]; then
    echo "Schema validation failed: knowledge vector tables are missing." >&2
    exit 1
  fi

  missing_knowledge_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('knowledge_collections_tenant_code_unique'), ('knowledge_sources_tenant_collection_source_unique'), ('knowledge_source_versions_source_version_unique'), ('knowledge_chunks_source_chunk_unique'), ('agent_knowledge_bindings_tenant_env_agent_collection_unique')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_knowledge_constraints}" != "0" ]]; then
    echo "Schema validation failed: knowledge vector constraints are missing." >&2
    exit 1
  fi

  missing_knowledge_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('knowledge_collections_tenant_status_updated_at_idx'), ('knowledge_source_versions_tenant_status_updated_at_idx'), ('knowledge_chunks_embedding_cosine_idx'), ('knowledge_ingestion_jobs_tenant_status_created_at_idx'), ('agent_knowledge_bindings_tenant_env_status_priority_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_knowledge_indexes}" != "0" ]]; then
    echo "Schema validation failed: knowledge vector indexes are missing." >&2
    exit 1
  fi
fi

compliance_consent_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '021_create_compliance_consent_schema.sql');")"

if [[ "${compliance_consent_applied}" == "t" ]]; then
  missing_compliance_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.retention_policies'), ('public.consent_policies'), ('public.consent_records'), ('public.data_export_requests'), ('public.data_deletion_requests'), ('public.pii_redaction_jobs')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_compliance_tables}" != "0" ]]; then
    echo "Schema validation failed: compliance/consent tables are missing." >&2
    exit 1
  fi

  missing_compliance_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('retention_policies_tenant_scope_name_unique'), ('consent_policies_tenant_env_name_version_unique'), ('consent_records_policy_tenant_fk'), ('data_export_requests_status_check'), ('data_deletion_requests_status_check'), ('pii_redaction_jobs_tenant_source_unique')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_compliance_constraints}" != "0" ]]; then
    echo "Schema validation failed: compliance/consent constraints are missing." >&2
    exit 1
  fi

  missing_compliance_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('retention_policies_tenant_status_updated_at_idx'), ('consent_policies_tenant_env_status_effective_idx'), ('consent_records_tenant_result_captured_at_idx'), ('data_export_requests_tenant_status_requested_at_idx'), ('data_deletion_requests_tenant_status_requested_at_idx'), ('pii_redaction_jobs_tenant_status_requested_at_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_compliance_indexes}" != "0" ]]; then
    echo "Schema validation failed: compliance/consent indexes are missing." >&2
    exit 1
  fi
fi

handoff_schema_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '022_create_handoff_schema.sql');")"

if [[ "${handoff_schema_applied}" == "t" ]]; then
  missing_handoff_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.handoff_queues'), ('public.human_agent_presence'), ('public.handoff_requests'), ('public.handoff_events')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_handoff_tables}" != "0" ]]; then
    echo "Schema validation failed: handoff tables are missing." >&2
    exit 1
  fi

  missing_handoff_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('handoff_queues_tenant_env_code_unique'), ('human_agent_presence_tenant_env_user_unique'), ('handoff_requests_actor_required_check'), ('handoff_events_request_tenant_fk'), ('handoff_events_actor_required_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_handoff_constraints}" != "0" ]]; then
    echo "Schema validation failed: handoff constraints are missing." >&2
    exit 1
  fi

  missing_handoff_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('handoff_queues_tenant_env_status_priority_idx'), ('human_agent_presence_tenant_env_status_seen_idx'), ('handoff_requests_tenant_status_requested_at_idx'), ('handoff_events_request_occurred_at_idx'), ('handoff_events_tenant_event_type_occurred_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_handoff_indexes}" != "0" ]]; then
    echo "Schema validation failed: handoff indexes are missing." >&2
    exit 1
  fi
fi

availability_sla_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '023_create_availability_sla_schema.sql');")"

if [[ "${availability_sla_applied}" == "t" ]]; then
  missing_availability_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.business_hours_policies'), ('public.holiday_calendars'), ('public.sla_policies'), ('public.escalation_policies')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_availability_tables}" != "0" ]]; then
    echo "Schema validation failed: availability/SLA tables are missing." >&2
    exit 1
  fi

  missing_availability_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('business_hours_policies_tenant_env_name_unique'), ('holiday_calendars_tenant_env_name_unique'), ('sla_policies_tenant_env_name_unique'), ('escalation_policies_tenant_env_name_unique'), ('escalation_policies_sla_policy_tenant_fk')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_availability_constraints}" != "0" ]]; then
    echo "Schema validation failed: availability/SLA constraints are missing." >&2
    exit 1
  fi

  missing_availability_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('business_hours_policies_tenant_env_status_idx'), ('holiday_calendars_tenant_env_status_idx'), ('sla_policies_tenant_env_status_entity_idx'), ('escalation_policies_tenant_env_status_trigger_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_availability_indexes}" != "0" ]]; then
    echo "Schema validation failed: availability/SLA indexes are missing." >&2
    exit 1
  fi
fi

notification_schema_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '024_create_notification_schema.sql');")"

if [[ "${notification_schema_applied}" == "t" ]]; then
  missing_notification_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.notification_templates'), ('public.notification_preferences'), ('public.notification_deliveries')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_notification_tables}" != "0" ]]; then
    echo "Schema validation failed: notification tables are missing." >&2
    exit 1
  fi

  missing_notification_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('notification_templates_tenant_code_channel_lang_unique'), ('notification_preferences_user_channel_scope_unique'), ('notification_deliveries_follow_up_task_tenant_fk'), ('notification_deliveries_status_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_notification_constraints}" != "0" ]]; then
    echo "Schema validation failed: notification constraints are missing." >&2
    exit 1
  fi

  missing_notification_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('notification_templates_tenant_channel_status_idx'), ('notification_preferences_tenant_channel_enabled_idx'), ('notification_deliveries_tenant_status_queued_at_idx'), ('notification_deliveries_follow_up_status_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_notification_indexes}" != "0" ]]; then
    echo "Schema validation failed: notification indexes are missing." >&2
    exit 1
  fi
fi

notification_inbox_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '056_create_user_notification_inbox.sql');")"

if [[ "${notification_inbox_applied}" == "t" ]]; then
  notification_inbox_table_exists="$(psql_command "${URL}" -tA -c "SELECT to_regclass('public.notifications') IS NOT NULL;")"

  if [[ "${notification_inbox_table_exists}" != "t" ]]; then
    echo "Schema validation failed: notification inbox table is missing." >&2
    exit 1
  fi

  missing_notification_inbox_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('notifications_public_id_unique'), ('notifications_recipient_user_tenant_fk'), ('notifications_status_check'), ('notifications_action_url_internal_check'), ('notifications_read_state_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_notification_inbox_constraints}" != "0" ]]; then
    echo "Schema validation failed: notification inbox constraints are missing." >&2
    exit 1
  fi

  missing_notification_inbox_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('notifications_recipient_status_created_at_idx'), ('notifications_recipient_created_at_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_notification_inbox_indexes}" != "0" ]]; then
    echo "Schema validation failed: notification inbox indexes are missing." >&2
    exit 1
  fi
fi

guardrail_schema_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '025_create_guardrail_schema.sql');")"

if [[ "${guardrail_schema_applied}" == "t" ]]; then
  missing_guardrail_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.guardrail_policies'), ('public.guardrail_policy_versions'), ('public.agent_guardrail_bindings'), ('public.policy_evaluation_logs')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_guardrail_tables}" != "0" ]]; then
    echo "Schema validation failed: guardrail tables are missing." >&2
    exit 1
  fi

  missing_guardrail_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('guardrail_policies_tenant_code_unique'), ('guardrail_policy_versions_policy_version_unique'), ('agent_guardrail_bindings_tenant_env_agent_policy_unique'), ('policy_evaluation_logs_policy_version_tenant_fk'), ('policy_evaluation_logs_result_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_guardrail_constraints}" != "0" ]]; then
    echo "Schema validation failed: guardrail constraints are missing." >&2
    exit 1
  fi

  missing_guardrail_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('guardrail_policies_tenant_status_updated_at_idx'), ('guardrail_policy_versions_tenant_status_updated_at_idx'), ('agent_guardrail_bindings_tenant_env_status_priority_idx'), ('policy_evaluation_logs_tenant_result_occurred_at_idx'), ('policy_evaluation_logs_tenant_policy_occurred_at_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_guardrail_indexes}" != "0" ]]; then
    echo "Schema validation failed: guardrail indexes are missing." >&2
    exit 1
  fi
fi

simulation_schema_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '026_create_simulation_schema.sql');")"

if [[ "${simulation_schema_applied}" == "t" ]]; then
  missing_simulation_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.simulation_scenarios'), ('public.simulation_assertions'), ('public.simulation_runs'), ('public.simulation_run_events')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_simulation_tables}" != "0" ]]; then
    echo "Schema validation failed: simulation tables are missing." >&2
    exit 1
  fi

  missing_simulation_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('simulation_scenarios_tenant_env_code_unique'), ('simulation_assertions_scenario_code_unique'), ('simulation_runs_scenario_tenant_fk'), ('simulation_runs_gate_decision_requires_terminal_state_check'), ('simulation_run_events_run_tenant_fk')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_simulation_constraints}" != "0" ]]; then
    echo "Schema validation failed: simulation constraints are missing." >&2
    exit 1
  fi

  missing_simulation_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('simulation_scenarios_tenant_env_status_updated_at_idx'), ('simulation_scenarios_tenant_agent_status_idx'), ('simulation_assertions_tenant_scenario_status_idx'), ('simulation_runs_tenant_env_status_created_at_idx'), ('simulation_runs_tenant_gate_decision_completed_at_idx'), ('simulation_run_events_tenant_run_occurred_at_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_simulation_indexes}" != "0" ]]; then
    echo "Schema validation failed: simulation indexes are missing." >&2
    exit 1
  fi
fi

telephony_abstraction_schema_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '027_create_telephony_abstraction_schema.sql');")"

if [[ "${telephony_abstraction_schema_applied}" == "t" ]]; then
  missing_telephony_abstraction_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.telephony_provider_accounts'), ('public.phone_number_orders'), ('public.provider_webhook_events'), ('public.provider_event_mappings')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_telephony_abstraction_tables}" != "0" ]]; then
    echo "Schema validation failed: telephony abstraction tables are missing." >&2
    exit 1
  fi

  missing_telephony_abstraction_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('telephony_provider_accounts_tenant_env_provider_ref_unique'), ('phone_number_orders_tenant_provider_order_unique'), ('provider_webhook_events_tenant_env_provider_event_unique'), ('provider_event_mappings_webhook_event_tenant_fk'), ('provider_event_mappings_error_on_failed_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_telephony_abstraction_constraints}" != "0" ]]; then
    echo "Schema validation failed: telephony abstraction constraints are missing." >&2
    exit 1
  fi

  missing_telephony_abstraction_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('telephony_provider_accounts_tenant_env_status_updated_at_idx'), ('phone_number_orders_tenant_env_status_requested_at_idx'), ('provider_webhook_events_tenant_status_received_at_idx'), ('provider_event_mappings_tenant_status_mapped_at_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_telephony_abstraction_indexes}" != "0" ]]; then
    echo "Schema validation failed: telephony abstraction indexes are missing." >&2
    exit 1
  fi
fi

analytics_reporting_schema_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '028_create_analytics_reporting_schema.sql');")"

if [[ "${analytics_reporting_schema_applied}" == "t" ]]; then
  missing_analytics_reporting_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.metric_snapshots'), ('public.report_definitions'), ('public.scheduled_reports'), ('public.report_deliveries')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_analytics_reporting_tables}" != "0" ]]; then
    echo "Schema validation failed: analytics/reporting tables are missing." >&2
    exit 1
  fi

  missing_analytics_reporting_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('metric_snapshots_tenant_scope_metric_window_dimension_unique'), ('report_definitions_tenant_code_unique'), ('scheduled_reports_definition_tenant_fk'), ('report_deliveries_artifact_tenant_fk'), ('report_deliveries_failed_requires_reason_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_analytics_reporting_constraints}" != "0" ]]; then
    echo "Schema validation failed: analytics/reporting constraints are missing." >&2
    exit 1
  fi

  missing_analytics_reporting_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('metric_snapshots_tenant_metric_window_start_idx'), ('report_definitions_tenant_status_updated_at_idx'), ('scheduled_reports_tenant_status_next_run_idx'), ('report_deliveries_tenant_status_requested_at_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_analytics_reporting_indexes}" != "0" ]]; then
    echo "Schema validation failed: analytics/reporting indexes are missing." >&2
    exit 1
  fi
fi

platform_security_operations_schema_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '029_create_platform_security_operations_schema.sql');")"

if [[ "${platform_security_operations_schema_applied}" == "t" ]]; then
  missing_platform_security_operations_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.platform_admin_users'), ('public.platform_admin_roles'), ('public.platform_admin_user_roles'), ('public.security_events'), ('public.security_incidents'), ('public.access_reviews'), ('public.access_review_items'), ('public.vulnerability_scan_runs'), ('public.vulnerability_findings'), ('public.sbom_snapshots'), ('public.dependency_scan_runs'), ('public.dependency_scan_findings')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_platform_security_operations_tables}" != "0" ]]; then
    echo "Schema validation failed: platform security/operations tables are missing." >&2
    exit 1
  fi

  missing_platform_security_operations_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('platform_admin_users_normalized_email_unique'), ('platform_admin_user_roles_user_role_unique'), ('security_incidents_incident_code_unique'), ('access_review_items_decision_review_pair_check'), ('vulnerability_findings_run_finding_key_unique'), ('dependency_scan_findings_run_package_issue_unique')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_platform_security_operations_constraints}" != "0" ]]; then
    echo "Schema validation failed: platform security/operations constraints are missing." >&2
    exit 1
  fi

  missing_platform_security_operations_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('platform_admin_users_status_updated_at_idx'), ('security_events_status_severity_occurred_at_idx'), ('security_incidents_status_severity_detected_at_idx'), ('access_reviews_scope_status_due_at_idx'), ('vulnerability_scan_runs_status_created_at_idx'), ('dependency_scan_runs_status_created_at_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_platform_security_operations_indexes}" != "0" ]]; then
    echo "Schema validation failed: platform security/operations indexes are missing." >&2
    exit 1
  fi
fi

platform_admin_role_public_ids_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '059_add_platform_admin_role_public_ids.sql');")"

if [[ "${platform_admin_role_public_ids_applied}" == "t" ]]; then
  missing_platform_admin_role_public_id_column="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'platform_admin_roles' AND column_name = 'public_id';")"

  if [[ "${missing_platform_admin_role_public_id_column}" != "1" ]]; then
    echo "Schema validation failed: platform admin role public_id column is missing." >&2
    exit 1
  fi

  missing_platform_admin_role_public_id_constraint="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM pg_constraint WHERE conname = 'platform_admin_roles_public_id_unique';")"

  if [[ "${missing_platform_admin_role_public_id_constraint}" != "1" ]]; then
    echo "Schema validation failed: platform admin role public_id unique constraint is missing." >&2
    exit 1
  fi
fi

management_identity_session_schema_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '058_create_management_identity_session_schema.sql');")"

if [[ "${management_identity_session_schema_applied}" == "t" ]]; then
  missing_management_identity_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.platform_admin_credentials'), ('public.platform_admin_sessions'), ('public.platform_admin_refresh_tokens'), ('public.platform_admin_permissions'), ('public.platform_admin_role_permissions')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_management_identity_tables}" != "0" ]]; then
    echo "Schema validation failed: management identity/session tables are missing." >&2
    exit 1
  fi

  missing_management_identity_columns="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('platform_admin_users', 'password_setup_required'), ('platform_admin_users', 'first_login_completed_at'), ('platform_admin_users', 'last_seen_at'), ('audit_logs', 'actor_platform_admin_user_id'), ('audit_logs', 'management_session_id')) AS required_column(table_name, column_name) WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = required_column.table_name AND column_name = required_column.column_name);")"

  if [[ "${missing_management_identity_columns}" != "0" ]]; then
    echo "Schema validation failed: management identity/session columns are missing." >&2
    exit 1
  fi

  missing_management_identity_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('platform_admin_credentials_user_type_identifier_unique'), ('platform_admin_credentials_secret_hash_length_check'), ('platform_admin_sessions_access_token_jti_unique'), ('platform_admin_sessions_csrf_token_hash_length_check'), ('platform_admin_refresh_tokens_token_hash_unique'), ('platform_admin_refresh_tokens_token_hash_length_check'), ('platform_admin_permissions_code_unique'), ('platform_admin_permissions_code_format_check'), ('platform_admin_role_permissions_role_permission_unique'), ('audit_logs_actor_platform_admin_user_fk'), ('audit_logs_management_session_fk'), ('audit_logs_platform_actor_required_check'), ('audit_logs_single_human_actor_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_management_identity_constraints}" != "0" ]]; then
    echo "Schema validation failed: management identity/session constraints are missing." >&2
    exit 1
  fi

  missing_management_identity_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('platform_admin_credentials_user_status_idx'), ('platform_admin_sessions_user_status_expires_at_idx'), ('platform_admin_sessions_status_last_seen_idx'), ('platform_admin_refresh_tokens_user_status_expires_at_idx'), ('platform_admin_refresh_tokens_family_status_idx'), ('platform_admin_permissions_category_code_idx'), ('platform_admin_role_permissions_permission_idx'), ('audit_logs_platform_actor_created_at_idx'), ('audit_logs_management_session_created_at_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = required_index.name);")"

  if [[ "${missing_management_identity_indexes}" != "0" ]]; then
    echo "Schema validation failed: management identity/session indexes are missing." >&2
    exit 1
  fi

  plaintext_like_management_columns="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = 'public' AND table_name IN ('platform_admin_credentials', 'platform_admin_sessions', 'platform_admin_refresh_tokens') AND column_name IN ('password', 'password_hash', 'secret', 'token', 'refresh_token', 'csrf_token', 'access_token', 'service_key');")"

  if [[ "${plaintext_like_management_columns}" != "0" ]]; then
    echo "Schema validation failed: plaintext-like secret columns found in management identity/session tables." >&2
    exit 1
  fi
fi

management_support_sessions_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '060_create_management_support_sessions.sql');")"

if [[ "${management_support_sessions_applied}" == "t" ]]; then
  support_sessions_table_exists="$(psql_command "${URL}" -tA -c "SELECT to_regclass('public.management_support_sessions') IS NOT NULL;")"

  if [[ "${support_sessions_table_exists}" != "t" ]]; then
    echo "Schema validation failed: management support sessions table is missing." >&2
    exit 1
  fi

  missing_support_sessions_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('management_support_sessions_public_id_unique'), ('management_support_sessions_tenant_id_fk'), ('management_support_sessions_requested_by_fk'), ('management_support_sessions_status_check'), ('management_support_sessions_access_scope_check'), ('management_support_sessions_reason_not_blank_check'), ('management_support_sessions_expiry_check'), ('management_support_sessions_metadata_object_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_support_sessions_constraints}" != "0" ]]; then
    echo "Schema validation failed: management support sessions constraints are missing." >&2
    exit 1
  fi

  missing_support_sessions_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('management_support_sessions_tenant_status_expires_at_idx'), ('management_support_sessions_requester_status_created_at_idx'), ('management_support_sessions_status_updated_at_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = required_index.name);")"

  if [[ "${missing_support_sessions_indexes}" != "0" ]]; then
    echo "Schema validation failed: management support sessions indexes are missing." >&2
    exit 1
  fi
fi

operational_reliability_schema_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '030_create_operational_reliability_schema.sql');")"

if [[ "${operational_reliability_schema_applied}" == "t" ]]; then
  missing_operational_reliability_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.feature_flags'), ('public.migration_jobs'), ('public.backup_restore_drills'), ('public.search_index_jobs'), ('public.import_jobs'), ('public.export_jobs'), ('public.slo_definitions'), ('public.alert_rules'), ('public.alert_events'), ('public.operational_incidents'), ('public.quota_policies'), ('public.quota_usage_snapshots')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_operational_reliability_tables}" != "0" ]]; then
    echo "Schema validation failed: operational reliability tables are missing." >&2
    exit 1
  fi

  missing_operational_reliability_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('feature_flags_scope_columns_check'), ('feature_flags_rollout_range_check'), ('import_jobs_artifact_tenant_fk'), ('alert_events_alert_rule_fk'), ('quota_policies_tenant_scope_code_unique'), ('quota_usage_snapshots_quota_policy_tenant_fk')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_operational_reliability_constraints}" != "0" ]]; then
    echo "Schema validation failed: operational reliability constraints are missing." >&2
    exit 1
  fi

  missing_operational_reliability_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('feature_flags_global_key_unique_idx'), ('search_index_jobs_tenant_status_queued_at_idx'), ('import_jobs_tenant_status_created_at_idx'), ('alert_events_status_triggered_at_idx'), ('quota_usage_snapshots_tenant_status_window_start_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = required_index.name);")"

  if [[ "${missing_operational_reliability_indexes}" != "0" ]]; then
    echo "Schema validation failed: operational reliability indexes are missing." >&2
    exit 1
  fi
fi

ai_call_sessions_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '045_create_ai_call_sessions.sql');")"
ai_call_session_key_deprecated_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '050_deprecate_ai_call_session_key.sql');")"

if [[ "${ai_call_sessions_applied}" == "t" ]]; then
  ai_call_sessions_table_exists="$(psql_command "${URL}" -tA -c "SELECT to_regclass('public.ai_call_sessions') IS NOT NULL;")"

  if [[ "${ai_call_sessions_table_exists}" != "t" ]]; then
    echo "Schema validation failed: AI call sessions table is missing." >&2
    exit 1
  fi

  if [[ "${ai_call_session_key_deprecated_applied}" == "t" ]]; then
    missing_ai_call_sessions_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('ai_call_sessions_pkey'), ('ai_call_sessions_data_object_check'), ('ai_call_sessions_status_check'), ('ai_call_sessions_updated_after_created_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"
  else
    missing_ai_call_sessions_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('ai_call_sessions_pkey'), ('ai_call_sessions_key_not_blank_check'), ('ai_call_sessions_data_object_check'), ('ai_call_sessions_status_check'), ('ai_call_sessions_updated_after_created_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"
  fi

  if [[ "${missing_ai_call_sessions_constraints}" != "0" ]]; then
    echo "Schema validation failed: AI call session constraints are missing." >&2
    exit 1
  fi
fi

ai_agent_settings_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '044_create_ai_agent_settings_schema.sql');")"
legacy_ai_instruction_storage_removed="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '070_remove_legacy_ai_instruction_storage.sql');")"

if [[ "${ai_agent_settings_applied}" == "t" && "${legacy_ai_instruction_storage_removed}" != "t" ]]; then
  ai_agent_settings_table_exists="$(psql_command "${URL}" -tA -c "SELECT to_regclass('public.ai_agent_settings') IS NOT NULL;")"

  if [[ "${ai_agent_settings_table_exists}" != "t" ]]; then
    echo "Schema validation failed: AI agent settings table is missing." >&2
    exit 1
  fi

  missing_ai_agent_settings_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('ai_agent_settings_pkey'), ('ai_agent_settings_public_id_unique'), ('ai_agent_settings_tenant_unique'), ('ai_agent_settings_tenant_id_fk'), ('ai_agent_settings_greeting_length_check'), ('ai_agent_settings_instructions_length_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_ai_agent_settings_constraints}" != "0" ]]; then
    echo "Schema validation failed: AI agent settings constraints are missing." >&2
    exit 1
  fi
fi

if [[ "${legacy_ai_instruction_storage_removed}" == "t" ]]; then
  legacy_ai_storage_exists="$(psql_command "${URL}" -tA -c "SELECT to_regclass('public.ai_agent_settings') IS NOT NULL OR EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ai_agents' AND column_name = 'instructions');")"

  if [[ "${legacy_ai_storage_exists}" != "f" ]]; then
    echo "Schema validation failed: legacy AI instruction storage still exists." >&2
    exit 1
  fi
fi

phone_number_lookup_index_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '046_create_phone_number_lookup_index.sql');")"

if [[ "${phone_number_lookup_index_applied}" == "t" ]]; then
  phone_number_lookup_index_valid="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid WHERE c.relname = 'phone_numbers_phone_number_lookup_idx' AND i.indisvalid);")"

  if [[ "${phone_number_lookup_index_valid}" != "t" ]]; then
    echo "Schema validation failed: phone number lookup index is missing or invalid." >&2
    exit 1
  fi
fi

ai_call_session_tenant_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '048_add_tenant_to_ai_call_sessions.sql');")"

if [[ "${ai_call_session_tenant_applied}" == "t" ]]; then
  ai_call_session_tenant_column_valid="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ai_call_sessions' AND column_name = 'tenant_id' AND is_nullable = 'NO');")"

  if [[ "${ai_call_session_tenant_column_valid}" != "t" ]]; then
    echo "Schema validation failed: AI call session tenant_id is missing or nullable." >&2
    exit 1
  fi

  ai_call_session_tenant_fk_valid="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ai_call_sessions_tenant_id_fk' AND contype = 'f');")"
  ai_call_session_tenant_index_valid="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'ai_call_sessions_tenant_updated_at_idx');")"

  if [[ "${ai_call_session_tenant_fk_valid}" != "t" || "${ai_call_session_tenant_index_valid}" != "t" ]]; then
    echo "Schema validation failed: AI call session tenant foreign key or lookup index is missing." >&2
    exit 1
  fi
fi

ai_call_session_create_update_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '049_split_ai_call_session_create_update.sql');")"

if [[ "${ai_call_session_create_update_applied}" == "t" ]]; then
  ai_call_session_identity_columns_valid="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) = 2 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ai_call_sessions' AND column_name IN ('id', 'public_id') AND is_nullable = 'NO';")"

  if [[ "${ai_call_session_identity_columns_valid}" != "t" ]]; then
    echo "Schema validation failed: AI call session identity columns are missing or nullable." >&2
    exit 1
  fi

  ai_call_session_identity_constraints_valid="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) = 2 FROM pg_constraint WHERE conname IN ('ai_call_sessions_pkey', 'ai_call_sessions_public_id_unique');")"

  if [[ "${ai_call_session_identity_constraints_valid}" != "t" ]]; then
    echo "Schema validation failed: AI call session identity constraints are missing." >&2
    exit 1
  fi

  if [[ "${ai_call_session_key_deprecated_applied}" != "t" ]]; then
    ai_call_session_key_index_valid="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'ai_call_sessions_key_created_at_idx');")"

    if [[ "${ai_call_session_key_index_valid}" != "t" ]]; then
      echo "Schema validation failed: AI call session key index is missing." >&2
      exit 1
    fi
  fi
fi

if [[ "${ai_call_session_key_deprecated_applied}" == "t" ]]; then
  ai_call_session_key_column_removed="$(psql_command "${URL}" -tA -c "SELECT NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ai_call_sessions' AND column_name = 'key');")"
  ai_call_session_key_constraint_removed="$(psql_command "${URL}" -tA -c "SELECT NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ai_call_sessions_key_not_blank_check');")"
  ai_call_session_key_index_removed="$(psql_command "${URL}" -tA -c "SELECT NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'ai_call_sessions_key_created_at_idx');")"

  if [[ "${ai_call_session_key_column_removed}" != "t" || "${ai_call_session_key_constraint_removed}" != "t" || "${ai_call_session_key_index_removed}" != "t" ]]; then
    echo "Schema validation failed: deprecated AI call session key artifacts still exist." >&2
    exit 1
  fi
fi

hotel_booking_removed="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '071_remove_hotel_booking_modules.sql');")"

if [[ "${hotel_booking_removed}" == "t" ]]; then
  remaining_booking_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.bookable_resources'), ('public.resource_offers'), ('public.resource_availability'), ('public.booking_reservation_requests'), ('public.hotelrunner_reservation_outbox'), ('public.hotelrunner_webhook_debug_logs')) AS removed_table(name) WHERE to_regclass(removed_table.name) IS NOT NULL;")"
  if [[ "${remaining_booking_tables}" != "0" ]]; then
    echo "Schema validation failed: retired hotel booking tables remain." >&2
    exit 1
  fi
fi

booking_availability_cache_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '051_create_booking_availability_cache.sql');")"

if [[ "${booking_availability_cache_applied}" == "t" && "${hotel_booking_removed}" != "t" ]]; then
  missing_booking_availability_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.bookable_resources'), ('public.resource_offers'), ('public.resource_availability')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_booking_availability_tables}" != "0" ]]; then
    echo "Schema validation failed: booking availability cache tables are missing." >&2
    exit 1
  fi

  missing_booking_availability_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('bookable_resources_public_id_unique'), ('bookable_resources_tenant_id_fk'), ('bookable_resources_integration_tenant_fk'), ('bookable_resources_provider_unique'), ('bookable_resources_type_not_blank_check'), ('bookable_resources_provider_id_not_blank_check'), ('bookable_resources_name_not_blank_check'), ('bookable_resources_status_check'), ('bookable_resources_metadata_object_check'), ('bookable_resources_payload_object_check'), ('resource_offers_public_id_unique'), ('resource_offers_tenant_id_fk'), ('resource_offers_integration_tenant_fk'), ('resource_offers_resource_fk'), ('resource_offers_provider_unique'), ('resource_offers_type_not_blank_check'), ('resource_offers_provider_id_not_blank_check'), ('resource_offers_name_not_blank_check'), ('resource_offers_status_check'), ('resource_offers_metadata_object_check'), ('resource_offers_payload_object_check'), ('resource_availability_public_id_unique'), ('resource_availability_tenant_id_fk'), ('resource_availability_integration_tenant_fk'), ('resource_availability_resource_fk'), ('resource_availability_offer_fk'), ('resource_availability_offer_date_unique'), ('resource_availability_price_non_negative_check'), ('resource_availability_currency_upper_check'), ('resource_availability_allocation_non_negative_check'), ('resource_availability_min_stay_check'), ('resource_availability_release_hour_check'), ('resource_availability_source_not_blank_check'), ('resource_availability_payload_object_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_booking_availability_constraints}" != "0" ]]; then
    echo "Schema validation failed: booking availability cache constraints are missing." >&2
    exit 1
  fi

  missing_booking_availability_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('bookable_resources_tenant_integration_status_idx'), ('resource_offers_tenant_resource_status_idx'), ('resource_availability_tenant_date_idx'), ('resource_availability_offer_date_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = required_index.name);")"

  if [[ "${missing_booking_availability_indexes}" != "0" ]]; then
    echo "Schema validation failed: booking availability cache indexes are missing." >&2
    exit 1
  fi
fi

web_push_delivery_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '057_add_web_push_delivery.sql');")"

if [[ "${web_push_delivery_applied}" == "t" ]]; then
  web_push_table_exists="$(psql_command "${URL}" -tA -c "SELECT to_regclass('public.web_push_subscriptions') IS NOT NULL;")"
  missing_web_push_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('web_push_subscriptions_public_id_unique'), ('web_push_subscriptions_id_tenant_id_unique'), ('web_push_subscriptions_tenant_id_fk'), ('web_push_subscriptions_user_tenant_fk'), ('web_push_subscriptions_endpoint_hash_check'), ('web_push_subscriptions_encrypted_subscription_not_blank_check'), ('web_push_subscriptions_encryption_auth_tag_not_blank_check'), ('web_push_subscriptions_encryption_iv_not_blank_check'), ('web_push_subscriptions_encryption_key_version_not_blank_check'), ('web_push_subscriptions_status_check'), ('notification_deliveries_source_notification_tenant_fk'), ('notification_deliveries_web_push_subscription_tenant_fk')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"
  missing_web_push_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('web_push_subscriptions_endpoint_hash_unique_idx'), ('web_push_subscriptions_user_status_updated_at_idx'), ('notification_deliveries_source_push_unique_idx'), ('notification_deliveries_push_status_queued_at_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = required_index.name);")"
  push_channel_constraints_valid="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) = 3 FROM pg_constraint WHERE conname IN ('notification_templates_channel_check', 'notification_preferences_channel_check', 'notification_deliveries_channel_check') AND pg_get_constraintdef(oid) LIKE '%push%';")"

  if [[ "${web_push_table_exists}" != "t" || "${missing_web_push_constraints}" != "0" || "${missing_web_push_indexes}" != "0" || "${push_channel_constraints_valid}" != "t" ]]; then
    echo "Schema validation failed: web push delivery schema is incomplete." >&2
    exit 1
  fi
fi

industry_catalog_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '063_create_industry_catalog.sql');")"

if [[ "${industry_catalog_applied}" == "t" ]]; then
  industries_table_exists="$(psql_command "${URL}" -tA -c "SELECT to_regclass('public.industries') IS NOT NULL;")"

  if [[ "${industries_table_exists}" != "t" ]]; then
    echo "Schema validation failed: industries table is missing." >&2
    exit 1
  fi

  missing_industry_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('industries_pkey'), ('industries_public_id_unique'), ('industries_code_unique'), ('industries_code_format_check'), ('industries_name_not_blank_check'), ('industries_status_check'), ('industries_sort_order_non_negative_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${missing_industry_constraints}" != "0" ]]; then
    echo "Schema validation failed: industry catalog constraints are missing." >&2
    exit 1
  fi

  industry_catalog_index_exists="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'industries_status_sort_order_code_idx');")"

  if [[ "${industry_catalog_index_exists}" != "t" ]]; then
    echo "Schema validation failed: industry catalog lookup index is missing." >&2
    exit 1
  fi

  required_industries_valid="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) = 2 FROM public.industries WHERE (code, name, status, sort_order) IN (('hospitality_accommodation', 'Otelcilik & Konaklama', 'active', 10), ('food_beverage_restaurant', 'Yeme-İçme & Restaurant', 'active', 20));")"

  if [[ "${required_industries_valid}" != "t" ]]; then
    echo "Schema validation failed: required industry reference data is missing or invalid." >&2
    exit 1
  fi
fi

tenant_industry_link_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '064_link_tenants_to_industries.sql');")"

if [[ "${tenant_industry_link_applied}" == "t" ]]; then
  tenant_industry_column_valid="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'tenants' AND column_name = 'industry_id' AND data_type = 'bigint');")"
  tenant_industry_fk_valid="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tenants_industry_id_fk' AND contype = 'f');")"
  tenant_industry_index_valid="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'tenants_industry_status_created_at_idx');")"

  if [[ "${tenant_industry_column_valid}" != "t" || "${tenant_industry_fk_valid}" != "t" || "${tenant_industry_index_valid}" != "t" ]]; then
    echo "Schema validation failed: tenant industry relationship is incomplete." >&2
    exit 1
  fi
fi

industry_agent_builder_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '065_create_industry_agent_builder_schema.sql');")"

if [[ "${industry_agent_builder_applied}" == "t" ]]; then
  missing_industry_agent_builder_tables="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('public.industry_agent_templates'), ('public.industry_agent_template_versions'), ('public.industry_agent_template_sections'), ('public.agent_config_section_values')) AS required_table(name) WHERE to_regclass(required_table.name) IS NULL;")"

  if [[ "${missing_industry_agent_builder_tables}" != "0" ]]; then
    echo "Schema validation failed: industry agent builder tables are missing." >&2
    exit 1
  fi

  industry_template_column_valid="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'agent_config_versions' AND column_name = 'industry_agent_template_version_id' AND data_type = 'bigint');")"
  missing_industry_agent_builder_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('industry_agent_templates_public_id_unique'), ('industry_agent_templates_industry_code_unique'), ('industry_agent_templates_industry_id_fk'), ('industry_agent_templates_code_format_check'), ('industry_agent_templates_status_check'), ('industry_agent_template_versions_public_id_unique'), ('industry_agent_template_versions_template_version_unique'), ('industry_agent_template_versions_template_id_fk'), ('industry_agent_template_versions_status_check'), ('industry_agent_template_sections_public_id_unique'), ('industry_agent_template_sections_version_key_unique'), ('industry_agent_template_sections_version_order_unique'), ('industry_agent_template_sections_template_version_id_fk'), ('agent_config_versions_industry_template_version_fk'), ('agent_config_section_values_public_id_unique'), ('agent_config_section_values_version_section_unique'), ('agent_config_section_values_tenant_id_fk'), ('agent_config_section_values_version_tenant_fk'), ('agent_config_section_values_template_section_id_fk'), ('agent_config_section_values_payload_object_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"

  if [[ "${industry_template_column_valid}" != "t" || "${missing_industry_agent_builder_constraints}" != "0" ]]; then
    echo "Schema validation failed: industry agent builder columns or constraints are incomplete." >&2
    exit 1
  fi

  missing_industry_agent_builder_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('industry_agent_templates_industry_status_code_idx'), ('industry_agent_template_versions_one_active_idx'), ('agent_config_versions_industry_template_version_idx'), ('agent_config_section_values_tenant_version_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = required_index.name);")"
  missing_industry_agent_builder_triggers="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('agent_config_section_values_validate_mutation'), ('agent_config_versions_prevent_template_version_mutation')) AS required_trigger(name) WHERE NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = required_trigger.name AND NOT tgisinternal);")"

  if [[ "${missing_industry_agent_builder_indexes}" != "0" || "${missing_industry_agent_builder_triggers}" != "0" ]]; then
    echo "Schema validation failed: industry agent builder indexes or mutation guards are missing." >&2
    exit 1
  fi

  hotel_template_seed_valid="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) = 7 FROM public.industry_agent_templates template JOIN public.industries industry ON industry.id = template.industry_id JOIN public.industry_agent_template_versions template_version ON template_version.industry_agent_template_id = template.id AND template_version.status = 'active' JOIN public.industry_agent_template_sections section ON section.industry_agent_template_version_id = template_version.id WHERE industry.code = 'hospitality_accommodation' AND template.code = 'hotel_guest_assistant';")"

  if [[ "${hotel_template_seed_valid}" != "t" ]]; then
    echo "Schema validation failed: active hotel agent template or its seven sections are missing." >&2
    exit 1
  fi
fi

relaxed_agent_builder_currency_format_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '066_relax_agent_builder_currency_format.sql');")"

if [[ "${relaxed_agent_builder_currency_format_applied}" == "t" ]]; then
  hotel_currency_format_is_free_text="$(psql_command "${URL}" -tA -c "SELECT section.validation_schema #> '{properties,currencies,items,pattern}' IS NULL FROM public.industry_agent_template_sections section JOIN public.industry_agent_template_versions template_version ON template_version.id = section.industry_agent_template_version_id JOIN public.industry_agent_templates template ON template.id = template_version.industry_agent_template_id WHERE template.code = 'hotel_guest_assistant' AND template_version.version_no = 1 AND section.section_key = 'payment_cancellation';")"

  if [[ "${hotel_currency_format_is_free_text}" != "t" ]]; then
    echo "Schema validation failed: hotel agent currency values must accept free text." >&2
    exit 1
  fi
fi

agent_config_improvement_runs_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '067_create_agent_config_improvement_runs.sql');")"

if [[ "${agent_config_improvement_runs_applied}" == "t" ]]; then
  improvement_runs_table_valid="$(psql_command "${URL}" -tA -c "SELECT to_regclass('public.agent_config_improvement_runs') IS NOT NULL;")"
  missing_improvement_run_constraints="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('agent_config_improvement_runs_public_id_unique'), ('agent_config_improvement_runs_tenant_id_fk'), ('agent_config_improvement_runs_version_tenant_fk'), ('agent_config_improvement_runs_requester_tenant_fk'), ('agent_config_improvement_runs_status_check'), ('agent_config_improvement_runs_source_hash_check'), ('agent_config_improvement_runs_completion_state_check')) AS required_constraint(name) WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = required_constraint.name);")"
  missing_improvement_run_indexes="$(psql_command "${URL}" -tA -c "SELECT COUNT(*) FROM (VALUES ('agent_config_improvement_runs_tenant_version_created_idx'), ('agent_config_improvement_runs_expiry_status_idx')) AS required_index(name) WHERE NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = required_index.name);")"

  if [[ "${improvement_runs_table_valid}" != "t" || "${missing_improvement_run_constraints}" != "0" || "${missing_improvement_run_indexes}" != "0" ]]; then
    echo "Schema validation failed: agent config improvement run schema is incomplete." >&2
    exit 1
  fi
fi

echo "Schema validation passed. Applied migrations: ${applied_count}."

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '074_add_caller_contact_foundation.sql') THEN
  IF (SELECT count(*) FROM public.contact_statuses) <> 6 THEN RAISE EXCEPTION 'Caller contact status catalog is incomplete'; END IF;
  IF EXISTS (SELECT 1 FROM (VALUES ('contact_import_previews'), ('contact_import_preview_rows'), ('contact_lists'), ('contact_list_members'), ('contact_change_events'), ('contact_consents'), ('contact_identity_revisions')) AS required(name)
             WHERE to_regclass('public.' || required.name) IS NULL) THEN RAISE EXCEPTION 'Caller contact tables are missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'customers_canonical_phone_unique' AND conrelid = 'public.customers'::regclass) THEN
   RAISE EXCEPTION 'Caller canonical phone uniqueness is missing'; END IF;
 END IF;
 IF EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '075_guard_canonical_contact_identity.sql') THEN
  IF (SELECT count(*) FROM pg_trigger WHERE tgname IN ('customers_guard_canonical_identity', 'customer_contacts_guard_canonical_identity') AND NOT tgisinternal) <> 2 THEN
   RAISE EXCEPTION 'Caller legacy-write guards are missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='082_partition_customer_contact_channels.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='customer_contacts_snapshot_identity' AND NOT tgisinternal) THEN
   RAISE EXCEPTION 'Contact channel identity guard missing'; END IF;
  IF EXISTS(SELECT 1 FROM public.customer_contacts WHERE customer_identity_revision IS NULL OR customer_identity_revision<1) THEN
   RAISE EXCEPTION 'Invalid contact channel identity'; END IF;
 END IF;
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='083_snapshot_contact_identity_profiles.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='contact_identity_revisions_snapshot_profile' AND NOT tgisinternal) THEN
   RAISE EXCEPTION 'Identity profile archive guard missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='084_guard_historical_work_reactivation.sql') THEN
  IF (SELECT count(*) FROM pg_trigger WHERE NOT tgisinternal AND tgname IN
   ('cases_guard_reactivation','leads_guard_reactivation','follow_up_tasks_guard_reactivation',
    'handoff_requests_guard_reactivation','workflow_runs_guard_reactivation','external_object_references_guard_reactivation',
    'calls_guard_identity_reactivation','call_sessions_guard_identity_reactivation'))<>8 THEN
   RAISE EXCEPTION 'Historical work reactivation guards missing'; END IF;
 END IF;
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='085_serialize_ai_session_identity.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='ai_call_sessions_guard_identity' AND NOT tgisinternal) THEN
   RAISE EXCEPTION 'AI session identity serialization missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='087_publish_contact_preference_outbox.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='contact_change_events_publish_preference' AND NOT tgisinternal) THEN
   RAISE EXCEPTION 'Contact preference outbox trigger missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='091_add_import_retention_summary.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='contact_import_previews' AND column_name='data_purged_at')
    OR NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='contact_import_jobs_retained_counts_complete')
    OR to_regclass('public.contact_import_previews_retention_idx') IS NULL THEN
   RAISE EXCEPTION 'Import retention schema incomplete';
  END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='092_create_caller_campaign_drafts.sql') THEN
  IF to_regclass('public.caller_campaigns') IS NULL
   OR to_regclass('public.caller_campaign_versions_one_draft_idx') IS NULL
   OR to_regclass('public.caller_campaign_source_lists_list_idx') IS NULL THEN
   RAISE EXCEPTION 'Campaign draft schema incomplete';
  END IF;
  IF EXISTS(SELECT 1 FROM public.caller_campaigns WHERE state <> 'draft') THEN
   RAISE EXCEPTION 'Publication is not enabled in draft foundation';
  END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='093_add_campaign_operational_settings.sql') THEN
  IF to_regclass('public.caller_campaign_versions_agent_idx') IS NULL
   OR NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='caller_campaign_versions_window')
   OR NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='caller_campaign_versions_dates')
   OR NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='caller_campaign_versions_agent_fk') THEN
   RAISE EXCEPTION 'Campaign operational settings schema incomplete';
  END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='094_create_campaign_survey_questions.sql') THEN
  IF to_regclass('public.caller_survey_questions') IS NULL
   OR NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='caller_survey_question_position' AND condeferrable AND condeferred) THEN
   RAISE EXCEPTION 'Campaign survey definition schema incomplete';
  END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='095_create_campaign_snapshots.sql') THEN
  IF to_regclass('public.caller_campaign_snapshots') IS NULL
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='caller_campaign_snapshots_immutable' AND NOT tgisinternal AND tgenabled='O') THEN
   RAISE EXCEPTION 'Campaign snapshot schema incomplete';
  END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='096_create_campaign_targets.sql') THEN
  IF to_regclass('public.caller_campaign_targets') IS NULL
   OR to_regclass('public.caller_campaign_target_sources') IS NULL
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='caller_campaign_target_guard' AND NOT tgisinternal AND tgenabled='O')
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='caller_campaign_target_source_guard' AND NOT tgisinternal AND tgenabled='O') THEN
   RAISE EXCEPTION 'Campaign target schema incomplete';
  END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='097_create_survey_sessions.sql') THEN
  IF to_regclass('public.caller_survey_sessions') IS NULL
   OR to_regclass('public.caller_survey_answer_revisions') IS NULL
   OR to_regclass('public.caller_survey_answer_active_idx') IS NULL
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='caller_survey_session_guard' AND NOT tgisinternal AND tgenabled='O')
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='caller_survey_answer_guard' AND NOT tgisinternal AND tgenabled='O') THEN
   RAISE EXCEPTION 'Survey session schema incomplete';
  END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='098_create_billing_tariff_versions.sql') THEN
  IF to_regclass('public.billing_tariff_versions') IS NULL
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='billing_tariff_version_guard' AND NOT tgisinternal AND tgenabled='O') THEN
   RAISE EXCEPTION 'Billing tariff schema incomplete';
  END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='099_create_billing_ledger.sql') THEN
  IF to_regclass('public.billing_accounts') IS NULL OR to_regclass('public.billing_ledger_entries') IS NULL
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='billing_ledger_apply' AND NOT tgisinternal AND tgenabled='O')
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='billing_ledger_post' AND NOT tgisinternal AND tgenabled='O')
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='billing_account_guard' AND NOT tgisinternal AND tgenabled='O') THEN
   RAISE EXCEPTION 'Prepaid ledger schema incomplete';
  END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='100_create_billing_reservations.sql') THEN
  IF to_regclass('public.billing_reservations') IS NULL
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='billing_reservation_guard' AND NOT tgisinternal AND tgenabled='O')
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='billing_reservation_final_check' AND tgdeferrable AND tginitdeferred AND tgenabled='O') THEN
   RAISE EXCEPTION 'Billing reservation schema incomplete';
  END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='101_create_billing_budget_limits.sql') THEN
  IF to_regclass('public.billing_budget_limits') IS NULL
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='billing_budget_limit_guard' AND NOT tgisinternal AND tgenabled='O') THEN
   RAISE EXCEPTION 'Billing budget schema incomplete';
  END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='102_add_billing_budget_events.sql') THEN
  IF to_regclass('public.billing_budget_events') IS NULL
   OR NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='billing_budget_limits' AND column_name='limit_revision')
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='billing_budget_event_guard' AND NOT tgisinternal AND tgenabled='O') THEN
   RAISE EXCEPTION 'Billing budget events schema incomplete';
  END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='103_fix_billing_tariff_platform_actor.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='billing_tariff_platform_actor_fkey'
    AND conrelid='public.billing_tariff_versions'::regclass
    AND confrelid='public.platform_admin_users'::regclass)
   OR EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public'
     AND table_name='billing_tariff_versions' AND column_name='published_by_user_id') THEN
   RAISE EXCEPTION 'Billing tariff platform actor schema incomplete';
  END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='104_add_tariff_publication_receipt.sql') THEN
  IF to_regclass('public.tariff_publication_receipt_key') IS NULL
   OR NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='tariff_publication_receipt_pair' AND conrelid='public.billing_tariff_versions'::regclass) THEN
   RAISE EXCEPTION 'Tariff publication receipt schema incomplete';
  END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='105_index_ledger_source_lookup.sql')
  AND to_regclass('public.billing_ledger_tenant_source_idx') IS NULL THEN
  RAISE EXCEPTION 'Tenant ledger source lookup index missing';
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='106_guard_billing_adjustments.sql') THEN
  IF to_regclass('public.billing_ledger_correction_idx') IS NULL
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='billing_adjustment_guard' AND NOT tgisinternal AND tgenabled='O') THEN
   RAISE EXCEPTION 'Billing correction safeguard schema incomplete';
  END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='107_create_billing_plan_receipts.sql') THEN
  IF to_regclass('public.billing_plan_creation_receipts') IS NULL
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='billing_plan_receipt_guard' AND NOT tgisinternal AND tgenabled='O') THEN
   RAISE EXCEPTION 'Billing plan creation receipt schema incomplete';
  END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='108_add_campaign_outbound_phone.sql') THEN
  IF to_regclass('public.caller_campaign_outbound_phone_idx') IS NULL
   OR NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='caller_campaign_outbound_phone_fk' AND conrelid='public.caller_campaign_versions'::regclass) THEN
   RAISE EXCEPTION 'Campaign outbound phone schema incomplete';
  END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='109_create_caller_dispatch_intents.sql') THEN
  IF to_regclass('public.caller_dispatch_intents') IS NULL OR to_regclass('public.caller_dispatch_open_phone') IS NULL
   OR (SELECT count(*) FROM pg_trigger WHERE tgname IN ('caller_dispatch_guard','caller_dispatch_count','caller_target_claim_guard','caller_dispatch_reservation_guard') AND NOT tgisinternal AND tgenabled='O')<>4 THEN
   RAISE EXCEPTION 'Caller dispatch safeguard schema incomplete';
  END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='110_index_dispatch_cooldown_history.sql')
  AND (to_regclass('public.caller_dispatch_phone_end_history') IS NULL OR to_regclass('public.caller_dispatch_campaign_end_history') IS NULL) THEN
  RAISE EXCEPTION 'Dispatch cooldown history indexes missing';
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='111_guard_submitted_dispatch_release.sql')
  AND NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='caller_dispatch_release_guard' AND NOT tgisinternal AND tgenabled='O' AND tgdeferrable AND tginitdeferred) THEN
  RAISE EXCEPTION 'Submitted dispatch release protection missing';
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='112_create_dispatch_transition_history.sql') THEN
  IF to_regclass('public.caller_dispatch_transitions') IS NULL OR to_regclass('public.caller_dispatch_transitions_scope') IS NULL
   OR (SELECT count(*) FROM pg_trigger WHERE tgname IN ('caller_dispatch_transition_guard','caller_dispatch_history') AND NOT tgisinternal AND tgenabled='O')<>2 THEN
   RAISE EXCEPTION 'Dispatch transition history safeguards missing';
  END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='113_caller_dispatch_event_receipts.sql') THEN
  IF to_regclass('public.caller_dispatch_event_receipts') IS NULL OR to_regclass('public.caller_dispatch_event_receipts_history') IS NULL
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='caller_dispatch_event_receipt_guard' AND NOT tgisinternal AND tgenabled='O') THEN
   RAISE EXCEPTION 'Dispatch provider event receipt safeguards missing';
  END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='114_dispatch_campaign_operations_index.sql')
  AND to_regclass('public.caller_dispatch_campaign_operations_idx') IS NULL THEN
  RAISE EXCEPTION 'Campaign operations dispatch index missing';
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='115_provider_circuit_state.sql') THEN
  IF to_regclass('public.caller_provider_circuits') IS NULL OR to_regclass('public.caller_provider_circuit_receipts') IS NULL
   OR to_regclass('public.caller_provider_circuits_due_idx') IS NULL
   OR (SELECT count(*) FROM pg_trigger WHERE tgname IN ('caller_provider_circuit_guard','caller_provider_circuit_receipt_guard') AND NOT tgisinternal AND tgenabled='O')<>2 THEN
   RAISE EXCEPTION 'Provider circuit persistence safeguards missing';
  END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='116_calling_policy_versions.sql') THEN
  IF to_regclass('public.caller_calling_policy_versions') IS NULL
   OR to_regclass('public.caller_calling_policy_country_effective') IS NULL
   OR to_regclass('public.caller_calling_policy_tenant_effective') IS NULL
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='caller_calling_policy_guard' AND NOT tgisinternal AND tgenabled='O') THEN
   RAISE EXCEPTION 'Calling policy safeguards missing';
  END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='117_calling_policy_publication_receipt.sql')
 AND to_regclass('public.caller_calling_policy_publication_key') IS NULL THEN RAISE EXCEPTION 'Calling policy publication receipt index missing'; END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='118_calling_policy_cancellations.sql') THEN
  IF to_regclass('public.caller_calling_policy_cancellations') IS NULL OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='caller_calling_policy_cancellation_guard' AND NOT tgisinternal AND tgenabled='O') THEN RAISE EXCEPTION 'Calling policy cancellation safeguards missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='119_campaign_stop_requests.sql') THEN
  IF to_regclass('public.caller_campaign_stop_requests') IS NULL
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='caller_campaign_stop_request_guard' AND NOT tgisinternal AND tgenabled='O')
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='caller_dispatch_campaign_stop_guard' AND NOT tgisinternal AND tgenabled='O') THEN RAISE EXCEPTION 'Campaign stop guards missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='120_campaign_stop_states.sql') THEN
  IF to_regclass('public.caller_campaign_state_events') IS NULL
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='caller_campaign_stop_state_guard' AND NOT tgisinternal AND tgenabled='O')
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='caller_campaign_state_event_guard' AND NOT tgisinternal AND tgenabled='O')
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='caller_campaign_stop_request_apply' AND NOT tgisinternal AND tgenabled='O') THEN RAISE EXCEPTION 'Campaign stop state safeguards missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='121_campaign_target_cancellation.sql') THEN
  IF to_regclass('public.caller_campaign_target_pending_cancel') IS NULL
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='caller_target_cancellation_guard' AND NOT tgisinternal AND tgenabled='O') THEN RAISE EXCEPTION 'Campaign target cancellation safeguards missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='122_confirmed_callback_plans.sql') THEN
  IF to_regclass('public.caller_callback_plans') IS NULL OR to_regclass('public.caller_callback_one_pending_target') IS NULL
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='caller_callback_plan_guard' AND NOT tgisinternal AND tgenabled='O') THEN RAISE EXCEPTION 'Callback plan safeguards missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='123_campaign_terminal_cancellation.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.caller_campaigns'::regclass AND conname='caller_campaigns_state_check' AND pg_get_constraintdef(oid) LIKE '%canceled%') THEN RAISE EXCEPTION 'Terminal campaign cancellation constraint missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='124_active_campaign_stop.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.caller_campaigns'::regclass AND conname='caller_campaign_active_stop_scope')
   OR NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.caller_campaign_stop_requests'::regclass AND conname='caller_stop_supersedes_scope')
   OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='caller_campaign_stop_state_guard' AND NOT tgisinternal AND tgenabled='O') THEN RAISE EXCEPTION 'Active stop safeguards missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$
DECLARE content_table regclass;
BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='174_campaign_report_export_contents.sql') THEN
  content_table:=to_regclass('public.caller_report_export_contents');
  IF content_table IS NULL THEN RAISE EXCEPTION 'Report export content table missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid=content_table
    AND tgname='caller_report_export_content_guard' AND NOT tgisinternal AND tgenabled='O'
    AND tgtype=31 AND tgfoid=to_regprocedure('public.guard_report_export_content()')) THEN
   RAISE EXCEPTION 'Report export content write/expiry guard missing or disabled'; END IF;
  IF (SELECT count(*) FROM pg_constraint WHERE conrelid=content_table AND contype='f' AND convalidated
    AND array_length(conkey,1)=2 AND confrelid IN ('public.artifacts'::regclass,'public.export_jobs'::regclass,
      'public.background_jobs'::regclass,'public.job_attempts'::regclass))<>4 THEN
   RAISE EXCEPTION 'Report export tenant composite foreign keys missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.export_jobs'::regclass
    AND conname='export_jobs_id_tenant_unique' AND contype='u' AND convalidated) THEN
   RAISE EXCEPTION 'Report export composite identity missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_index WHERE indexrelid=to_regclass('public.caller_report_export_expiry_idx')
    AND indrelid=content_table AND indisvalid AND indisready) THEN
   RAISE EXCEPTION 'Report export expiry index missing or invalid'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid=content_table AND contype='c' AND convalidated
    AND pg_get_constraintdef(oid) LIKE '%octet_length(csv_content)%10485760%') THEN
   RAISE EXCEPTION 'Report export byte-size bound missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$
DECLARE enrollment_table regclass;
BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='175_test_number_enrollment.sql') THEN
  enrollment_table:=to_regclass('public.caller_test_numbers');
  IF enrollment_table IS NULL THEN RAISE EXCEPTION 'Test number enrollment table missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid=enrollment_table
    AND tgname='caller_test_number_enrollment_guard' AND NOT tgisinternal AND tgenabled='O'
    AND tgtype=31 AND tgfoid=to_regprocedure('public.guard_test_number_enrollment()')) THEN
   RAISE EXCEPTION 'Test number identity/history guard missing or disabled'; END IF;
  IF (SELECT count(*) FROM pg_constraint WHERE conrelid=enrollment_table AND contype='f' AND convalidated
    AND array_length(conkey,1)=2 AND confrelid='public.users'::regclass)<>2 THEN
   RAISE EXCEPTION 'Test number tenant-scoped actor foreign keys missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_index WHERE indexrelid=to_regclass('public.caller_test_number_active_unique')
    AND indrelid=enrollment_table AND indisunique AND indisvalid AND indisready
    AND pg_get_expr(indpred,indrelid) = '(state = ''active''::text)'
    AND pg_get_indexdef(indexrelid,1,true)='tenant_id'
    AND pg_get_indexdef(indexrelid,2,true)='canonical_phone'
    AND indnkeyatts=2) THEN
   RAISE EXCEPTION 'Test number active tenant/phone uniqueness missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_index WHERE indexrelid=to_regclass('public.caller_test_number_history_idx')
    AND indrelid=enrollment_table AND indisvalid AND indisready) THEN
   RAISE EXCEPTION 'Test number history index missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid=enrollment_table AND contype='c' AND convalidated
    AND pg_get_constraintdef(oid) LIKE '%state%active%revoked_at IS NULL%revoked_by_user_id IS NULL%revocation_reason IS NULL%'
    AND pg_get_constraintdef(oid) LIKE '%state%revoked%revoked_at IS NOT NULL%revoked_by_user_id IS NOT NULL%revocation_reason IS NOT NULL%') THEN
   RAISE EXCEPTION 'Test number lifecycle shape constraint missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$
DECLARE result_table regclass;
BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='176_release_simulation_results.sql') THEN
  result_table:=to_regclass('public.caller_release_simulation_results');
  IF result_table IS NULL THEN RAISE EXCEPTION 'Release simulation results table missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid=result_table
    AND tgname='caller_release_simulation_result_guard' AND NOT tgisinternal AND tgenabled='O'
    AND tgtype=31 AND tgfoid=to_regprocedure('public.guard_release_simulation_result()')) THEN
   RAISE EXCEPTION 'Release simulation result guard missing or disabled'; END IF;
  IF (SELECT count(*) FROM pg_constraint WHERE conrelid=result_table AND contype='f' AND convalidated
    AND array_length(conkey,1)=2 AND confrelid IN ('public.caller_release_artifacts'::regclass,
      'public.simulation_runs'::regclass,'public.background_jobs'::regclass,'public.job_attempts'::regclass))<>4 THEN
   RAISE EXCEPTION 'Release simulation tenant composite foreign keys missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_index WHERE indexrelid=to_regclass('public.caller_release_simulation_job_run_unique')
    AND indrelid='public.background_jobs'::regclass AND indisunique AND indisvalid AND indisready
    AND pg_get_expr(indpred,indrelid)='(queue_name = ''caller-release-simulation''::text)') THEN
   RAISE EXCEPTION 'Release simulation dedicated job uniqueness missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_index WHERE indexrelid=to_regclass('public.caller_release_simulation_history_idx')
    AND indrelid=result_table AND indisvalid AND indisready) THEN
   RAISE EXCEPTION 'Release simulation history index missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='177_simulation_definition_binding.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid='public.caller_release_simulation_results'::regclass
   AND attname='definition_hash' AND NOT attisdropped AND atttypid='text'::regtype) THEN
   RAISE EXCEPTION 'Simulation definition hash column missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.caller_release_simulation_results'::regclass
   AND tgname='caller_simulation_definition_guard' AND NOT tgisinternal AND tgenabled='O' AND tgtype=7
   AND tgfoid=to_regprocedure('public.guard_simulation_definition_binding()')) THEN
   RAISE EXCEPTION 'Simulation definition guard missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ DECLARE table_name text; relation regclass; BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='178_transfer_configuration.sql') THEN
  FOREACH table_name IN ARRAY ARRAY['caller_transfer_team_policies','caller_transfer_destinations'] LOOP
   relation:=to_regclass('public.'||table_name);
   IF relation IS NULL THEN RAISE EXCEPTION 'Transfer configuration table missing: %',table_name; END IF;
   IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid=relation AND NOT tgisinternal AND tgenabled='O'
     AND tgtype=31 AND tgfoid=to_regprocedure('public.guard_caller_transfer_configuration()')) THEN
    RAISE EXCEPTION 'Transfer configuration guard missing: %',table_name; END IF;
   IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid=relation AND contype='f' AND convalidated AND array_length(conkey,1)=2) THEN
    RAISE EXCEPTION 'Transfer tenant scope foreign key missing: %',table_name; END IF;
  END LOOP;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='179_transfer_attempts.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid='public.caller_transfer_attempts'::regclass AND attname='capacity_held' AND attgenerated='s' AND NOT attisdropped) THEN
   RAISE EXCEPTION 'Transfer generated occupancy missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.caller_transfer_attempts'::regclass AND tgname='caller_transfer_attempt_guard' AND NOT tgisinternal AND tgenabled='O' AND tgtype=31 AND tgfoid=to_regprocedure('public.guard_caller_transfer_attempt()')) THEN
   RAISE EXCEPTION 'Transfer attempt guard missing'; END IF;
  IF (SELECT count(*) FROM pg_constraint WHERE conrelid='public.caller_transfer_attempts'::regclass AND contype='f' AND convalidated AND array_length(conkey,1)=2)<>4 THEN
   RAISE EXCEPTION 'Transfer attempt tenant foreign keys missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='181_transfer_event_receipts.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.caller_transfer_event_receipts'::regclass AND tgname='caller_transfer_receipt_guard' AND NOT tgisinternal AND tgenabled='O' AND tgtype=31 AND tgfoid=to_regprocedure('public.guard_caller_transfer_receipt()')) THEN
   RAISE EXCEPTION 'Transfer receipt immutability guard missing'; END IF;
  IF (SELECT count(*) FROM pg_constraint WHERE conrelid='public.caller_transfer_event_receipts'::regclass AND contype='f' AND convalidated AND array_length(conkey,1)=2)<>3 THEN
   RAISE EXCEPTION 'Transfer receipt scoped relationships missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='182_transfer_failure_actions.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.caller_transfer_failure_actions'::regclass AND tgname='caller_transfer_failure_action_guard' AND NOT tgisinternal AND tgenabled='O' AND tgtype=31 AND tgfoid=to_regprocedure('public.guard_transfer_failure_action()')) THEN
   RAISE EXCEPTION 'Transfer failure action evidence guard missing'; END IF;
  IF (SELECT count(*) FROM pg_constraint WHERE conrelid='public.caller_transfer_failure_actions'::regclass AND contype='f' AND convalidated AND array_length(conkey,1)=2)<>2 THEN
   RAISE EXCEPTION 'Transfer failure task tenant relationships missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='184_inbound_call_bindings.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.caller_inbound_bindings'::regclass AND tgname='caller_inbound_binding_guard' AND NOT tgisinternal AND tgenabled='O' AND tgtype=31 AND tgfoid=to_regprocedure('public.guard_inbound_call_binding()')) THEN
   RAISE EXCEPTION 'Inbound binding immutability guard missing'; END IF;
  IF (SELECT count(*) FROM pg_constraint WHERE conrelid='public.caller_inbound_bindings'::regclass AND contype='f' AND convalidated AND array_length(conkey,1)=2)<>6 THEN
   RAISE EXCEPTION 'Inbound tenant relationship guards missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='185_inbound_completion_receipts.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.caller_inbound_completions'::regclass AND tgname='caller_inbound_completion_guard' AND NOT tgisinternal AND tgenabled='O' AND tgtype=31 AND tgfoid=to_regprocedure('public.guard_inbound_completion()')) THEN
   RAISE EXCEPTION 'Inbound completion evidence guard missing'; END IF;
  IF (SELECT count(*) FROM pg_constraint WHERE conrelid='public.caller_inbound_completions'::regclass AND contype='f' AND convalidated AND array_length(conkey,1)=2)<>2 THEN
   RAISE EXCEPTION 'Inbound completion tenant relationships missing'; END IF;
  IF to_regclass('public.caller_inbound_completed_phone_idx') IS NULL OR to_regclass('public.caller_inbound_binding_phone_idx') IS NULL THEN
   RAISE EXCEPTION 'Inbound cooldown history indexes missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='186_inbound_topic_confirmations.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.caller_inbound_topic_confirmations'::regclass AND tgname='caller_inbound_topic_guard' AND NOT tgisinternal AND tgenabled='O' AND tgtype=31 AND tgfoid=to_regprocedure('public.guard_inbound_topic_confirmation()')) THEN
   RAISE EXCEPTION 'Inbound topic evidence guard missing'; END IF;
  IF (SELECT count(*) FROM pg_constraint WHERE conrelid='public.caller_inbound_topic_confirmations'::regclass AND contype='f' AND convalidated AND array_length(conkey,1)=2)<>2 THEN
   RAISE EXCEPTION 'Inbound topic tenant relationships missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='187_inbound_closed_campaign_tasks.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.caller_inbound_follow_up_actions'::regclass AND tgname='caller_inbound_follow_up_guard' AND NOT tgisinternal AND tgenabled='O' AND tgtype=31 AND tgfoid=to_regprocedure('public.guard_inbound_follow_up_action()')) THEN
   RAISE EXCEPTION 'Inbound follow-up evidence guard missing'; END IF;
  IF (SELECT count(*) FROM pg_constraint WHERE conrelid='public.caller_inbound_follow_up_actions'::regclass AND contype='f' AND convalidated AND array_length(conkey,1)=2)<>4 THEN
   RAISE EXCEPTION 'Inbound follow-up tenant relationships missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='188_inbound_greeting_pins.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.caller_inbound_greeting_pins'::regclass AND tgname='caller_inbound_greeting_pin_guard' AND NOT tgisinternal AND tgenabled='O' AND tgtype=31 AND tgfoid=to_regprocedure('public.guard_inbound_greeting_pin()')) THEN
   RAISE EXCEPTION 'Inbound greeting pin guard missing'; END IF;
  IF (SELECT count(*) FROM pg_constraint WHERE conrelid='public.caller_inbound_greeting_pins'::regclass AND contype='f' AND convalidated AND array_length(conkey,1)=2)<>3 THEN
   RAISE EXCEPTION 'Inbound greeting pin scoped relationships missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='190_inbound_admission_quota_guard.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.caller_inbound_greeting_pins'::regclass AND tgname='caller_inbound_greeting_admission_guard' AND NOT tgisinternal AND tgenabled='O' AND tgtype=7 AND tgfoid=to_regprocedure('public.guard_inbound_admission_quota()')) THEN
   RAISE EXCEPTION 'Inbound quota insert guard missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.quota_policies'::regclass AND tgname='caller_quota_configuration_lock' AND NOT tgisinternal AND tgenabled='O' AND tgtype=62 AND tgfoid=to_regprocedure('public.lock_caller_quota_configuration()')) THEN
   RAISE EXCEPTION 'Quota writer statement lock missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='191_inbound_quota_policy_contract.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.quota_policies'::regclass AND conname='caller_inbound_quota_policy_contract' AND convalidated) THEN
   RAISE EXCEPTION 'Inbound quota policy contract missing'; END IF;
  IF to_regclass('public.caller_inbound_quota_tenant_unique') IS NULL THEN
   RAISE EXCEPTION 'Inbound tenant quota uniqueness missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='192_call_capacity_policies.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.caller_capacity_policies'::regclass AND conname='caller_capacity_scope_contract' AND convalidated) THEN
   RAISE EXCEPTION 'Call capacity scope contract missing'; END IF;
  IF to_regclass('public.caller_capacity_platform_unique') IS NULL OR to_regclass('public.caller_capacity_tenant_unique') IS NULL OR to_regclass('public.caller_capacity_provider_unique') IS NULL THEN
   RAISE EXCEPTION 'Call capacity scope uniqueness missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.caller_capacity_policies'::regclass AND tgname='caller_capacity_write_lock' AND tgtype=62 AND tgenabled='O') THEN
   RAISE EXCEPTION 'Call capacity configuration serialization missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.caller_capacity_policies'::regclass AND tgname='caller_capacity_no_truncate' AND tgtype=34 AND tgenabled='O') THEN
   RAISE EXCEPTION 'Call capacity truncate guard missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.tenants'::regclass AND tgname='caller_tenant_capacity_provision' AND tgtype=5 AND tgenabled='O') THEN
   RAISE EXCEPTION 'Tenant capacity provisioning missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='193_call_capacity_claims.sql') THEN
  IF to_regclass('public.caller_capacity_claim_held_idx') IS NULL THEN
   RAISE EXCEPTION 'Held capacity claim index missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.caller_capacity_claims'::regclass AND tgname='caller_capacity_claim_write_lock' AND tgtype=62 AND tgenabled='O') THEN
   RAISE EXCEPTION 'Capacity claim serialization missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.caller_dispatch_intents'::regclass AND tgname='caller_dispatch_terminal_capacity' AND tgenabled='O') OR
     NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.caller_inbound_completions'::regclass AND tgname='caller_inbound_terminal_capacity' AND tgenabled='O') THEN
   RAISE EXCEPTION 'Terminal call capacity release missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='194_capacity_legacy_occupancy_indexes.sql') THEN
  IF to_regclass('public.caller_capacity_legacy_call_idx') IS NULL OR to_regclass('public.caller_capacity_legacy_session_idx') IS NULL THEN
   RAISE EXCEPTION 'Legacy capacity occupancy indexes missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='195_capacity_assignment_receipts.sql') THEN
  IF to_regclass('public.caller_capacity_assignment_policy_idx') IS NULL THEN
   RAISE EXCEPTION 'Capacity assignment history index missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.caller_capacity_assignment_receipts'::regclass AND tgname='caller_capacity_assignment_receipt_no_truncate' AND tgtype=34 AND tgenabled='O') THEN
   RAISE EXCEPTION 'Capacity assignment receipt truncate guard missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='196_test_dispatch_intents.sql') THEN
  IF to_regclass('public.caller_test_dispatch_open_phone') IS NULL OR to_regclass('public.caller_test_dispatch_acceptance_idx') IS NULL THEN
   RAISE EXCEPTION 'Test dispatch phone/quota indexes missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.caller_test_dispatch_intents'::regclass AND tgname='caller_test_dispatch_guard' AND tgtype=31 AND tgenabled='O') THEN
   RAISE EXCEPTION 'Test dispatch lifecycle guard missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='197_shared_outbound_phone_admission.sql') THEN
  IF (SELECT count(*) FROM pg_trigger WHERE tgrelid IN ('public.caller_dispatch_intents'::regclass,'public.caller_test_dispatch_intents'::regclass) AND tgname='caller_00_phone_admission_guard' AND tgtype=7 AND tgenabled='O') <> 2 THEN
   RAISE EXCEPTION 'Shared outbound phone admission guards missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='198_test_call_capacity_claims.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.caller_capacity_claims'::regclass AND conname='caller_capacity_claim_test_source_fk' AND contype='f') THEN
   RAISE EXCEPTION 'Test capacity source foreign key missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.caller_test_dispatch_intents'::regclass AND tgname='caller_test_dispatch_terminal_capacity' AND tgtype=17 AND tgenabled='O') THEN
   RAISE EXCEPTION 'Test terminal capacity release missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='199_test_dispatch_event_receipts.sql') THEN
  IF to_regclass('public.caller_test_dispatch_event_receipts_history') IS NULL THEN
   RAISE EXCEPTION 'Test provider event history index missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.caller_test_dispatch_event_receipts'::regclass AND tgname='caller_test_dispatch_event_receipt_no_truncate' AND tgtype=34 AND tgenabled='O') THEN
   RAISE EXCEPTION 'Test provider receipt truncate guard missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='200_guard_test_dispatch_release.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.billing_reservations'::regclass AND tgname='caller_test_dispatch_release_guard' AND tgdeferrable AND tginitdeferred AND tgenabled='O') THEN
   RAISE EXCEPTION 'Test dispatch deferred cost release guard missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='201_test_dispatch_cooldowns.sql') THEN
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.caller_test_dispatch_intents'::regclass AND tgname='caller_01_test_cooldown_guard' AND tgtype=7 AND tgenabled='O') THEN
   RAISE EXCEPTION 'Test dispatch cooldown guard missing'; END IF;
 END IF;
END $$;
SQL

psql_command "${URL}" <<'SQL'
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.schema_migrations WHERE version='202_test_number_challenge_bindings.sql') THEN
  IF to_regclass('public.caller_test_number_challenge_history') IS NULL THEN
   RAISE EXCEPTION 'Test ownership challenge history index missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.otp_challenges'::regclass AND tgname='caller_test_bound_otp_guard' AND tgenabled='O') THEN
   RAISE EXCEPTION 'Bound test OTP reset guard missing'; END IF;
 END IF;
END $$;
SQL
