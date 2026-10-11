import { validateCatalog } from '../../../src/validators/catalog';

describe('validateCatalog', () => {
  const VALID_CATALOG = {
    apiVersion: 'backstage.io/v1alpha1',
    kind: 'Component',
    metadata: {
      name: 'payments-api',
      title: 'Payments API',
      description: 'Manages payment lifecycle',
      annotations: {
        'backstage.io/techdocs-ref': 'dir:.',
      },
    },
    spec: {
      type: 'service',
      lifecycle: 'production',
      owner: 'group:payments-team',
    },
  };

  it('returns no errors for a valid catalog-info', () => {
    const result = validateCatalog(VALID_CATALOG);
    expect(result.errors).toHaveLength(0);
  });

  it('returns no warnings for a complete catalog-info', () => {
    const result = validateCatalog(VALID_CATALOG);
    expect(result.warnings).toHaveLength(0);
  });

  it('errors when metadata.name is missing', () => {
    const data = { ...VALID_CATALOG, metadata: { ...VALID_CATALOG.metadata, name: undefined } };
    const result = validateCatalog(data);
    expect(result.errors.some(e => e.field === 'catalog.metadata.name')).toBe(true);
  });

  it('errors when apiVersion top-level field is missing', () => {
    const { apiVersion: _omit, ...data } = VALID_CATALOG;
    const result = validateCatalog(data);
    expect(result.errors.some(e => e.field === 'catalog.apiVersion')).toBe(true);
  });

  it('errors when kind is missing', () => {
    const { kind: _omit, ...data } = VALID_CATALOG;
    const result = validateCatalog(data);
    expect(result.errors.some(e => e.field === 'catalog.kind')).toBe(true);
  });

  it('warns when apiVersion is not the expected value', () => {
    const data = { ...VALID_CATALOG, apiVersion: 'backstage.io/v1beta1' };
    const result = validateCatalog(data);
    expect(result.warnings.some(w => w.field === 'catalog.apiVersion')).toBe(true);
  });

  it('warns for unknown kind', () => {
    const data = { ...VALID_CATALOG, kind: 'Template' };
    const result = validateCatalog(data);
    expect(result.warnings.some(w => w.field === 'catalog.kind')).toBe(true);
  });

  it('warns when techdocs annotation is missing', () => {
    const data = {
      ...VALID_CATALOG,
      metadata: { ...VALID_CATALOG.metadata, annotations: {} },
    };
    const result = validateCatalog(data);
    expect(result.warnings.some(w => w.field === 'catalog.metadata.annotations')).toBe(true);
  });

  it('warns when spec block is missing entirely', () => {
    const { spec: _omit, ...data } = VALID_CATALOG;
    const result = validateCatalog(data);
    expect(result.warnings.some(w => w.field === 'catalog.spec')).toBe(true);
  });

  it('warns when spec.type is unknown', () => {
    const data = { ...VALID_CATALOG, spec: { ...VALID_CATALOG.spec, type: 'microservice' } };
    const result = validateCatalog(data);
    expect(result.warnings.some(w => w.field === 'catalog.spec.type')).toBe(true);
  });

  it('warns when spec.lifecycle is unknown', () => {
    const data = { ...VALID_CATALOG, spec: { ...VALID_CATALOG.spec, lifecycle: 'beta' } };
    const result = validateCatalog(data);
    expect(result.warnings.some(w => w.field === 'catalog.spec.lifecycle')).toBe(true);
  });

  it('warns when spec.owner is missing', () => {
    const { owner: _omit, ...specWithoutOwner } = VALID_CATALOG.spec;
    const data = { ...VALID_CATALOG, spec: specWithoutOwner };
    const result = validateCatalog(data);
    expect(result.warnings.some(w => w.field === 'catalog.spec.owner')).toBe(true);
  });

  it('warns but does not error when metadata.title is missing', () => {
    const data = { ...VALID_CATALOG, metadata: { ...VALID_CATALOG.metadata, title: undefined } };
    const result = validateCatalog(data);
    expect(result.errors.some(e => e.field === 'catalog.metadata.title')).toBe(false);
    expect(result.warnings.some(w => w.field === 'catalog.metadata.title')).toBe(true);
  });
});
