/**
 * Frontmatter schema for the `sd:` namespace.
 *
 * Every page starlightdown generates carries an `sd:` block. It holds only the
 * data that cannot be expressed as markdown: what kind of page this is, the
 * function's aliases, its usage synopsis, its lifecycle. Prose — descriptions,
 * argument documentation, examples — stays in the body as plain GFM.
 *
 * Because this runs through `docsSchema({ extend: sdSchema })`, a typo in the R
 * emitter becomes a precise build error naming the file and the field.
 *
 * @example
 * // src/content.config.ts
 * import { docsSchema } from '@astrojs/starlight/schema';
 * import { sdSchema } from 'starlightdown-starlight/schema';
 * schema: docsSchema({ extend: sdSchema })
 */

import { z } from 'astro/zod';

/** Lifecycle stages, mirroring the {lifecycle} package. */
export const lifecycleSchema = z.enum(['experimental', 'stable', 'deprecated', 'superseded']);

/**
 * A see-also target. A bare string is resolved against the manifest's topic
 * map; anything unresolved is rendered as literal text rather than a dead link.
 * The object form carries a pre-resolved URL, e.g. from downlit.
 */
const seeAlsoSchema = z.union([
	z.string(),
	z.object({
		name: z.string(),
		href: z.string().optional(),
		package: z.string().optional(),
	}),
]);

/** One entry in a `reference/index.md` group. */
const indexTopicSchema = z.object({
	name: z.string(),
	/** Root-relative route without the site base, e.g. `/reference/add_one/`. */
	slug: z.string().optional(),
	summary: z.string().optional(),
	lifecycle: lifecycleSchema.optional(),
});

/** A section of the reference index, from a `_pkgdown.yml` reference group. */
const groupSchema = z.object({
	title: z.string(),
	desc: z.string().optional(),
	topics: z.array(indexTopicSchema).default([]),
});

const badgeSchema = z.union([
	z.string(),
	z.object({
		text: z.string(),
		variant: z.enum(['note', 'danger', 'success', 'caution', 'tip', 'default']).optional(),
		href: z.string().optional(),
	}),
]);

export const sdFrontmatterSchema = z.object({
	/** Selects the chrome wrapped around the page body. */
	kind: z
		.enum(['reference', 'reference-index', 'article', 'news', 'home'])
		.default('article'),
	/** Topic name, for reference pages: the primary function name. */
	name: z.string().optional(),
	/** All `\alias{}` entries, including `name` itself. */
	aliases: z.array(z.string()).default([]),
	/** Usage synopsis, rendered as an R code block. Newline-separated. */
	usage: z.string().optional(),
	lifecycle: lifecycleSchema.optional(),
	/** Package version that introduced the topic, e.g. `"0.2.0"`. */
	since: z.string().optional(),
	/** Source file relative to the package root, e.g. `"R/arith.R"`. */
	source: z.string().optional(),
	/** `@family` label(s) this topic belongs to. */
	family: z.union([z.string(), z.array(z.string())]).optional(),
	seealso: z.array(seeAlsoSchema).default([]),
	/** Sections for `kind: reference-index` pages. */
	groups: z.array(groupSchema).optional(),
	badges: z.array(badgeSchema).default([]),
});

export const sdSchema = z.object({
	sd: sdFrontmatterSchema.optional(),
});

export default sdSchema;
