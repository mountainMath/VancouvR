test_that("unqoute_strings removes surrounding double quotes", {
  expect_equal(VancouvR:::unqoute_strings('"hello"'), "hello")
  expect_equal(VancouvR:::unqoute_strings("hello"),   "hello")
  expect_equal(VancouvR:::unqoute_strings('""'),       "")
  expect_equal(VancouvR:::unqoute_strings('"'),        "")  # lone quote is stripped
})

test_that("unqoute_strings is vectorised", {
  expect_equal(
    VancouvR:::unqoute_strings(c('"a"', 'b', '"c"')),
    c("a", "b", "c")
  )
})

test_that("remove_na_cols drops all-NA columns", {
  df <- tibble::tibble(
    dataset_id   = c("a", "b"),
    title        = c("A", "B"),
    keyword      = c("k1", "k2"),
    `search-term` = c("s1", "s2"),
    all_na       = c(NA_character_, NA_character_),
    has_data     = c(1, NA)
  )
  result <- VancouvR:::remove_na_cols(df)
  expect_false("all_na"   %in% names(result))
  expect_true("has_data"  %in% names(result))
})

test_that("remove_na_cols always keeps main_cols even when all NA", {
  df <- tibble::tibble(
    dataset_id    = c(NA_character_, NA_character_),
    title         = c(NA_character_, NA_character_),
    keyword       = c(NA_character_, NA_character_),
    `search-term` = c(NA_character_, NA_character_),
    other_na      = c(NA_character_, NA_character_)
  )
  result <- VancouvR:::remove_na_cols(df)
  expect_true(all(c("dataset_id", "title", "keyword", "search-term") %in% names(result)))
  expect_false("other_na" %in% names(result))
})

test_that("remove_na_cols puts main_cols before non-main columns", {
  df <- tibble::tibble(
    has_data      = c(1, 2),
    `search-term` = c("s", "t"),
    keyword       = c("k", "l"),
    title         = c("A", "B"),
    dataset_id    = c("a", "b")
  )
  result <- VancouvR:::remove_na_cols(df)
  main_positions  <- which(names(result) %in% c("dataset_id", "title", "keyword", "search-term"))
  other_positions <- which(!names(result) %in% c("dataset_id", "title", "keyword", "search-term"))
  expect_true(max(main_positions) < min(other_positions))
})


test_that("cov_as_integer keeps values beyond R's integer range", {
  # The portal's `int` type is 64-bit. Assessed land values overflow int32, and
  # as.integer() would turn them into NA.
  big <- c("1000", "3000000000")
  expect_type(VancouvR:::cov_as_integer(big), "double")
  expect_equal(VancouvR:::cov_as_integer(big), c(1000, 3e9))

  expect_type(VancouvR:::cov_as_integer(c("1000", "2000")), "integer")
  expect_equal(VancouvR:::cov_as_integer(c("1000", NA)), c(1000L, NA))
})
