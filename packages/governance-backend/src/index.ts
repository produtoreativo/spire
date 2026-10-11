import { createBackendPlugin, coreServices } from '@backstage/backend-plugin-api';
import { createRouter } from './router';

export const governancePlugin = createBackendPlugin({
  pluginId: 'spire-governance',
  register(reg) {
    reg.registerInit({
      deps: {
        httpRouter: coreServices.httpRouter,
        config: coreServices.rootConfig,
        logger: coreServices.rootLogger,
      },
      async init({ httpRouter, config, logger }) {
        httpRouter.addAuthPolicy({ path: '/', allow: 'unauthenticated' });
        const router = createRouter({ config, logger });
        httpRouter.use(router);
        logger.info('@spire/backstage-plugin-governance-backend registered at /api/spire-governance');
      },
    });
  },
});

export default governancePlugin;
