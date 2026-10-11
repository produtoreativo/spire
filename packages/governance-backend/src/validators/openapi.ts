import { execFile } from 'child_process';
import { promisify } from 'util';
import { mkdtempSync, writeFileSync, rmSync } from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';
import { ValidationResult, ValidationIssue } from '../types';

const execFileAsync = promisify(execFile);

interface SpectralIssue {
  severity: number;
  message: string;
  path?: string[];
  range?: { start?: { line?: number } };
}

interface OasdiffResult {
  breaking: boolean;
  changes: unknown[];
  unavailable?: boolean;
}

export async function validateOpenAPI(
  content: string,
  logger: { warn: (msg: string) => void },
): Promise<ValidationResult> {
  const errors: ValidationIssue[] = [];
  const warnings: ValidationIssue[] = [];

  const tmpDir = mkdtempSync(join(tmpdir(), 'spire-openapi-'));
  try {
    const specPath = join(tmpDir, 'openapi.yaml');
    writeFileSync(specPath, content, 'utf-8');

    try {
      const { stdout } = await execFileAsync(
        'spectral',
        ['lint', specPath, '--format', 'json', '--ruleset', 'oas', '--quiet'],
        { timeout: 30_000 },
      );
      classifySpectralIssues(parseSpectralOutput(stdout), errors, warnings);
    } catch (e: unknown) {
      const err = e as NodeJS.ErrnoException & { stdout?: string };
      if (err.stdout) {
        classifySpectralIssues(parseSpectralOutput(err.stdout), errors, warnings);
      } else if (err.code !== '1') {
        logger.warn(`spectral CLI unavailable: ${err.message}`);
        warnings.push({ field: 'openapi.spectral', message: 'Spectral CLI not available — lint skipped', advisory: true });
      }
    }
  } finally {
    try { rmSync(tmpDir, { recursive: true }); } catch (_) { /* ignore */ }
  }

  return { errors, warnings };
}

export async function runOasdiff(
  previousContent: string,
  currentContent: string,
  logger: { warn: (msg: string) => void },
): Promise<OasdiffResult> {
  const tmpDir = mkdtempSync(join(tmpdir(), 'spire-oasdiff-'));
  try {
    const prevPath = join(tmpDir, 'previous.yaml');
    const currPath = join(tmpDir, 'current.yaml');
    writeFileSync(prevPath, previousContent, 'utf-8');
    writeFileSync(currPath, currentContent, 'utf-8');

    try {
      const { stdout } = await execFileAsync(
        'oasdiff',
        ['breaking', prevPath, currPath, '--format', 'json'],
        { timeout: 30_000 },
      );
      const changes = parseJsonSafe<unknown[]>(stdout, []);
      return { breaking: changes.length > 0, changes };
    } catch (e: unknown) {
      const err = e as NodeJS.ErrnoException & { stdout?: string };
      if (err.code === '1' && err.stdout) {
        const changes = parseJsonSafe<unknown[]>(err.stdout, []);
        return { breaking: changes.length > 0, changes };
      }
      logger.warn(`oasdiff unavailable: ${(err as Error).message}`);
      return { breaking: false, changes: [], unavailable: true };
    }
  } finally {
    try { rmSync(tmpDir, { recursive: true }); } catch (_) { /* ignore */ }
  }
}

function parseSpectralOutput(stdout: string): SpectralIssue[] {
  return parseJsonSafe<SpectralIssue[]>(stdout, []);
}

function classifySpectralIssues(
  issues: SpectralIssue[],
  errors: ValidationIssue[],
  warnings: ValidationIssue[],
): void {
  for (const issue of issues) {
    const vi: ValidationIssue = {
      field: 'openapi.spectral',
      message: issue.message,
      path: issue.path?.join('.'),
      line: issue.range?.start?.line,
    };
    if (issue.severity === 0) {
      errors.push(vi);
    } else {
      warnings.push(vi);
    }
  }
}

function parseJsonSafe<T>(str: string, fallback: T): T {
  try {
    return JSON.parse(str) as T;
  } catch {
    return fallback;
  }
}
