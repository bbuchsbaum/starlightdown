/**
 * Types for the manifest module the plugin injects.
 *
 * Reference it from a project with:
 *   /// <reference types="starlightdown-starlight/virtual" />
 */

declare module 'virtual:starlightdown/site' {
	import type { SdKind, SdLifecycle } from 'starlightdown-starlight/schema';

	export interface SdTopic {
		name: string;
		/** Root-relative route without the site base, e.g. `/reference/add_one/`. */
		route: string;
		title?: string;
		summary?: string;
		lifecycle?: SdLifecycle;
		aliases?: string[];
	}

	export interface SdManifest {
		schemaVersion: 1;
		generator: { name: string; version: string };
		site: { url: string; base: string; theme: string };
		package: {
			name: string;
			title: string;
			version: string;
			license?: string;
			maintainer?: { name: string; email?: string } | null;
			urls: {
				homepage?: string;
				repo?: string;
				bugs?: string;
				cran?: string;
				runiverse?: string;
				/** Explicit prefix for source links; overrides the guess from `repo`. */
				source?: string;
			};
		};
		install: { cran?: string; runiverse?: string; github?: string };
		citation: { text: string; bibtex?: string } | null;
		quickstart?: string | null;
		sidebar: unknown[];
		topics: Record<string, SdTopic>;
		redirects: Record<string, string>;
		news: { latest?: string; route?: string } | null;
		routes?: Array<{ id: string; route: string; kind: SdKind; title: string }>;
	}

	const site: SdManifest;
	export default site;
}

declare namespace App {
	interface Locals {
		starlightdown: {
			kind: import('starlightdown-starlight/schema').SdKind;
			sd: import('starlightdown-starlight/schema').SdFrontmatter;
			topic: import('virtual:starlightdown/site').SdTopic | null;
		};
	}
}
