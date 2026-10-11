import { GovernanceReport, GovernanceStatus, ValidationIssue } from './types';

interface ReportInput {
  status: GovernanceStatus;
  service: string;
  processed: string[];
  errors: ValidationIssue[];
  warnings: ValidationIssue[];
  openapiVersion: string | null;
  asyncapiVersion: string | null;
  kongRouteCreated: boolean;
  catalogRegistered: boolean;
  durationMs: number;
}

export function buildReport(input: ReportInput): GovernanceReport {
  return {
    status: input.status,
    service: input.service,
    timestamp: new Date().toISOString(),
    duration_ms: input.durationMs,
    processed: input.processed,
    versions: {
      openapi: input.openapiVersion,
      asyncapi: input.asyncapiVersion,
    },
    kong_route_created: input.kongRouteCreated,
    catalog_registered: input.catalogRegistered,
    errors: input.errors,
    warnings: input.warnings,
    summary: buildSummary(input.status, input.errors.length, input.warnings.length),
  };
}

function buildSummary(status: GovernanceStatus, errorCount: number, warningCount: number): string {
  switch (status) {
    case 'governed':
      return '✓ Service governed — all checks passed.';
    case 'governed_with_warnings':
      return `⚠ Service governed with ${warningCount} warning(s) — review recommended.`;
    case 'rejected':
      return `✗ Submission rejected — ${errorCount} error(s) must be resolved before registration.`;
  }
}

export function deriveStatus(errors: ValidationIssue[], warnings: ValidationIssue[]): GovernanceStatus {
  if (errors.length > 0) return 'rejected';
  const actionableWarnings = warnings.filter(w => !w.advisory);
  if (actionableWarnings.length > 0) return 'governed_with_warnings';
  return 'governed';
}
