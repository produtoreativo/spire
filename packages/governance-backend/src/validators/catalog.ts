import { ValidationResult, ValidationIssue } from '../types';

const REQUIRED_TOP_FIELDS = ['apiVersion', 'kind', 'metadata'] as const;
const REQUIRED_METADATA = ['name', 'title', 'description'] as const;
const REQUIRED_ANNOTATIONS = ['backstage.io/techdocs-ref'] as const;
const ALLOWED_KINDS = ['Component', 'API', 'Resource', 'System'] as const;
const ALLOWED_TYPES = ['service', 'library', 'website', 'batch', 'worker'] as const;
const ALLOWED_LIFECYCLES = ['experimental', 'production', 'deprecated'] as const;

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function validateCatalog(data: Record<string, any>): ValidationResult {
  const errors: ValidationIssue[] = [];
  const warnings: ValidationIssue[] = [];

  for (const field of REQUIRED_TOP_FIELDS) {
    if (!data[field]) {
      errors.push({ field: `catalog.${field}`, message: `Required field '${field}' is missing` });
    }
  }

  if (data.apiVersion !== 'backstage.io/v1alpha1') {
    warnings.push({
      field: 'catalog.apiVersion',
      message: `Expected 'backstage.io/v1alpha1', got '${data.apiVersion}'`,
    });
  }

  if (data.kind && !(ALLOWED_KINDS as readonly string[]).includes(data.kind)) {
    warnings.push({
      field: 'catalog.kind',
      message: `Unexpected kind '${data.kind}'. Allowed: ${ALLOWED_KINDS.join(', ')}`,
    });
  }

  if (data.metadata) {
    for (const field of REQUIRED_METADATA) {
      if (!data.metadata[field]) {
        const issue: ValidationIssue = {
          field: `catalog.metadata.${field}`,
          message: `metadata.${field} is ${field === 'name' ? 'required' : 'recommended'}`,
        };
        if (field === 'name') {
          errors.push(issue);
        } else {
          warnings.push(issue);
        }
      }
    }

    const annotations: Record<string, string> = data.metadata.annotations ?? {};
    for (const ann of REQUIRED_ANNOTATIONS) {
      if (!annotations[ann]) {
        warnings.push({
          field: 'catalog.metadata.annotations',
          message: `Recommended annotation '${ann}' is missing (required for TechDocs)`,
        });
      }
    }
  }

  if (data.spec) {
    if (!data.spec.type) {
      warnings.push({ field: 'catalog.spec.type', message: `spec.type is recommended. Allowed: ${ALLOWED_TYPES.join(', ')}` });
    } else if (!(ALLOWED_TYPES as readonly string[]).includes(data.spec.type)) {
      warnings.push({
        field: 'catalog.spec.type',
        message: `Unknown spec.type '${data.spec.type}'. Suggested: ${ALLOWED_TYPES.join(', ')}`,
      });
    }

    if (!data.spec.lifecycle) {
      warnings.push({ field: 'catalog.spec.lifecycle', message: `spec.lifecycle is recommended. Allowed: ${ALLOWED_LIFECYCLES.join(', ')}` });
    } else if (!(ALLOWED_LIFECYCLES as readonly string[]).includes(data.spec.lifecycle)) {
      warnings.push({
        field: 'catalog.spec.lifecycle',
        message: `Unknown lifecycle '${data.spec.lifecycle}'. Allowed: ${ALLOWED_LIFECYCLES.join(', ')}`,
      });
    }

    if (!data.spec.owner) {
      warnings.push({ field: 'catalog.spec.owner', message: "spec.owner is recommended (e.g. 'group:my-team')" });
    }
  } else {
    warnings.push({ field: 'catalog.spec', message: 'spec block is missing — type, lifecycle and owner are recommended' });
  }

  return { errors, warnings };
}
