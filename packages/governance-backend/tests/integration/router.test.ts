import express from 'express';
import request from 'supertest';
import { createRouter } from '../../src/router';

// Minimal mock for Backstage service interfaces
const mockConfig = {
  getOptionalString: (key: string) => {
    const values: Record<string, string> = {
      'spireGovernance.apicurioUrl': 'http://apicurio:8080',
      'spireGovernance.kongAdminUrl': 'http://kong:8001',
      'spireGovernance.microcksUrl': 'http://microcks:8080',
      'spireGovernance.pipelineToken': 'test-token',
    };
    return values[key];
  },
  getString: (key: string) => {
    if (key === 'backend.baseUrl') return 'http://localhost:7007';
    throw new Error(`getString: unknown key ${key}`);
  },
};

const mockLogger = {
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
  debug: jest.fn(),
  child: jest.fn().mockReturnThis(),
};

function buildApp() {
  const app = express();
  const router = createRouter({ config: mockConfig as never, logger: mockLogger as never });
  app.use('/api/spire-governance', router);
  return app;
}

const VALID_CATALOG_YAML = `apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: test-service
  title: Test Service
  description: A test service
  annotations:
    backstage.io/techdocs-ref: dir:.
spec:
  type: service
  lifecycle: production
  owner: group:test-team
`;

const VALID_OBC_MD = `---
version: 1.0.0
status: active
---

## Business Outcome

Test business outcome.

## Observable Events

| Event | Trigger | Observable via |
|---|---|---|
| obc.validated | Spire validates | Spire catalog |

## Initial SLIs

| SLI | Description |
|---|---|
| Availability | % requests successful |

## Reliability Rules

- Availability: >= 99%

## Response Contract

| Scenario | Response |
|---|---|
| Valid | 200 OK |
`;

describe('GET /api/spire-governance/health', () => {
  it('returns 200 with plugin name', async () => {
    const app = buildApp();
    const res = await request(app).get('/api/spire-governance/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.plugin).toBe('@spire/backstage-plugin-governance-backend');
  });
});

describe('POST /api/spire-governance/submit', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // Mock fetch globally for external service calls
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 404,
      json: async () => ({}),
      text: async () => 'not found',
    }) as jest.Mock;
  });

  it('returns 400 when catalog_info is missing', async () => {
    const app = buildApp();
    const res = await request(app).post('/api/spire-governance/submit').field('catalog_url', 'http://example.com');
    expect(res.status).toBe(400);
    expect(res.body.error).toContain('catalog_info');
  });

  it('returns 422 when OBCs are missing', async () => {
    const app = buildApp();
    const res = await request(app)
      .post('/api/spire-governance/submit')
      .attach('catalog_info', Buffer.from(VALID_CATALOG_YAML), 'catalog-info.yaml');
    expect(res.status).toBe(422);
    expect(res.body.status).toBe('rejected');
    expect(res.body.errors.some((e: { field: string }) => e.field === 'obcs')).toBe(true);
  });

  it('returns 200 governed when catalog + valid OBC submitted', async () => {
    const app = buildApp();
    const res = await request(app)
      .post('/api/spire-governance/submit')
      .attach('catalog_info', Buffer.from(VALID_CATALOG_YAML), 'catalog-info.yaml')
      .attach('obcs', Buffer.from(VALID_OBC_MD), 'service-obc.md');

    expect(res.status).toBe(200);
    expect(res.body.status).toMatch(/^governed/);
    expect(res.body.service).toBe('test-service');
    expect(res.body.processed).toContain('catalog-info.yaml');
    expect(res.body.processed).toContain('1 OBC(s)');
  });

  it('returns 422 when catalog-info.yaml is invalid YAML', async () => {
    const app = buildApp();
    const res = await request(app)
      .post('/api/spire-governance/submit')
      .attach('catalog_info', Buffer.from(': invalid: yaml:'), 'catalog-info.yaml');
    expect(res.status).toBe(400);
  });

  it('returns report with duration_ms and timestamp', async () => {
    const app = buildApp();
    const res = await request(app)
      .post('/api/spire-governance/submit')
      .attach('catalog_info', Buffer.from(VALID_CATALOG_YAML), 'catalog-info.yaml')
      .attach('obcs', Buffer.from(VALID_OBC_MD), 'service-obc.md');

    expect(res.body.duration_ms).toBeGreaterThanOrEqual(0);
    expect(res.body.timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T/);
  });

  it('processes OBC errors correctly', async () => {
    const invalidObc = VALID_OBC_MD.replace('## Business Outcome', '## Renamed Section');
    const app = buildApp();
    const res = await request(app)
      .post('/api/spire-governance/submit')
      .attach('catalog_info', Buffer.from(VALID_CATALOG_YAML), 'catalog-info.yaml')
      .attach('obcs', Buffer.from(invalidObc), 'service-obc.md');

    expect(res.status).toBe(422);
    expect(res.body.status).toBe('rejected');
    expect(res.body.errors.some((e: { message: string }) => e.message.includes('Business Outcome'))).toBe(true);
  });
});
