package authz

import future.keywords.if
import future.keywords.in

default allow := false

# ─── Public paths (no JWT required) ──────────────────────────────────────────
allow if {
	input.path in {"/health", "/healthz", "/_ping", "/status"}
}

# ─── Role extraction from X-User-Claims header ───────────────────────────────
# oidcify encodes the JWT payload as standard base64 (not URL-safe) in the header.
claims := json.unmarshal(base64.decode(input.headers["x-user-claims"])) if {
	is_string(input.headers["x-user-claims"])
}

roles := claims.realm_access.roles if {
	claims.realm_access.roles
}

# ─── spire-admin: unrestricted access ────────────────────────────────────────
allow if {
	"spire-admin" in roles
}

# ─── spire-publisher: read + write to /specs, read-only elsewhere ─────────────
allow if {
	"spire-publisher" in roles
	startswith(input.path, "/specs")
}

allow if {
	"spire-publisher" in roles
	input.method in {"GET", "HEAD", "OPTIONS"}
}

# ─── spire-reader: read-only on all routes ───────────────────────────────────
allow if {
	"spire-reader" in roles
	input.method in {"GET", "HEAD", "OPTIONS"}
}

# ─── spire-registrar: CI/CD pipelines — register catalog locations ────────────
allow if {
	"spire-registrar" in roles
	startswith(input.path, "/backstage/api/catalog/")
	input.method in {"GET", "POST"}
}

# ─── spire-registrar: governance plugin — submit service artifacts ─────────────
allow if {
	"spire-registrar" in roles
	startswith(input.path, "/spire/api/governance/")
	input.method in {"POST", "GET"}
}

# ─── Versioned service routes: any authenticated user can call governed APIs ───
allow if {
	count(roles) > 0
	regex.match(`^/v\d+/[a-z0-9-]+/`, input.path)
}
