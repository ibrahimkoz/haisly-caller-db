INSERT INTO public.pricing_plans (
  code,
  name,
  description,
  status,
  currency_code,
  metadata
)
VALUES
  (
    'trial',
    'Trial',
    'Time-limited onboarding plan for evaluation.',
    'active',
    'USD',
    '{"is_default": false, "tier": 0}'::jsonb
  ),
  (
    'basic',
    'Basic',
    'Starter production plan for small teams.',
    'active',
    'USD',
    '{"is_default": true, "tier": 1}'::jsonb
  ),
  (
    'pro',
    'Pro',
    'Growth plan with advanced usage allowances.',
    'active',
    'USD',
    '{"is_default": false, "tier": 2}'::jsonb
  ),
  (
    'enterprise',
    'Enterprise',
    'Custom enterprise contract and governance controls.',
    'active',
    'USD',
    '{"is_default": false, "tier": 3}'::jsonb
  )
ON CONFLICT ON CONSTRAINT pricing_plans_code_unique DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  status = EXCLUDED.status,
  currency_code = EXCLUDED.currency_code,
  metadata = EXCLUDED.metadata,
  updated_at = now();
