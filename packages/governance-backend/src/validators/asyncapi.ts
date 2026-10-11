import { execFile } from 'child_process';
import { promisify } from 'util';
import { mkdtempSync, writeFileSync, rmSync } from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';
import { ValidationResult, ValidationIssue } from '../types';

const execFileAsync = promisify(execFile);

export async function validateAsyncAPI(
  content: string,
  logger: { warn: (msg: string) => void },
): Promise<ValidationResult> {
  const errors: ValidationIssue[] = [];
  const warnings: ValidationIssue[] = [];

  const tmpDir = mkdtempSync(join(tmpdir(), 'spire-asyncapi-'));
  try {
    const specPath = join(tmpDir, 'asyncapi.yaml');
    writeFileSync(specPath, content, 'utf-8');

    try {
      await execFileAsync('asyncapi', ['validate', specPath, '--no-tty'], { timeout: 30_000 });
    } catch (e: unknown) {
      const err = e as NodeJS.ErrnoException & { stderr?: string; killed?: boolean };
      if (err.stderr?.includes('error')) {
        errors.push({ field: 'asyncapi', message: err.stderr.trim() });
      } else if (!err.killed) {
        logger.warn(`asyncapi CLI unavailable: ${(err as Error).message}`);
        warnings.push({ field: 'asyncapi', message: 'asyncapi CLI not available — validation skipped', advisory: true });
      }
    }
  } finally {
    try { rmSync(tmpDir, { recursive: true }); } catch (_) { /* ignore */ }
  }

  return { errors, warnings };
}
