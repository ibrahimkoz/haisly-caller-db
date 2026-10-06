DROP INDEX IF EXISTS public.dependency_scan_findings_status_severity_detected_at_idx;

DROP TABLE IF EXISTS public.dependency_scan_findings;

DROP INDEX IF EXISTS public.dependency_scan_runs_status_created_at_idx;

DROP TABLE IF EXISTS public.dependency_scan_runs;

DROP INDEX IF EXISTS public.sbom_snapshots_source_generated_at_idx;

DROP TABLE IF EXISTS public.sbom_snapshots;

DROP INDEX IF EXISTS public.vulnerability_findings_status_severity_discovered_at_idx;

DROP TABLE IF EXISTS public.vulnerability_findings;

DROP INDEX IF EXISTS public.vulnerability_scan_runs_status_created_at_idx;

DROP TABLE IF EXISTS public.vulnerability_scan_runs;

DROP INDEX IF EXISTS public.access_review_items_review_decision_idx;

DROP TABLE IF EXISTS public.access_review_items;

DROP INDEX IF EXISTS public.access_reviews_tenant_status_updated_at_idx;
DROP INDEX IF EXISTS public.access_reviews_scope_status_due_at_idx;

DROP TABLE IF EXISTS public.access_reviews;

DROP INDEX IF EXISTS public.security_incidents_tenant_status_detected_at_idx;
DROP INDEX IF EXISTS public.security_incidents_status_severity_detected_at_idx;

DROP TABLE IF EXISTS public.security_incidents;

DROP INDEX IF EXISTS public.security_events_tenant_occurred_at_idx;
DROP INDEX IF EXISTS public.security_events_status_severity_occurred_at_idx;

DROP TABLE IF EXISTS public.security_events;

DROP INDEX IF EXISTS public.platform_admin_user_roles_role_status_idx;

DROP TABLE IF EXISTS public.platform_admin_user_roles;
DROP TABLE IF EXISTS public.platform_admin_roles;

DROP INDEX IF EXISTS public.platform_admin_users_status_updated_at_idx;

DROP TABLE IF EXISTS public.platform_admin_users;
