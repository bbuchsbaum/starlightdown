import type { z } from 'astro/zod';

export type SdKind = 'reference' | 'reference-index' | 'article' | 'news' | 'home';
export type SdLifecycle = 'experimental' | 'stable' | 'deprecated' | 'superseded';

export interface SdSeeAlso {
	name: string;
	href?: string;
	package?: string;
}

export interface SdIndexTopic {
	name: string;
	slug?: string;
	summary?: string;
	lifecycle?: SdLifecycle;
}

export interface SdGroup {
	title: string;
	desc?: string;
	topics: SdIndexTopic[];
}

export interface SdBadge {
	text: string;
	variant?: 'note' | 'danger' | 'success' | 'caution' | 'tip' | 'default';
	href?: string;
}

export interface SdFrontmatter {
	kind: SdKind;
	name?: string;
	aliases: string[];
	usage?: string;
	lifecycle?: SdLifecycle;
	since?: string;
	source?: string;
	family?: string | string[];
	seealso: (string | SdSeeAlso)[];
	groups?: SdGroup[];
	badges: (string | SdBadge)[];
}

export declare const lifecycleSchema: z.ZodType<SdLifecycle>;
export declare const sdFrontmatterSchema: z.ZodObject<z.ZodRawShape>;
export declare const sdSchema: z.ZodObject<z.ZodRawShape>;
export default sdSchema;
