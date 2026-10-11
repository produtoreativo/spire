import { ArtifactSet } from './types';

type MulterFiles = { [fieldname: string]: Express.Multer.File[] };

export function detectArtifacts(files: MulterFiles): ArtifactSet {
  return {
    hasCatalog: Boolean(files.catalog_info?.[0]),
    hasObcs: (files.obcs?.length ?? 0) > 0,
    hasOpenAPI: Boolean(files.openapi?.[0]),
    hasAsyncAPI: Boolean(files.asyncapi?.[0]),
    hasSLO: Boolean(files.slo?.[0]),
  };
}

export function slugify(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}
