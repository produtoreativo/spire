import yaml from 'js-yaml';
import { runOasdiff } from '../validators/openapi';
import { ApicurioRegistration } from '../types';

type ArtifactType = 'OPENAPI' | 'ASYNCAPI';

const CONTENT_TYPES: Record<ArtifactType, string> = {
  OPENAPI: 'application/vnd.oai.openapi+yaml',
  ASYNCAPI: 'application/vnd.aai.asyncapi+yaml',
};

interface ApicurioOptions {
  url: string;
  logger: { warn: (msg: string) => void };
}

export async function registerInApicurio(
  artifact: { content: string; slug: string; type: ArtifactType },
  options: ApicurioOptions,
): Promise<ApicurioRegistration> {
  const { content, slug, type } = artifact;
  const { url, logger } = options;

  const groupId = 'spire-services';
  const artifactId = `${slug}-${type.toLowerCase()}`;
  const apiBase = `${url}/apis/registry/v3/groups/${groupId}/artifacts`;

  const submittedVersion = extractVersion(content, type);
  let previousContent: string | null = null;
  let previousVersion: string | null = null;

  try {
    const listResp = await fetch(`${apiBase}/${artifactId}/versions?limit=1&orderBy=createdOn&order=desc`);
    if (listResp.ok) {
      const listData = (await listResp.json()) as { versions?: Array<{ version: string }> };
      const latestVersion = listData.versions?.[0]?.version;
      if (latestVersion) {
        const contentResp = await fetch(`${apiBase}/${artifactId}/versions/${latestVersion}/content`);
        if (contentResp.ok) {
          previousContent = await contentResp.text();
          previousVersion = latestVersion;
        }
      }
    }
  } catch (e) {
    logger.warn(`Apicurio fetch failed: ${(e as Error).message}`);
  }

  if (previousContent && type === 'OPENAPI') {
    const diffResult = await runOasdiff(previousContent, content, logger);
    if (diffResult.breaking) {
      const prevMajor = Number((previousVersion ?? '0.0.0').split('.')[0]);
      const newMajor = Number(submittedVersion.split('.')[0]);
      if (newMajor <= prevMajor) {
        return { breaking: true, previousVersion, version: submittedVersion };
      }
    }
  }

  try {
    const createResp = await fetch(`${apiBase}?ifExists=UPDATE`, {
      method: 'POST',
      headers: {
        'Content-Type': CONTENT_TYPES[type],
        'X-Registry-ArtifactId': artifactId,
        'X-Registry-ArtifactType': type,
        'X-Registry-Version': submittedVersion,
      },
      body: content,
    });

    if (!createResp.ok) {
      const errBody = await createResp.text();
      logger.warn(`Apicurio registration failed (${createResp.status}): ${errBody}`);
    }
  } catch (e) {
    logger.warn(`Apicurio registration error: ${(e as Error).message}`);
  }

  return { breaking: false, previousVersion, version: submittedVersion };
}

function extractVersion(content: string, type: ArtifactType): string {
  try {
    const parsed = yaml.load(content) as Record<string, unknown>;
    const info = parsed?.info as Record<string, string> | undefined;
    if (type === 'OPENAPI' || type === 'ASYNCAPI') {
      return info?.version ?? '1.0.0';
    }
  } catch {
    /* fall through */
  }
  return '1.0.0';
}
