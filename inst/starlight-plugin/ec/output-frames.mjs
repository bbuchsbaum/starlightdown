/**
 * Expressive Code plugin for R output blocks.
 *
 * R's example runner emits console output as fenced blocks with reserved info
 * strings — ```r-output, ```r-message, ```r-warning, ```r-error — sitting
 * directly beneath the ```r block that produced them. This plugin renders those
 * as unhighlighted, chrome-free blocks tagged with `sd-output` and `sd-<kind>`;
 * `styles/code.css` then fuses each source/output pair into a single cell.
 *
 * Output is also marked `data-pagefind-ignore`, so searching for a term finds
 * the function that produces it rather than every page that printed it.
 */

const OUTPUT_LANGUAGES = {
	'r-output': 'output',
	'r-message': 'message',
	'r-warning': 'warning',
	'r-error': 'error',
};

function addClass(node, className) {
	const props = (node.properties ??= {});
	const existing = props.className;
	if (Array.isArray(existing)) existing.push(className);
	else if (typeof existing === 'string') props.className = [existing, className];
	else props.className = [className];
}

export default function outputFrames() {
	// Keyed by block, so nothing leaks between builds or between blocks.
	const kinds = new WeakMap();

	return {
		name: 'starlightdown-output-frames',
		hooks: {
			preprocessLanguage({ codeBlock }) {
				const kind = OUTPUT_LANGUAGES[codeBlock.language];
				if (!kind) return;
				kinds.set(codeBlock, kind);
				// Console output is not R source: highlighting it invents syntax
				// that isn't there. Render it verbatim.
				codeBlock.language = 'plaintext';
			},

			preprocessMetadata({ codeBlock }) {
				if (!kinds.has(codeBlock)) return;
				// No editor or terminal chrome — the fused cell supplies the frame.
				codeBlock.props.frame = 'none';
			},

			postprocessRenderedBlock({ codeBlock, renderData }) {
				const kind = kinds.get(codeBlock);
				if (!kind) return;
				addClass(renderData.blockAst, 'sd-output');
				addClass(renderData.blockAst, `sd-output-${kind}`);
				renderData.blockAst.properties.dataPagefindIgnore = 'all';
			},

			postprocessRenderedBlockGroup({ renderedGroupContents, renderData }) {
				// Tag the outer `.expressive-code` wrapper as well: CSS needs to see
				// the output block as a *sibling* of the source block to fuse them.
				const kind = renderedGroupContents
					.map(({ codeBlock }) => kinds.get(codeBlock))
					.find(Boolean);
				if (!kind) return;
				addClass(renderData.groupAst, 'sd-output-block');
				addClass(renderData.groupAst, `sd-output-${kind}`);
			},
		},
	};
}
