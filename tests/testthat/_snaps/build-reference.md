# a whole reference page is stable

    Code
      cat(readLines(file.path(built$stage, "reference", "full_add.md"), warn = FALSE,
      encoding = "UTF-8"), sep = "\n")
    Output
      ---
      title: full_add
      description: Add two numbers
      sd:
        kind: reference
        name: full_add
        aliases:
        - full_add
        - full_plus
        usage: full_add(x, y = 1)
        source: man/full_add.Rd
        family:
        - arithmetic
        seealso:
        - full_describe
        - full_internal
        - name: lm
          package: stats
          href: https://rdrr.io/r/stats/lm.html
      ---
      
      Adds `y` to `x`, which is roughly $x + y$ and no more.
      
      ## Arguments
      
      | Argument | Description |
      | :--- | :--- |
      | `x` | A numeric vector. |
      | `y` | A numeric vector of length one. Defaults to `1`. |
      
      ## Details
      
      The identity behind this function is
      
      $$
      \sum_i (x_i + y) = n y + \sum_i x_i
      $$
      
      Behaviour depends on the storage mode of `x`:
      
      | Mode | Result | Note |
      | :--- | :--- | :--- |
      | integer | exact | no coercion happens |
      | double | exact | to within `.Machine$double.eps` |
      
      Roughly `100%` of inputs behave. See [`full_config`](/testpkg.full/reference/full_config/) for
      options and [`lm`](https://rdrr.io/r/stats/lm.html) for something entirely different.
      
      ## Value
      
      A numeric vector, `x + y`.
      
      ## See also
      
      [`full_describe`](/testpkg.full/reference/full_describe/), the helper [`full_internal`](/testpkg.full/reference/full_internal/), and
      [linear models](https://rdrr.io/r/stats/lm.html).
      
      ## Examples
      
      ```r
      full_add(1, 2)
      ```
      
      ```r-output
      [1] 3
      ```
      
      ```r
      full_add(1:3)
      ```
      
      ```r-output
      [1] 2 3 4
      ```

# the reference index page is stable

    Code
      cat(readLines(file.path(built$stage, "reference", "index.md"), warn = FALSE,
      encoding = "UTF-8"), sep = "\n")
    Output
      ---
      title: Function reference
      sd:
        kind: reference-index
        groups:
        - title: Core, one's favourites
          desc: |
            Primary entry points. These are the functions you'll reach for first.
          topics:
          - name: full_add
            slug: /reference/full_add/
            summary: Add two numbers
          - name: full_config
            slug: /reference/full_config/
            summary: Configure testpkg.full
        - title: Everything else
          topics:
          - name: full_describe
            slug: /reference/full_describe/
            summary: Describe an object in one line
          - name: full_experimental
            slug: /reference/full_experimental/
            summary: Double a number
            lifecycle: experimental
          - name: full_plot
            slug: /reference/full_plot/
            summary: Plot a sequence
          - name: full_quotes
            slug: /reference/full_quotes/
            summary: Find one's bearings with Ω and friends
          - name: +.fullclass
            slug: /reference/full_ops/
            summary: Add two fullclass objects
      ---

