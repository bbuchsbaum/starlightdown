# running examples emits the source/output fence contract

    Code
      cat(out$markdown)
    Output
      ```r
      1 + 1
      ```
      
      ```r-output
      [1] 2
      ```
      
      ```r
      x <- 41
      x + 1
      ```
      
      ```r-output
      [1] 42
      ```

# messages, warnings and errors get their own fences

    Code
      cat(out$markdown)
    Output
      ```r
      message("a message")
      ```
      
      ```r-message
      a message
      ```
      
      ```r
      warning("a warning")
      ```
      
      ```r-warning
      Warning: a warning
      ```
      
      ```r
      stop("an error")
      ```
      
      ```r-error
      Error: an error
      ```
      
      ```r
      "still evaluated"
      ```
      
      ```r-output
      [1] "still evaluated"
      ```

# dontrun is shown but not run, dontshow is run but not shown

    Code
      cat(out$markdown)
    Output
      ```r
      1 + 1
      ```
      
      ```r-output
      [1] 2
      ```
      
      ```r
      # Not run:
      stop("this must never run")
      # End(Not run)
      ```

# execute = FALSE shows the code without running it

    Code
      cat(out$markdown)
    Output
      ```r
      1 + 1
      stop("must not run")
      ```

