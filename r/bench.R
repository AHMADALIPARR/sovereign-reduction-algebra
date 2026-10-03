# Measured benches only. Latency is system.time elapsed, printed to 1e-6 s.
# user.self and sys.self are printed too. No imputed times.
# Matrices are gmp bigz, never double.
# A[i,j] = (i*n+j) mod 5. B[i,j] = (n*n + i*n + j) mod 5. Row-major.
# sha512_dag_seal calls dag_seal_hex on
#   exact = product, predicted = product, weights = the 4x4 permutation,
#   prime = Goldilocks p.
# The routed head is not part of this timing.
# N=1024 sha512_dag_seal is not started: the preimage grows with N^2 and
# the N=128 seal is already the measured cost of this interpreter.

userlib <- path.expand("~/R/library")
if (dir.exists(userlib)) .libPaths(c(userlib, .libPaths()))
suppressPackageStartupMessages(library(gmp))

cmd_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
this_file <- sub("^--file=", "", file_arg[[1]])
source(file.path(dirname(normalizePath(this_file)), "sha512.R"))

fmt_sec <- function(x) formatC(x, format = "f", digits = 6)

P <- as.bigz("18446744069414584321")
PERM4 <- as.bigz(matrix(c(
  "0", "1", "0", "0",
  "0", "0", "1", "0",
  "0", "0", "0", "1",
  "1", "0", "0", "0"
), nrow = 4L, byrow = TRUE))

cat("BENCH_V1\nLANGUAGE\nR\n")
cat("VERSION\n")
cat(R.version.string, "\n", sep = "")
cat("GMP_VERSION\n")
cat(as.character(packageVersion("gmp")), "\n", sep = "")
cat("TIMER\nsystem.time\n")

fill_mat <- function(n, offset) {
  idx <- 0:(n * n - 1L)
  chars <- as.character((offset + idx) %% 5L)
  M <- as.bigz(matrix(chars, nrow = n, byrow = TRUE))
  if (!inherits(M, "bigz")) stop("NOT_BIGZ", call. = FALSE)
  M
}

run_mm <- function(n, trials) {
  A <- fill_mat(n, 0)
  B <- fill_mat(n, n * n)
  C <- A %*% B
  if (!inherits(C, "bigz")) stop("NOT_BIGZ", call. = FALSE)
  elapsed <- character(trials)
  user <- character(trials)
  sys <- character(trials)
  for (i in seq_len(trials)) {
    tm <- system.time(C <- A %*% B)
    elapsed[i] <- fmt_sec(tm[["elapsed"]])
    user[i] <- fmt_sec(tm[["user.self"]])
    sys[i] <- fmt_sec(tm[["sys.self"]])
  }
  if (!inherits(C, "bigz")) stop("NOT_BIGZ", call. = FALSE)
  cat("RECORD\nSIZE\n", n, "\nOP\nunmasked_integer_matmul\nTRIALS\n", trials, "\n", sep = "")
  cat("SECONDS\n")
  cat(elapsed, sep = "\n")
  cat("\n")
  cat("USER_SECONDS\n")
  cat(user, sep = "\n")
  cat("\n")
  cat("SYS_SECONDS\n")
  cat(sys, sep = "\n")
  cat("\n")
  cat("CHECKSUM\n")
  cat(as.character(sum(C)), "\n", sep = "")
  cat("RESULT_TYPE\nbigz\n")
  C
}

run_seal <- function(n, C, trials) {
  if (!inherits(C, "bigz")) stop("NOT_BIGZ", call. = FALSE)
  elapsed <- character(trials)
  user <- character(trials)
  sys <- character(trials)
  s <- ""
  for (i in seq_len(trials)) {
    tm <- system.time(s <- dag_seal_hex(C, C, PERM4, P))
    elapsed[i] <- fmt_sec(tm[["elapsed"]])
    user[i] <- fmt_sec(tm[["user.self"]])
    sys[i] <- fmt_sec(tm[["sys.self"]])
  }
  nbytes <- length(node_raw("exact_head", C))
  cat("RECORD\nSIZE\n", n, "\nOP\nsha512_dag_seal\nTRIALS\n", trials, "\n", sep = "")
  cat("SECONDS\n")
  cat(elapsed, sep = "\n")
  cat("\n")
  cat("USER_SECONDS\n")
  cat(user, sep = "\n")
  cat("\n")
  cat("SYS_SECONDS\n")
  cat(sys, sep = "\n")
  cat("\n")
  cat("CHECKSUM\n")
  cat(s, "\n", sep = "")
  cat("NODE_BYTES\n", nbytes, "\n", sep = "")
  cat("RESULT_TYPE\nsha512\n")
  s
}

C128 <- run_mm(128L, 3L)
run_seal(128L, C128, 3L)
C1024 <- run_mm(1024L, 3L)
cat("SKIP_LINE\n")
cat("1024 sha512_dag_seal not started: N=128 sha512_dag_seal was measured in this process; ",
    "the node preimage holds N*N integers and the seal hashes two of them, ",
    "so N=1024 is 64 times the integers. This R SHA-512 is an interpreter ",
    "loop over 16-bit limbs and was not run at N=1024.\n", sep = "")
cat("BENCH_DONE\n")
quit(status = 0L)
