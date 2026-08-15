/**
 * Expressive Code configuration.
 *
 * This lives in its own module rather than in the Starlight plugin's
 * `updateConfig({ expressiveCode })` because Astro serializes integration
 * options to JSON so the `<Code>` component can rebuild the renderer at
 * runtime. Our `plugins` array is not serializable, so passing it through the
 * integration breaks every `<Code>` on the site. Expressive Code's documented
 * escape hatch is a root `ec.config.mjs`, which is imported as a real module —
 * the scaffold ships a three-line one that re-exports this object.
 *
 * Colour values fall back to Starlight's own variables so the code styling
 * still holds together under an external theme preset, where the `--sd-*`
 * tokens are absent.
 */

import outputFrames from './ec/output-frames.mjs';

export const ecConfig = {
	themes: ['github-dark-dimmed', 'github-light-default'],
	useStarlightUiThemeColors: true,
	useStarlightDarkModeSwitch: true,
	plugins: [outputFrames()],
	frames: {
		showCopyToClipboardButton: true,
		// R examples are full of `# comments`; never mistake one for a filename.
		extractFileNameFromCode: false,
	},
	styleOverrides: {
		borderRadius: '2px',
		borderWidth: '1px',
		borderColor: 'var(--sd-code-border, var(--sl-color-hairline))',
		codeBackground: 'var(--sd-code-bg, var(--sl-color-bg))',
		codeFontFamily: 'var(--sd-font-mono, var(--__sl-font-mono))',
		// Code sits next to 17px serif prose, and IBM Plex Mono runs small for
		// its size. Starlight's default (13px) reads as a footnote beside the
		// body text; 15px is the smallest that holds its own.
		codeFontSize: '0.9375rem',
		codeLineHeight: '1.6',
		codePaddingBlock: '0.7rem',
		codePaddingInline: '0.9rem',
		uiFontFamily: 'var(--sd-font-sans, var(--__sl-font))',
		uiFontSize: '0.75rem',
		frames: {
			frameBoxShadowCssValue: 'none',
			shadowColor: 'transparent',
			editorActiveTabBackground: 'var(--sd-code-bg, var(--sl-color-bg))',
			editorActiveTabBorderColor: 'var(--sd-code-border, var(--sl-color-hairline))',
			editorActiveTabForeground: 'var(--sd-ink, var(--sl-color-white))',
			editorActiveTabIndicatorHeight: '0px',
			editorTabBarBackground: 'var(--sd-code-chrome, var(--sl-color-bg-nav))',
			editorTabBarBorderBottomColor: 'var(--sd-code-border, var(--sl-color-hairline))',
			editorTabBorderRadius: '0px',
			terminalBackground: 'var(--sd-code-bg, var(--sl-color-bg))',
			terminalTitlebarBackground: 'var(--sd-code-chrome, var(--sl-color-bg-nav))',
			terminalTitlebarBorderBottomColor: 'var(--sd-code-border, var(--sl-color-hairline))',
			terminalTitlebarForeground: 'var(--sd-ink-muted, var(--sl-color-gray-3))',
		},
	},
};

export default ecConfig;
