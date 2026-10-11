export interface ValidationIssue {
  field: string;
  message: string;
  line?: number;
  path?: string;
  advisory?: boolean;
}

export interface ValidationResult {
  errors: ValidationIssue[];
  warnings: ValidationIssue[];
}

export interface ArtifactSet {
  hasCatalog: boolean;
  hasObcs: boolean;
  hasOpenAPI: boolean;
  hasAsyncAPI: boolean;
  hasSLO: boolean;
}

export interface ApicurioRegistration {
  breaking: boolean;
  previousVersion: string | null;
  version: string;
}

export interface KongSyncResult {
  created: boolean;
  major: number;
  error?: string;
}

export interface MicrocksResult {
  updated: boolean;
  error?: string;
}

export type GovernanceStatus = 'governed' | 'governed_with_warnings' | 'rejected';

export interface GovernanceReport {
  status: GovernanceStatus;
  service: string;
  timestamp: string;
  duration_ms: number;
  processed: string[];
  versions: {
    openapi: string | null;
    asyncapi: string | null;
  };
  kong_route_created: boolean;
  catalog_registered: boolean;
  errors: ValidationIssue[];
  warnings: ValidationIssue[];
  summary: string;
}

export interface SubmitBody {
  catalog_url?: string;
}

export interface OBCFile {
  name: string;
  content: string;
}
