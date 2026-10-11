import { ValidationResult, ValidationIssue, OBCFile } from '../types';

// Sections required for a well-formed OBC (blocking errors if missing)
const REQUIRED_SECTIONS = [
  'Business Outcome',
  'Observable Events',
  'Initial SLIs',
  'Reliability Rules',
] as const;

// Sections that are advisory — missing generates a warning, not an error
const ADVISORY_SECTIONS = ['Response Contract'] as const;

// Frontmatter fields introduced in EXP-008 schema — advisory for legacy OBCs
const ADVISORY_FRONTMATTER_FIELDS = ['version', 'status'] as const;
const VALID_STATUSES = ['draft', 'active', 'deprecated', 'superseded'] as const;
const SEMVER_RE = /^\d+\.\d+\.\d+$/;

export function validateOBCs(obcFiles: OBCFile[]): ValidationResult {
  const errors: ValidationIssue[] = [];
  const warnings: ValidationIssue[] = [];

  if (obcFiles.length === 0) {
    errors.push({ field: 'obcs', message: 'At least one OBC file is required (prodops/artifacts/obcs/*.md)' });
    return { errors, warnings };
  }

  for (const obc of obcFiles) {
    const result = validateSingleOBC(obc.name, obc.content);
    errors.push(...result.errors);
    warnings.push(...result.warnings);
  }

  return { errors, warnings };
}

export function validateSingleOBC(filename: string, content: string): ValidationResult {
  const errors: ValidationIssue[] = [];
  const warnings: ValidationIssue[] = [];

  const frontmatter = parseFrontmatter(content);

  for (const field of ADVISORY_FRONTMATTER_FIELDS) {
    if (!frontmatter[field]) {
      warnings.push({
        field: `obc.${filename}.${field}`,
        message: `OBC '${filename}': add frontmatter field '${field}' to adopt the EXP-008 schema`,
        advisory: true,
      });
    }
  }

  if (frontmatter.version) {
    if (!SEMVER_RE.test(frontmatter.version)) {
      errors.push({
        field: `obc.${filename}.version`,
        message: `OBC '${filename}': version '${frontmatter.version}' must follow semver (MAJOR.MINOR.PATCH)`,
      });
    } else {
      const [majorStr] = frontmatter.version.split('.');
      const major = Number(majorStr);
      if (major > 0 && !frontmatter.changelog) {
        warnings.push({
          field: `obc.${filename}.changelog`,
          message: `OBC '${filename}': MAJOR version (${frontmatter.version}) without changelog entry — document the breaking business intent`,
        });
      }
    }
  }

  if (frontmatter.status && !(VALID_STATUSES as readonly string[]).includes(frontmatter.status)) {
    warnings.push({
      field: `obc.${filename}.status`,
      message: `OBC '${filename}': status '${frontmatter.status}' is not standard. Use: ${VALID_STATUSES.join(', ')}`,
    });
  }

  const body = stripFrontmatter(content);
  const hasH2Section = (s: string) => new RegExp(`(?:^|\\n)## ${s}(?:\\s|$)`).test(body);
  const missingSections = REQUIRED_SECTIONS.filter(s => !hasH2Section(s));
  if (missingSections.length === REQUIRED_SECTIONS.length) {
    // No standard sections at all — legacy format OBC
    warnings.push({
      field: `obc.${filename}.format`,
      message: `OBC '${filename}': no standard sections found — migrate to the standard schema (Business Outcome, Observable Events, Initial SLIs, Reliability Rules)`,
      advisory: true,
    });
  } else {
    for (const section of missingSections) {
      errors.push({
        field: `obc.${filename}.section`,
        message: `OBC '${filename}': required section '## ${section}' is missing`,
      });
    }
  }

  for (const section of ADVISORY_SECTIONS) {
    if (!hasH2Section(section)) {
      warnings.push({
        field: `obc.${filename}.section`,
        message: `OBC '${filename}': section '## ${section}' is recommended — document the failure mode and response expectations`,
        advisory: true,
      });
    }
  }

  return { errors, warnings };
}

type Frontmatter = Record<string, string>;

function parseFrontmatter(content: string): Frontmatter {
  const match = content.match(/^---\n([\s\S]*?)\n---/);
  if (!match) return {};

  const result: Frontmatter = {};
  for (const line of match[1].split('\n')) {
    const colonIdx = line.indexOf(':');
    if (colonIdx < 0) continue;
    const key = line.slice(0, colonIdx).trim();
    const value = line.slice(colonIdx + 1).trim();
    if (key) result[key] = value;
  }
  return result;
}

function stripFrontmatter(content: string): string {
  return content.replace(/^---\n[\s\S]*?\n---\n?/, '');
}
