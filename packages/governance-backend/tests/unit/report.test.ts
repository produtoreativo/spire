import { buildReport, deriveStatus } from '../../src/report';
import { ValidationIssue } from '../../src/types';

const BASE_INPUT = {
  service: 'payments-api',
  processed: ['catalog-info.yaml', '2 OBC(s)'],
  errors: [] as ValidationIssue[],
  warnings: [] as ValidationIssue[],
  openapiVersion: null,
  asyncapiVersion: null,
  kongRouteCreated: false,
  catalogRegistered: false,
  durationMs: 123,
};

describe('buildReport', () => {
  it('builds a governed report when no errors or warnings', () => {
    const report = buildReport({ ...BASE_INPUT, status: 'governed' });
    expect(report.status).toBe('governed');
    expect(report.service).toBe('payments-api');
    expect(report.summary).toContain('all checks passed');
    expect(report.duration_ms).toBe(123);
    expect(report.timestamp).toBeTruthy();
    expect(report.processed).toHaveLength(2);
  });

  it('builds a rejected report with errors', () => {
    const errors: ValidationIssue[] = [{ field: 'catalog.metadata.name', message: 'Required field missing' }];
    const report = buildReport({ ...BASE_INPUT, status: 'rejected', errors });
    expect(report.status).toBe('rejected');
    expect(report.summary).toContain('1 error(s)');
    expect(report.errors).toHaveLength(1);
  });

  it('builds a governed_with_warnings report', () => {
    const warnings: ValidationIssue[] = [
      { field: 'catalog.spec.type', message: 'Unknown type' },
      { field: 'catalog.spec.owner', message: 'Owner missing' },
    ];
    const report = buildReport({ ...BASE_INPUT, status: 'governed_with_warnings', warnings });
    expect(report.status).toBe('governed_with_warnings');
    expect(report.summary).toContain('2 warning(s)');
    expect(report.warnings).toHaveLength(2);
  });

  it('includes version information when present', () => {
    const report = buildReport({ ...BASE_INPUT, status: 'governed', openapiVersion: '2.1.0', asyncapiVersion: '1.0.0' });
    expect(report.versions.openapi).toBe('2.1.0');
    expect(report.versions.asyncapi).toBe('1.0.0');
  });

  it('has null versions when not provided', () => {
    const report = buildReport({ ...BASE_INPUT, status: 'governed' });
    expect(report.versions.openapi).toBeNull();
    expect(report.versions.asyncapi).toBeNull();
  });

  it('reflects kong_route_created and catalog_registered flags', () => {
    const report = buildReport({ ...BASE_INPUT, status: 'governed', kongRouteCreated: true, catalogRegistered: true });
    expect(report.kong_route_created).toBe(true);
    expect(report.catalog_registered).toBe(true);
  });
});

describe('deriveStatus', () => {
  it('returns rejected when errors present', () => {
    const errors: ValidationIssue[] = [{ field: 'x', message: 'error' }];
    expect(deriveStatus(errors, [])).toBe('rejected');
  });

  it('returns governed when no errors or warnings', () => {
    expect(deriveStatus([], [])).toBe('governed');
  });

  it('returns governed_with_warnings when there are actionable warnings', () => {
    const warnings: ValidationIssue[] = [{ field: 'x', message: 'warn' }];
    expect(deriveStatus([], warnings)).toBe('governed_with_warnings');
  });

  it('returns governed when all warnings are advisory', () => {
    const warnings: ValidationIssue[] = [{ field: 'x', message: 'advisory warning', advisory: true }];
    expect(deriveStatus([], warnings)).toBe('governed');
  });

  it('prioritizes errors over warnings', () => {
    const errors: ValidationIssue[] = [{ field: 'x', message: 'error' }];
    const warnings: ValidationIssue[] = [{ field: 'y', message: 'warn' }];
    expect(deriveStatus(errors, warnings)).toBe('rejected');
  });
});
