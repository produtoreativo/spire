import yaml from 'js-yaml';
import { KongSyncResult } from '../types';

interface KongOptions {
  adminUrl: string;
  logger: { warn: (msg: string) => void };
}

export async function syncKongRoute(
  spec: { slug: string; version: string; specContent: string },
  options: KongOptions,
): Promise<KongSyncResult> {
  const { slug, version, specContent } = spec;
  const { adminUrl, logger } = options;

  const [majorStr] = version.split('.');
  const major = Number(majorStr);
  const serviceName = `${slug}-v${major}`;
  const routeName = `${slug}-v${major}-route`;
  const routePath = `/v${major}/${slug}`;

  const upstreamUrl = resolveUpstreamUrl(specContent, slug, logger);

  try {
    const svcResp = await fetch(`${adminUrl}/services/${serviceName}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: serviceName,
        url: upstreamUrl,
        tags: ['spire', `service:${slug}`, `version:v${major}`, 'active'],
      }),
    });

    if (!svcResp.ok) {
      const body = await svcResp.text();
      logger.warn(`Kong service upsert failed (${svcResp.status}): ${body}`);
      return { created: false, major, error: `Kong service upsert failed: ${svcResp.status}` };
    }
  } catch (e) {
    logger.warn(`Kong Admin API unreachable: ${(e as Error).message}`);
    return { created: false, major, error: (e as Error).message };
  }

  const routeExists = await checkRouteExists(adminUrl, routeName);

  try {
    await fetch(`${adminUrl}/services/${serviceName}/routes/${routeName}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: routeName,
        paths: [routePath],
        strip_path: false,
        tags: ['spire', `service:${slug}`, `version:v${major}`, 'active'],
      }),
    });
  } catch (e) {
    logger.warn(`Kong route upsert failed: ${(e as Error).message}`);
  }

  return { created: !routeExists, major };
}

export async function deprecateKongRoute(
  target: { slug: string; major: number },
  options: KongOptions,
): Promise<{ ok: boolean; error?: string }> {
  const { slug, major } = target;
  const { adminUrl, logger } = options;
  const serviceName = `${slug}-v${major}`;

  try {
    const resp = await fetch(`${adminUrl}/services/${serviceName}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        tags: ['spire', `service:${slug}`, `version:v${major}`, 'deprecated'],
      }),
    });
    return { ok: resp.ok };
  } catch (e) {
    logger.warn(`Kong deprecation failed: ${(e as Error).message}`);
    return { ok: false, error: (e as Error).message };
  }
}

async function checkRouteExists(adminUrl: string, routeName: string): Promise<boolean> {
  try {
    const resp = await fetch(`${adminUrl}/routes/${routeName}`);
    return resp.ok;
  } catch {
    return false;
  }
}

function resolveUpstreamUrl(
  specContent: string,
  slug: string,
  logger: { warn: (msg: string) => void },
): string {
  try {
    const parsed = yaml.load(specContent) as Record<string, unknown>;
    const servers = parsed?.servers as Array<{ url: string }> | undefined;
    const url = servers?.[0]?.url;
    if (url && !url.includes('{')) return url;
  } catch {
    /* fall through */
  }
  logger.warn(`Kong sync: no static upstream in servers[0].url for '${slug}' — using placeholder`);
  return `http://${slug}:8080`;
}
