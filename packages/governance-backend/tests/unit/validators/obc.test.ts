import { validateOBCs, validateSingleOBC } from '../../../src/validators/obc';

const VALID_OBC = `---
version: 1.0.0
status: active
changelog: |
  1.0.0: Initial OBC
---

# OBC: Payments API

## Business Outcome

Clientes completam o checkout com taxa de sucesso > 99.5%.

## Observable Events

| Event | Trigger | Observable via |
|---|---|---|
| obc.validated | Spire valida este OBC | Spire catalog |

## Initial SLIs

| SLI | Description |
|---|---|
| Availability | % requests successful |

## Reliability Rules

- Availability: >= 99.5%

## Response Contract

| Scenario | Response |
|---|---|
| Valid request | 200 OK |
`;

describe('validateSingleOBC', () => {
  it('returns no errors for a valid OBC', () => {
    const result = validateSingleOBC('service-obc.md', VALID_OBC);
    expect(result.errors).toHaveLength(0);
  });

  it('warns (advisory) when version frontmatter is missing', () => {
    const content = VALID_OBC.replace('version: 1.0.0\n', '');
    const result = validateSingleOBC('service-obc.md', content);
    expect(result.errors.some(e => e.field.includes('version'))).toBe(false);
    expect(result.warnings.some(w => w.field.includes('version') && w.advisory)).toBe(true);
  });

  it('errors when version is not semver', () => {
    const content = VALID_OBC.replace('version: 1.0.0', 'version: 1.0');
    const result = validateSingleOBC('service-obc.md', content);
    expect(result.errors.some(e => e.message.includes('semver'))).toBe(true);
  });

  it('warns (advisory) when status frontmatter is missing', () => {
    const content = VALID_OBC.replace('status: active\n', '');
    const result = validateSingleOBC('service-obc.md', content);
    expect(result.errors.some(e => e.field.includes('status'))).toBe(false);
    expect(result.warnings.some(w => w.field.includes('status') && w.advisory)).toBe(true);
  });

  it('warns for unknown status', () => {
    const content = VALID_OBC.replace('status: active', 'status: invalid');
    const result = validateSingleOBC('service-obc.md', content);
    expect(result.warnings.some(w => w.field.includes('status'))).toBe(true);
  });

  it.each([
    'Business Outcome',
    'Observable Events',
    'Initial SLIs',
    'Reliability Rules',
  ])('errors when required section "%s" is missing', (section) => {
    const content = VALID_OBC.replace(`## ${section}`, '## REMOVED');
    const result = validateSingleOBC('service-obc.md', content);
    expect(result.errors.some(e => e.message.includes(section))).toBe(true);
  });

  it('warns (advisory) when Response Contract section is missing', () => {
    const content = VALID_OBC.replace('## Response Contract', '## REMOVED');
    const result = validateSingleOBC('service-obc.md', content);
    expect(result.errors.some(e => e.message.includes('Response Contract'))).toBe(false);
    expect(result.warnings.some(w => w.message.includes('Response Contract') && w.advisory)).toBe(true);
  });

  it('warns (advisory) when no standard sections exist — legacy format', () => {
    const legacy = '# OBC — Legacy\n\n## 1. Observable Behavior Contract\n\nSome content here.\n';
    const result = validateSingleOBC('legacy.md', legacy);
    expect(result.errors.some(e => e.field.includes('section'))).toBe(false);
    expect(result.warnings.some(w => w.field.includes('format') && w.advisory)).toBe(true);
  });

  it('warns when MAJOR version has no changelog', () => {
    const content = VALID_OBC.replace('version: 1.0.0', 'version: 2.0.0').replace('changelog: |\n  1.0.0: Initial OBC\n', '');
    const result = validateSingleOBC('service-obc.md', content);
    expect(result.warnings.some(w => w.field.includes('changelog'))).toBe(true);
  });

  it('does not warn about changelog for version 0.x', () => {
    const content = VALID_OBC.replace('version: 1.0.0', 'version: 0.1.0').replace('changelog: |\n  1.0.0: Initial OBC\n', '');
    const result = validateSingleOBC('service-obc.md', content);
    expect(result.warnings.some(w => w.field.includes('changelog'))).toBe(false);
  });
});

describe('validateOBCs', () => {
  it('errors when no OBC files provided', () => {
    const result = validateOBCs([]);
    expect(result.errors.length).toBeGreaterThan(0);
    expect(result.errors[0].field).toBe('obcs');
  });

  it('validates multiple OBC files', () => {
    const files = [
      { name: 'first.md', content: VALID_OBC },
      { name: 'second.md', content: VALID_OBC.replace('version: 1.0.0', 'version: bad') },
    ];
    const result = validateOBCs(files);
    expect(result.errors.some(e => e.field.includes('second.md'))).toBe(true);
    expect(result.errors.some(e => e.field.includes('first.md'))).toBe(false);
  });
});
