import express, { Router } from 'express';
import multer from 'multer';
import yaml from 'js-yaml';
import { RootConfigService, RootLoggerService } from '@backstage/backend-plugin-api';

import { detectArtifacts, slugify } from './detect';
import { validateCatalog } from './validators/catalog';
import { validateOBCs } from './validators/obc';
import { validateOpenAPI } from './validators/openapi';
import { validateAsyncAPI } from './validators/asyncapi';
import { validateSLO } from './validators/slo';
import { registerInApicurio } from './registry/apicurio';
import { syncKongRoute } from './registry/kong';
import { updateMicrocks } from './registry/microcks';
import { buildReport, deriveStatus } from './report';
import { ValidationIssue, SubmitBody } from './types';

interface RouterOptions {
  config: RootConfigService;
  logger: RootLoggerService;
}

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 4 * 1024 * 1024 },
});

export function createRouter({ config, logger }: RouterOptions): Router {
  const router = Router();

  const apicurioUrl = config.getOptionalString('spireGovernance.apicurioUrl') ?? 'http://apicurio:8080';
  const kongAdminUrl = config.getOptionalString('spireGovernance.kongAdminUrl') ?? 'http://kong:8001';
  const microcksUrl = config.getOptionalString('spireGovernance.microcksUrl') ?? 'http://microcks:8080';
  const pipelineToken = config.getOptionalString('spireGovernance.pipelineToken') ?? '';
  const backstageInternalUrl = 'http://localhost:7007';

  // ── POST /submit ─────────────────────────────────────────────────────────────
  router.post(
    '/submit',
    upload.fields([
      { name: 'catalog_info', maxCount: 1 },
      { name: 'openapi', maxCount: 1 },
      { name: 'asyncapi', maxCount: 1 },
      { name: 'slo', maxCount: 1 },
      { name: 'obcs', maxCount: 50 },
    ]),
    async (req, res) => {
      const startTime = Date.now();
      const errors: ValidationIssue[] = [];
      const warnings: ValidationIssue[] = [];
      const processed: string[] = [];

      try {
        const files = (req.files ?? {}) as { [fieldname: string]: Express.Multer.File[] };
        const body = req.body as SubmitBody;
        const { catalog_url } = body;

        const artifacts = detectArtifacts(files);

        // ── 1. catalog-info.yaml (required) ────────────────────────────────────
        if (!artifacts.hasCatalog) {
          res.status(400).json({ error: 'catalog_info file is required' });
          return;
        }

        const catalogContent = files.catalog_info[0].buffer.toString('utf-8');
        let catalogData: Record<string, unknown>;
        try {
          const docs = yaml.loadAll(catalogContent) as Record<string, unknown>[];
          catalogData = docs[0];
        } catch (e) {
          res.status(400).json({ error: `catalog-info.yaml parse error: ${(e as Error).message}` });
          return;
        }

        const catalogResult = validateCatalog(catalogData);
        errors.push(...catalogResult.errors);
        warnings.push(...catalogResult.warnings);
        processed.push('catalog-info.yaml');

        const slug = slugify((catalogData.metadata as Record<string, string>)?.name ?? 'unknown');

        // ── 2. OBCs (required) ──────────────────────────────────────────────────
        if (!artifacts.hasObcs) {
          errors.push({ field: 'obcs', message: 'At least one OBC file is required (prodops/artifacts/obcs/*.md)' });
        } else {
          const obcFiles = files.obcs.map(f => ({ name: f.originalname, content: f.buffer.toString('utf-8') }));
          const obcResult = validateOBCs(obcFiles);
          errors.push(...obcResult.errors);
          warnings.push(...obcResult.warnings);
          processed.push(`${files.obcs.length} OBC(s)`);
        }

        // ── 3. OpenAPI (optional) ───────────────────────────────────────────────
        let openapiVersion: string | null = null;
        let kongRouteCreated = false;

        if (artifacts.hasOpenAPI) {
          const openapiContent = files.openapi[0].buffer.toString('utf-8');

          const spectralResult = await validateOpenAPI(openapiContent, logger);
          errors.push(...spectralResult.errors);
          warnings.push(...spectralResult.warnings);
          processed.push('openapi.yaml (Spectral)');

          if (spectralResult.errors.length === 0) {
            const apicurioResult = await registerInApicurio(
              { content: openapiContent, slug, type: 'OPENAPI' },
              { url: apicurioUrl, logger },
            );

            if (apicurioResult.breaking) {
              errors.push({
                field: 'openapi.version',
                message: `Breaking change detected without MAJOR version bump. Current: ${apicurioResult.previousVersion}, submitted: ${apicurioResult.version}. Bump MAJOR to proceed (e.g. 1.x → 2.0.0).`,
              });
            } else {
              openapiVersion = apicurioResult.version;
              processed.push(`openapi → Apicurio v${openapiVersion}`);

              const kongResult = await syncKongRoute(
                { slug, version: openapiVersion, specContent: openapiContent },
                { adminUrl: kongAdminUrl, logger },
              );

              if (kongResult.error) {
                warnings.push({ field: 'kong', message: `Kong sync: ${kongResult.error}`, advisory: true });
              } else {
                kongRouteCreated = kongResult.created;
                processed.push(`Kong /v${kongResult.major}/${slug} ${kongResult.created ? 'created' : 'updated'}`);
              }
            }
          }
        }

        // ── 4. AsyncAPI (optional) ──────────────────────────────────────────────
        let asyncapiVersion: string | null = null;

        if (artifacts.hasAsyncAPI) {
          const asyncapiContent = files.asyncapi[0].buffer.toString('utf-8');

          const asyncResult = await validateAsyncAPI(asyncapiContent, logger);
          errors.push(...asyncResult.errors);
          warnings.push(...asyncResult.warnings);
          processed.push('asyncapi.yaml');

          if (asyncResult.errors.length === 0) {
            const apicurioResult = await registerInApicurio(
              { content: asyncapiContent, slug, type: 'ASYNCAPI' },
              { url: apicurioUrl, logger },
            );
            asyncapiVersion = apicurioResult.version;
            processed.push(`asyncapi → Apicurio v${asyncapiVersion}`);

            const microcksResult = await updateMicrocks(
              { slug, content: asyncapiContent },
              { url: microcksUrl, logger },
            );
            if (microcksResult.updated) processed.push('Microcks mocks updated');
          }
        }

        // ── 5. SLO (optional, advisory) ─────────────────────────────────────────
        if (artifacts.hasSLO) {
          const sloContent = files.slo[0].buffer.toString('utf-8');
          const sloResult = await validateSLO(sloContent, logger);
          for (const issue of sloResult.issues) {
            warnings.push({ field: 'slo', message: issue, advisory: true });
          }
          processed.push('slo.yaml (advisory)');
        }

        // ── 6. Catalog registration ─────────────────────────────────────────────
        let catalogRegistered = false;
        if (errors.length === 0 && catalog_url) {
          catalogRegistered = await registerCatalogLocation(
            catalog_url,
            backstageInternalUrl,
            pipelineToken,
            logger,
            warnings,
          );
        }

        // ── 7. Report ───────────────────────────────────────────────────────────
        const status = deriveStatus(errors, warnings);
        const report = buildReport({
          status,
          service: (catalogData.metadata as Record<string, string>)?.name ?? slug,
          processed,
          errors,
          warnings,
          openapiVersion,
          asyncapiVersion,
          kongRouteCreated,
          catalogRegistered,
          durationMs: Date.now() - startTime,
        });

        logger.info(`Governance [${status}] for '${slug}' in ${Date.now() - startTime}ms`);
        res.status(errors.length > 0 ? 422 : 200).json(report);
      } catch (err) {
        logger.error(`Governance submission error: ${(err as Error).message}`);
        res.status(500).json({ error: 'Internal governance error', details: (err as Error).message });
      }
    },
  );

  // ── GET /health ─────────────────────────────────────────────────────────────
  router.get('/health', (_req, res) => {
    res.json({ status: 'ok', plugin: '@spire/backstage-plugin-governance-backend' });
  });

  // ── GET /services ───────────────────────────────────────────────────────────
  router.get('/services', async (_req, res) => {
    try {
      const resp = await fetch(`${apicurioUrl}/apis/registry/v3/search/artifacts?limit=100`);
      if (!resp.ok) {
        res.status(502).json({ error: 'Apicurio returned non-OK', status: resp.status });
        return;
      }
      res.json(await resp.json());
    } catch (e) {
      res.status(502).json({ error: 'Apicurio unavailable', details: (e as Error).message });
    }
  });

  return router;
}

async function registerCatalogLocation(
  catalogUrl: string,
  backstageInternalUrl: string,
  pipelineToken: string,
  logger: { warn: (msg: string) => void },
  warnings: ValidationIssue[],
): Promise<boolean> {
  try {
    const resp = await fetch(`${backstageInternalUrl}/api/catalog/locations`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${pipelineToken}`,
      },
      body: JSON.stringify({ type: 'url', target: catalogUrl }),
    });

    if (resp.ok || resp.status === 409) return true;

    warnings.push({ field: 'catalog', message: `Catalog registration returned HTTP ${resp.status}` });
    return false;
  } catch (e) {
    warnings.push({ field: 'catalog', message: `Catalog registration failed: ${(e as Error).message}`, advisory: true });
    return false;
  }
}

// Re-export express for external use (e.g. tests)
export { express };
