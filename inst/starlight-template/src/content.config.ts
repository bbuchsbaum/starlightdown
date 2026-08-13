import { defineCollection } from 'astro:content';
import { docsLoader } from '@astrojs/starlight/loaders';
import { docsSchema } from '@astrojs/starlight/schema';
import { sdSchema } from 'starlightdown-starlight/schema';

// `sdSchema` validates the `sd:` frontmatter block that starlightdown writes.
// A malformed field fails the build with the offending file and key named.
export const collections = {
	docs: defineCollection({ loader: docsLoader(), schema: docsSchema({ extend: sdSchema }) }),
};
