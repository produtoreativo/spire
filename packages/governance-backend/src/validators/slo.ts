import { execFile } from 'child_process';
import { promisify } from 'util';
import { mkdtempSync, writeFileSync, rmSync } from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';

const execFileAsync = promisify(execFile);

export interface SLOResult {
  issues: string[];
}

export async function validateSLO(
  content: string,
  logger: { warn: (msg: string) => void },
): Promise<SLOResult> {
  const issues: string[] = [];

  const tmpDir = mkdtempSync(join(tmpdir(), 'spire-slo-'));
  try {
    const sloPath = join(tmpDir, 'slo.yaml');
    writeFileSync(sloPath, content, 'utf-8');

    try {
      await execFileAsync('oslo', ['validate', '-f', sloPath], { timeout: 15_000 });
    } catch (e: unknown) {
      const err = e as NodeJS.ErrnoException & { stdout?: string; stderr?: string };
      if (err.stdout) issues.push(err.stdout.trim());
      if (err.stderr) issues.push(err.stderr.trim());
      if (!err.stdout && !err.stderr) {
        logger.warn(`oslo CLI unavailable: ${(err as Error).message}`);
        issues.push('oslo CLI not available — SLO validation skipped (advisory)');
      }
    }
  } finally {
    try { rmSync(tmpDir, { recursive: true }); } catch (_) { /* ignore */ }
  }

  return { issues };
}
