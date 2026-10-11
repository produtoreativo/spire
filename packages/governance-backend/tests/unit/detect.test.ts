import { detectArtifacts, slugify } from '../../src/detect';

type FakeFile = { buffer: Buffer; originalname: string };
type FakeFiles = { [k: string]: FakeFile[] };

function makeFile(name = 'file.yaml'): FakeFile {
  return { buffer: Buffer.from('content'), originalname: name };
}

describe('detectArtifacts', () => {
  it('detects all artifacts when all present', () => {
    const files: FakeFiles = {
      catalog_info: [makeFile('catalog-info.yaml')],
      obcs: [makeFile('obc.md'), makeFile('obc2.md')],
      openapi: [makeFile('openapi.yaml')],
      asyncapi: [makeFile('asyncapi.yaml')],
      slo: [makeFile('slo.yaml')],
    };
    const result = detectArtifacts(files as never);
    expect(result).toEqual({ hasCatalog: true, hasObcs: true, hasOpenAPI: true, hasAsyncAPI: true, hasSLO: true });
  });

  it('detects only catalog when only catalog present', () => {
    const files: FakeFiles = { catalog_info: [makeFile()] };
    const result = detectArtifacts(files as never);
    expect(result).toEqual({ hasCatalog: true, hasObcs: false, hasOpenAPI: false, hasAsyncAPI: false, hasSLO: false });
  });

  it('returns all false for empty files', () => {
    const result = detectArtifacts({} as never);
    expect(result).toEqual({ hasCatalog: false, hasObcs: false, hasOpenAPI: false, hasAsyncAPI: false, hasSLO: false });
  });

  it('detects OBCs when one or more present', () => {
    const files: FakeFiles = { catalog_info: [makeFile()], obcs: [makeFile('obc.md')] };
    const result = detectArtifacts(files as never);
    expect(result.hasObcs).toBe(true);
  });
});

describe('slugify', () => {
  it.each([
    ['payments-api', 'payments-api'],
    ['Payments API', 'payments-api'],
    ['my_service', 'my-service'],
    ['  space  ', 'space'],
    ['UPPER CASE', 'upper-case'],
    ['multiple---dashes', 'multiple-dashes'],
  ])('slugifies %s to %s', (input, expected) => {
    expect(slugify(input)).toBe(expected);
  });
});
