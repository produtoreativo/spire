import { MicrocksResult } from '../types';

interface MicrocksOptions {
  url: string;
  logger: { warn: (msg: string) => void };
}

export async function updateMicrocks(
  spec: { slug: string; content: string },
  options: MicrocksOptions,
): Promise<MicrocksResult> {
  const { slug, content } = spec;
  const { url, logger } = options;

  try {
    const formData = new FormData();
    const blob = new Blob([content], { type: 'application/vnd.aai.asyncapi+yaml' });
    formData.append('file', blob, `${slug}-asyncapi.yaml`);
    formData.append('mainArtifact', 'true');

    const resp = await fetch(`${url}/api/artifact/upload`, {
      method: 'POST',
      body: formData,
    });

    if (!resp.ok) {
      const body = await resp.text();
      logger.warn(`Microcks upload failed (${resp.status}): ${body}`);
      return { updated: false };
    }

    return { updated: true };
  } catch (e) {
    logger.warn(`Microcks unreachable: ${(e as Error).message}`);
    return { updated: false, error: (e as Error).message };
  }
}
