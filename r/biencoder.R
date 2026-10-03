# SUBLEQ bi-encoder. Not softmax attention. Not a trained model.
# Weights are a fixed permutation, not fit by a loop.
# Every tensor entry is a gmp bigz extended integer. Doubles abort.
# Unmasked head is Q %*% t(K) and must equal A %*% B.
# Routed head masks dot-product factors with the SUBLEQ predicate.
# Goldilocks p = 2^64 - 2^32 + 1.

userlib <- path.expand("~/R/library")
if (dir.exists(userlib)) .libPaths(c(userlib, .libPaths()))
suppressPackageStartupMessages(library(gmp))

cmd_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
this_file <- sub("^--file=", "", file_arg[[1]])
source(file.path(dirname(normalizePath(this_file)), "sha512.R"))

P <- as.bigz("18446744069414584321")
GSAFE <- as.bigz("65537")
LCGA <- as.bigz("48271")
LCGM <- as.bigz("2147483647")
SEED0 <- as.bigz("20261002")
RADIX <- as.bigz("5")
HALF <- P %/% as.bigz("2")

refuse_double <- function(M, where) {
  if (is.double(M) || inherits(M, "numeric")) {
    # bigz is not numeric; a plain numeric matrix is float or integer.
    if (!inherits(M, "bigz")) {
      stop(paste("FLOAT_REFUSED", where), call. = FALSE)
    }
  }
  if (!inherits(M, "bigz")) {
    stop(paste("NOT_BIGZ", where), call. = FALSE)
  }
  M
}

as_mat <- function(chars, nr, nc) {
  # Character digits only, then bigz. Never pass a double vector in.
  if (any(grepl("[^0-9-]", chars))) stop("non-digit matrix entry", call. = FALSE)
  refuse_double(as.bigz(base::matrix(chars, nrow = nr, ncol = nc, byrow = TRUE)), "as_mat")
}

zeros <- function(nr, nc) {
  as_mat(rep("0", nr * nc), nr, nc)
}

transpose_z <- function(M) {
  refuse_double(M, "transpose_in")
  nr <- nrow(M)
  nc <- ncol(M)
  out <- zeros(nc, nr)
  for (i in seq_len(nr)) {
    for (j in seq_len(nc)) out[j, i] <- M[i, j]
  }
  refuse_double(out, "transpose_out")
}

mm <- function(A, B) {
  refuse_double(A, "mm.A")
  refuse_double(B, "mm.B")
  C <- A %*% B
  refuse_double(C, "mm.C")
}

fmm <- function(A, B) {
  mod.bigz(mm(A, B), P)
}

lcg_step <- function(seed) {
  mod.bigz(LCGA * seed, LCGM)
}

lcg_draw <- function(n, seed) {
  buf <- character(n)
  for (i in seq_len(n)) {
    seed <- lcg_step(seed)
    buf[i] <- as.character(mod.bigz(seed, RADIX))
  }
  list(vals = as.bigz(buf), seed = seed)
}

# SUBLEQ: subtract, compare, predicate, select, route, reduce.
subleq <- function(q, k) {
  diff <- refuse_double(k - q, "diff")
  pred <- as.bigz(diff <= as.bigz("0"))
  selected <- diff[as.logical(pred)]
  routed <- pred * diff
  agg <- sum(routed)
  dot <- sum(pred * q * k)
  list(
    dot = refuse_double(dot, "dot"),
    agg = refuse_double(agg, "agg"),
    pred = pred,
    nsel = length(selected)
  )
}

field_routed <- function(q, k) {
  diff <- mod.bigz(k - q, P)
  signed <- diff - P * as.bigz(diff > HALF)
  pred <- as.bigz(signed <= as.bigz("0"))
  terms <- pred * mod.bigz(q * k, P)
  mod.bigz(sum(terms), P)
}

pair_apply <- function(Q, K, fn) {
  nr <- nrow(Q)
  nc <- nrow(K)
  out <- zeros(nr, nc)
  for (i in seq_len(nr)) {
    for (j in seq_len(nc)) {
      out[i, j] <- fn(Q[i, ], K[j, ])
    }
  }
  refuse_double(out, "pair")
}

pred_rows <- function(Q, K) {
  rows <- list()
  for (i in seq_len(nrow(Q))) {
    for (j in seq_len(nrow(K))) {
      rows[[length(rows) + 1L]] <- subleq(Q[i, ], K[j, ])$pred
    }
  }
  rows
}

run_case <- function(A, B, W) {
  Q <- mm(A, W)
  K <- mm(transpose_z(B), W)
  exact <- mm(Q, transpose_z(K))
  ref <- mm(A, B)
  pr <- pair_apply(Q, K, function(q, k) subleq(q, k)$dot)
  ag <- pair_apply(Q, K, function(q, k) subleq(q, k)$agg)
  pd <- pred_rows(Q, K)
  err <- as.bigz("0")
  for (i in seq_len(nrow(pr))) {
    for (j in seq_len(ncol(pr))) {
      d <- pr[i, j] - ref[i, j]
      if (d < as.bigz("0")) d <- -d
      if (d > err) err <- d
    }
  }
  list(
    Q = Q, K = K, predicted = pr, exact = exact, reference = ref,
    aggregates = ag, predicates = pd, err = err,
    match = all(exact == ref)
  )
}

frun <- function(A, B, W) {
  Q <- fmm(A, W)
  K <- fmm(transpose_z(B), W)
  exact <- fmm(Q, transpose_z(K))
  ref <- fmm(A, B)
  pr <- pair_apply(Q, K, field_routed)
  list(predicted = pr, exact = exact, reference = ref)
}

cat_line <- function(x) cat(as.character(x), "\n", sep = "")

cat_mat <- function(M) {
  refuse_double(M, "print")
  for (i in seq_len(nrow(M))) {
    cat(paste(as.character(M[i, ]), collapse = " "), "\n", sep = "")
  }
}

cat_pred <- function(rows) {
  for (r in rows) cat(paste(as.character(r), collapse = " "), "\n", sep = "")
}

flag <- function(x) if (isTRUE(x)) "1" else "0"

perm_chars <- c(
  "0", "1", "0", "0",
  "0", "0", "1", "0",
  "0", "0", "0", "1",
  "1", "0", "0", "0"
)
PERM <- as_mat(perm_chars, 4L, 4L)
ID4 <- zeros(4L, 4L)
for (i in seq_len(4L)) ID4[i, i] <- as.bigz("1")
perm_ok <- all(mm(PERM, transpose_z(PERM)) == ID4)

drawn_a <- lcg_draw(16L, SEED0)
drawn_b <- lcg_draw(16L, drawn_a$seed)
A <- as_mat(as.character(drawn_a$vals), 4L, 4L)
B <- as_mat(as.character(drawn_b$vals), 4L, 4L)
seeded <- run_case(A, B, PERM)
GS <- mod.bigz(seeded$predicted, GSAFE)
shapes_ok <- all(dim(A) == c(4L, 4L), dim(B) == c(4L, 4L),
                 dim(seeded$predicted) == c(4L, 4L),
                 dim(seeded$exact) == c(4L, 4L),
                 dim(seeded$reference) == c(4L, 4L))

fs <- frun(A, B, PERM)
fs_agrees <- all(fs$predicted == seeded$predicted,
                 fs$exact == seeded$exact,
                 fs$reference == seeded$reference)

LA <- as_mat(c(
  as.character(P - as.bigz("2")), "4", "1", "7",
  "3", as.character(P - as.bigz("5")), "2", "9",
  "8", "1", as.character(P - as.bigz("1")), "6",
  "0", "5", "4", as.character(P - as.bigz("3"))
), 4L, 4L)
LB <- as_mat(c(
  as.character(P - as.bigz("4")), "2", "3", "1",
  "6", as.character(P - as.bigz("1")), "0", "5",
  "1", "8", as.character(P - as.bigz("6")), "2",
  "7", "3", "4", as.character(P - as.bigz("2"))
), 4L, 4L)
fl <- frun(LA, LB, PERM)
fl_match <- all(fl$exact == fl$reference)

HA <- as_mat(c("1", "2", "3", "4", "0", "1"), 2L, 3L)
HB <- as_mat(c("1", "2", "0", "1", "2", "1"), 3L, 2L)
HW <- zeros(3L, 3L)
for (i in seq_len(3L)) HW[i, i] <- as.bigz("1")
hand <- run_case(HA, HB, HW)

sha_empty <- sha512_hex(raw())
sha_abc <- sha512_hex(charToRaw("abc"))
sha_long <- sha512_hex(charToRaw(NIST_LONG_MSG))
seal <- dag_seal_hex(seeded$exact, seeded$predicted, PERM, P)
PRm <- seeded$predicted
PRm[1, 1] <- PRm[1, 1] + as.bigz("1")
mseal <- dag_seal_hex(seeded$exact, PRm, PERM, P)
vok <- verify_dag(seal, seeded$exact, seeded$predicted, PERM, P)
vbad <- verify_dag(seal, seeded$exact, PRm, PERM, P)
NEG <- as.bigz(matrix(c("-12", "0", "7"), nrow = 1L, byrow = TRUE))
NW <- as.bigz(matrix("1", nrow = 1L, ncol = 1L))
nseal <- dag_seal_hex(NEG, NEG, NW, P)

cat("BIENCODER_V1\n")
cat("ENGINE\nR\n")
cat("R_VERSION\n")
cat(R.version.string, "\n", sep = "")
cat("GMP_VERSION\n")
cat(as.character(packageVersion("gmp")), "\n", sep = "")
cat("M\n4\nK\n4\nN\n4\n")
cat("SEED\n")
cat_line(SEED0)
cat("RADIX\n")
cat_line(RADIX)
cat("A\n"); cat_mat(A)
cat("B\n"); cat_mat(B)
cat("WQ\n"); cat_mat(PERM)
cat("WK\n"); cat_mat(PERM)
cat("Q\n"); cat_mat(seeded$Q)
cat("KTOWER\n"); cat_mat(seeded$K)
cat("PREDICTED\n"); cat_mat(seeded$predicted)
cat("EXACT_HEAD\n"); cat_mat(seeded$exact)
cat("REFERENCE\n"); cat_mat(seeded$reference)
cat("AGGREGATES\n"); cat_mat(seeded$aggregates)
cat("PREDICATES\n"); cat_pred(seeded$predicates)
cat("GSAFE_PREDICTED\n"); cat_mat(GS)
cat("MAX_ABS_ERROR\n"); cat_line(seeded$err)
cat("EXACT_HEAD_MATCH\n"); cat(flag(seeded$match), "\n", sep = "")
cat("PERMUTATION_INVERSE\n"); cat(flag(perm_ok), "\n", sep = "")
cat("SHAPES_OK\n"); cat(flag(shapes_ok), "\n", sep = "")
cat("NOT_SOFTMAX\n1\n")
cat("GOLDILOCKS_P\n"); cat_line(P)
cat("FIELD_SMALL_PREDICTED\n"); cat_mat(fs$predicted)
cat("FIELD_SMALL_EXACT_HEAD\n"); cat_mat(fs$exact)
cat("FIELD_SMALL_REFERENCE\n"); cat_mat(fs$reference)
cat("FIELD_SMALL_AGREES\n"); cat(flag(fs_agrees), "\n", sep = "")
cat("FIELD_LARGE_PREDICTED\n"); cat_mat(fl$predicted)
cat("FIELD_LARGE_EXACT_HEAD\n"); cat_mat(fl$exact)
cat("FIELD_LARGE_REFERENCE\n"); cat_mat(fl$reference)
cat("FIELD_LARGE_EXACT_MATCH\n"); cat(flag(fl_match), "\n", sep = "")
cat("HAND_PREDICTED\n"); cat_mat(hand$predicted)
cat("HAND_EXACT_HEAD\n"); cat_mat(hand$exact)
cat("HAND_REFERENCE\n"); cat_mat(hand$reference)
cat("HAND_MAX_ABS_ERROR\n"); cat_line(hand$err)
cat("HAND_EXACT_HEAD_MATCH\n"); cat(flag(hand$match), "\n", sep = "")
cat("SHA512_EMPTY\n"); cat(sha_empty, "\n", sep = "")
cat("SHA512_ABC\n"); cat(sha_abc, "\n", sep = "")
cat("SHA512_LONG\n"); cat(sha_long, "\n", sep = "")
cat("SEAL\n"); cat(seal, "\n", sep = "")
cat("VERIFY\n"); cat(flag(vok), "\n", sep = "")
cat("MUTATED_SEAL\n"); cat(mseal, "\n", sep = "")
cat("VERIFY_MUTATED\n"); cat(flag(vbad), "\n", sep = "")
cat("NEG_SEAL\n"); cat(nseal, "\n", sep = "")
quit(status = 0)
