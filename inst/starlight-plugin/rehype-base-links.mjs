/* removed — see CONTRACT.md, "Links in prose".
 *
 * This was a rehype plugin that prefixed root-relative markdown links with the
 * site base. Astro 7 renders Starlight markdown with the `satteri` processor,
 * which does not run remark/rehype plugins at all; wiring it up produced a
 * build warning and silently did nothing. Forcing `markdown.processor: unified()`
 * on every site to get it back is too large a change to make on a user's behalf.
 *
 * R therefore emits prose links with the base already applied. Paths in
 * site.json and in `sd:` frontmatter stay base-less and are prefixed at render.
 */
