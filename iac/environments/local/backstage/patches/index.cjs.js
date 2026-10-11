'use strict';

// EXP-004/EXP-008: Custom backend entry point for Spire IDP.
// Base: ghcr.io/backstage/backstage:latest (official image).
// EXP-008: Governance plugin compiled from packages/governance-backend/ (TypeScript).
//   Build: npm run build in packages/governance-backend/ → dist/
//   Dockerfile: cp dist/ → /app/packages/backend/dist/plugins/governance-backend/

var backendDefaults = require('@backstage/backend-defaults');

const backend = backendDefaults.createBackend();
backend.add(import('@backstage/plugin-app-backend'));
backend.add(import('@backstage/plugin-proxy-backend'));
backend.add(import('@backstage/plugin-scaffolder-backend'));
backend.add(import('@backstage/plugin-scaffolder-backend-module-github'));
backend.add(import('@backstage/plugin-scaffolder-backend-module-notifications'));
backend.add(import('@backstage/plugin-techdocs-backend'));
backend.add(import('@backstage/plugin-auth-backend'));
backend.add(import('@backstage/plugin-auth-backend-module-guest-provider'));
backend.add(import('@backstage/plugin-auth-backend-module-oidc-provider'));
backend.add(import('@backstage/plugin-catalog-backend'));
backend.add(import('@backstage/plugin-catalog-backend-module-scaffolder-entity-model'));
backend.add(import('@backstage/plugin-catalog-backend-module-logs'));
backend.add(import('@backstage/plugin-permission-backend'));
backend.add(import('@backstage/plugin-permission-backend-module-allow-all-policy'));
backend.add(import('@backstage/plugin-search-backend'));
backend.add(import('@backstage/plugin-search-backend-module-pg'));
backend.add(import('@backstage/plugin-search-backend-module-catalog'));
backend.add(import('@backstage/plugin-search-backend-module-techdocs'));
backend.add(import('@backstage/plugin-kubernetes-backend'));
backend.add(import('@backstage/plugin-user-settings-backend'));
backend.add(import('@backstage/plugin-notifications-backend'));
backend.add(import('@backstage/plugin-signals-backend'));
backend.add(import('@backstage/plugin-mcp-actions-backend'));
backend.add(import('@backstage/plugin-vault-backend'));
// EXP-008: Governance plugin — validates OBCs + specs, syncs Kong + Apicurio
backend.add(import('./plugins/governance-backend/index.js'));
backend.start();
