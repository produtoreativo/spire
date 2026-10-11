#!/usr/bin/env bash
# Regenera CA local e wildcard cert para *.spire.localhost.
# Executar da raiz do ambiente local: ./traefik/certs/generate.sh
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

echo "→ Generating Spire Local Root CA..."
openssl genrsa -out "$DIR/spire-ca.key" 4096 2>/dev/null
openssl req -new -x509 -days 3650 -key "$DIR/spire-ca.key" -sha256 \
  -out "$DIR/spire-ca.crt" \
  -subj "/C=BR/ST=SP/L=Sao Paulo/O=Spire Development/CN=Spire Local Root CA"

echo "→ Generating wildcard key and CSR..."
openssl genrsa -out "$DIR/wildcard.key" 2048 2>/dev/null

cat > /tmp/spire-san.cnf << 'EOF'
[req]
req_extensions     = v3_req
distinguished_name = req_dn
prompt             = no

[req_dn]
C  = BR
ST = SP
L  = Sao Paulo
O  = Spire Development
CN = *.spire.localhost

[v3_req]
subjectAltName    = @alt_names
keyUsage          = digitalSignature, keyEncipherment
extendedKeyUsage  = serverAuth
basicConstraints  = CA:FALSE

[alt_names]
DNS.1 = *.spire.localhost
DNS.2 = spire.localhost
DNS.3 = localhost
EOF

openssl req -new -key "$DIR/wildcard.key" -out /tmp/wildcard.csr -config /tmp/spire-san.cnf

cat > /tmp/spire-ext.cnf << 'EOF'
subjectAltName    = DNS:*.spire.localhost,DNS:spire.localhost,DNS:localhost
keyUsage          = digitalSignature, keyEncipherment
extendedKeyUsage  = serverAuth
basicConstraints  = CA:FALSE
EOF

openssl x509 -req -in /tmp/wildcard.csr \
  -CA "$DIR/spire-ca.crt" -CAkey "$DIR/spire-ca.key" \
  -CAcreateserial -out "$DIR/wildcard.crt" \
  -days 825 -sha256 -extfile /tmp/spire-ext.cnf

echo "✓ Done: spire-ca.crt + spire-ca.key + wildcard.crt + wildcard.key"
echo ""
echo "Trust the CA on macOS:"
echo "  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $DIR/spire-ca.crt"
echo ""
echo "Trust the CA on Linux (Debian/Ubuntu):"
echo "  sudo cp $DIR/spire-ca.crt /usr/local/share/ca-certificates/spire-local-ca.crt && sudo update-ca-certificates"
