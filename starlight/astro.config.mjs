import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

import sidebar from './starlight.sidebar.mjs';

export default defineConfig({
  integrations: [
    starlight({
      title: 'Documentation Websites for R Packages with Astro Starlight',
      sidebar,
      customCss: ['./src/styles/nova.css', './src/styles/ion.css', './src/styles/ion-overrides.css'],
    }),
  ],
  markdown: {
    shikiConfig: {
      themes: {
        light: 'github-light',
        dark: 'github-dark-dimmed',
      },
    },
  },
});
