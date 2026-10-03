# SHA-512 (FIPS 180-4) and the bi-encoder DAG seal.
# A word is four uint16 limbs, most-significant limb first. Limbs stay in
# 0..65535 so R bitwShiftL never overflows a signed 32-bit integer
# (bit 31 of a uint32 is R's NA_integer_ and cannot be used with bitw*).
#
# Canonical node preimage, big-endian, no JSON, no floats:
#   8 bytes ASCII "SRANOD01"
#   uint32be role_len, then that many ASCII bytes of the role
#   uint32be rank, then rank uint32be dimensions
#   uint32be count (product of the dimensions; rank 0 has count 1)
#   count integers in row-major order (last axis fastest). Each is
#     uint32be nbytes, then nbytes of ASCII decimal:
#     optional leading "-", no "+", no leading zeros, zero is "0"
# Node digest = SHA-512 of that preimage (64 bytes).
#
# DAG preimage:
#   8 bytes ASCII "SRADAG01"
#   uint32be child count
#   that many raw 64-byte digests, fixed order:
#     exact_head, predicted, weights, prime
# The seal is the lowercase hex SHA-512 of the DAG preimage.
# verify recomputes the seal from the tensors and compares.

userlib <- path.expand("~/R/library")
if (dir.exists(userlib)) .libPaths(c(userlib, .libPaths()))
suppressPackageStartupMessages(library(gmp))

NIST_EMPTY <- "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"
NIST_ABC <- "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
NIST_LONG <- "8e959b75dae313da8cf4f72814fc143f8f7779c6eb9f7fa17299aeadb6889018501d289e4900f7e4331b99dec4b5433ac7d329eeb6dd26545e96e55b874be909"
NIST_LONG_MSG <- "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu"

hex_word <- function(s) {
  dig <- c(0:9, 10:15)
  names(dig) <- strsplit("0123456789abcdef", "", fixed = TRUE)[[1]]
  chars <- strsplit(s, "", fixed = TRUE)[[1]]
  limbs <- integer(4)
  for (i in 1:4) {
    v <- 0L
    for (k in 1:4) v <- v * 16L + dig[[chars[(i - 1L) * 4L + k]]]
    limbs[i] <- v
  }
  limbs
}

H512 <- lapply(c(
  "6a09e667f3bcc908",
  "bb67ae8584caa73b",
  "3c6ef372fe94f82b",
  "a54ff53a5f1d36f1",
  "510e527fade682d1",
  "9b05688c2b3e6c1f",
  "1f83d9abfb41bd6b",
  "5be0cd19137e2179"
), hex_word)

K512 <- lapply(c(
  "428a2f98d728ae22",
  "7137449123ef65cd",
  "b5c0fbcfec4d3b2f",
  "e9b5dba58189dbbc",
  "3956c25bf348b538",
  "59f111f1b605d019",
  "923f82a4af194f9b",
  "ab1c5ed5da6d8118",
  "d807aa98a3030242",
  "12835b0145706fbe",
  "243185be4ee4b28c",
  "550c7dc3d5ffb4e2",
  "72be5d74f27b896f",
  "80deb1fe3b1696b1",
  "9bdc06a725c71235",
  "c19bf174cf692694",
  "e49b69c19ef14ad2",
  "efbe4786384f25e3",
  "0fc19dc68b8cd5b5",
  "240ca1cc77ac9c65",
  "2de92c6f592b0275",
  "4a7484aa6ea6e483",
  "5cb0a9dcbd41fbd4",
  "76f988da831153b5",
  "983e5152ee66dfab",
  "a831c66d2db43210",
  "b00327c898fb213f",
  "bf597fc7beef0ee4",
  "c6e00bf33da88fc2",
  "d5a79147930aa725",
  "06ca6351e003826f",
  "142929670a0e6e70",
  "27b70a8546d22ffc",
  "2e1b21385c26c926",
  "4d2c6dfc5ac42aed",
  "53380d139d95b3df",
  "650a73548baf63de",
  "766a0abb3c77b2a8",
  "81c2c92e47edaee6",
  "92722c851482353b",
  "a2bfe8a14cf10364",
  "a81a664bbc423001",
  "c24b8b70d0f89791",
  "c76c51a30654be30",
  "d192e819d6ef5218",
  "d69906245565a910",
  "f40e35855771202a",
  "106aa07032bbd1b8",
  "19a4c116b8d2d0c8",
  "1e376c085141ab53",
  "2748774cdf8eeb99",
  "34b0bcb5e19b48a8",
  "391c0cb3c5c95a63",
  "4ed8aa4ae3418acb",
  "5b9cca4f7763e373",
  "682e6ff3d6b2b8a3",
  "748f82ee5defb2fc",
  "78a5636f43172f60",
  "84c87814a1f0ab72",
  "8cc702081a6439ec",
  "90befffa23631e28",
  "a4506cebde82bde9",
  "bef9a3f7b2c67915",
  "c67178f2e372532b",
  "ca273eceea26619c",
  "d186b8c721c0c207",
  "eada7dd6cde0eb1e",
  "f57d4f7fee6ed178",
  "06f067aa72176fba",
  "0a637dc5a2c898a6",
  "113f9804bef90dae",
  "1b710b35131c471b",
  "28db77f523047d84",
  "32caab7b40c72493",
  "3c9ebe0a15c9bebc",
  "431d67c49c100d4c",
  "4cc5d4becb3e42b6",
  "597f299cfc657e2a",
  "5fcb6fab3ad6faec",
  "6c44198c4a475817"
), hex_word)

addw <- function(a, b) {
  out <- integer(4)
  carry <- 0L
  for (i in 4:1) {
    s <- a[i] + b[i] + carry
    out[i] <- bitwAnd(s, 65535L)
    carry <- bitwShiftR(s, 16L)
  }
  out
}

shlw <- function(a, n) {
  if (n <= 0L) return(a)
  if (n >= 64L) return(c(0L, 0L, 0L, 0L))
  limb <- as.integer(n %/% 16L)
  bit <- as.integer(n %% 16L)
  src <- c(0L, 0L, 0L, 0L)
  if (limb < 4L) {
    for (i in seq_len(4L - limb)) src[i] <- a[i + limb]
  }
  if (bit == 0L) return(src)
  ext <- c(src, 0L)
  out <- integer(4)
  shift_down <- 16L - bit
  for (i in 1:4) {
    low_from_next <- bitwShiftR(ext[i + 1L], shift_down)
    out[i] <- bitwAnd(bitwShiftL(ext[i], bit) + low_from_next, 65535L)
  }
  out
}

shrw <- function(a, n) {
  if (n <= 0L) return(a)
  if (n >= 64L) return(c(0L, 0L, 0L, 0L))
  limb <- as.integer(n %/% 16L)
  bit <- as.integer(n %% 16L)
  src <- c(0L, 0L, 0L, 0L)
  if (limb < 4L) {
    for (i in (limb + 1L):4L) src[i] <- a[i - limb]
  }
  if (bit == 0L) return(src)
  out <- integer(4)
  prev <- 0L
  mask <- bitwShiftL(1L, bit) - 1L
  up <- 16L - bit
  for (i in 1:4) {
    v <- src[i]
    high <- bitwShiftL(bitwAnd(prev, mask), up)
    out[i] <- bitwAnd(bitwShiftR(v, bit) + high, 65535L)
    prev <- v
  }
  out
}

rotrw <- function(a, n) {
  n <- as.integer(n %% 64L)
  if (n == 0L) return(a)
  bitwOr(shrw(a, n), shlw(a, 64L - n))
}

notw <- function(a) bitwXor(a, 65535L)
andw <- function(a, b) bitwAnd(a, b)
xorw <- function(a, b) bitwXor(a, b)

pack8 <- function(b) {
  b <- as.integer(b)
  c(
    bitwOr(bitwShiftL(b[1], 8L), b[2]),
    bitwOr(bitwShiftL(b[3], 8L), b[4]),
    bitwOr(bitwShiftL(b[5], 8L), b[6]),
    bitwOr(bitwShiftL(b[7], 8L), b[8])
  )
}

be8 <- function(w) {
  out <- integer(8)
  k <- 1L
  for (i in 1:4) {
    out[k] <- bitwShiftR(w[i], 8L)
    out[k + 1L] <- bitwAnd(w[i], 255L)
    k <- k + 2L
  }
  as.raw(out)
}

sha512_raw <- function(msg) {
  if (!is.raw(msg)) stop("sha512_raw expects raw", call. = FALSE)
  nb <- length(msg)
  bitlen <- nb * 8
  base <- nb + 1L
  z <- as.integer((112L - (base %% 128L)) %% 128L)
  total <- base + z + 16L
  buf <- raw(total)
  if (nb > 0L) buf[seq_len(nb)] <- msg
  buf[nb + 1L] <- as.raw(128L)
  bl <- bitlen
  for (i in total:(total - 15L)) {
    buf[i] <- as.raw(bl %% 256)
    bl <- bl %/% 256
  }
  if ((total %% 128L) != 0L) stop("PAD_FAIL", call. = FALSE)
  mint <- as.integer(buf)
  nblk <- total %/% 128L
  state <- H512
  for (bi in seq_len(nblk)) {
    off <- (bi - 1L) * 128L
    blk <- mint[(off + 1L):(off + 128L)]
    ws <- vector("list", 80L)
    for (j in 0:15) {
      o <- 8L * j
      ws[[j + 1L]] <- pack8(blk[(o + 1L):(o + 8L)])
    }
    for (i in 16:79) {
      w15 <- ws[[i - 14L]]
      w2 <- ws[[i - 1L]]
      w16 <- ws[[i - 15L]]
      w7 <- ws[[i - 6L]]
      s0 <- xorw(xorw(rotrw(w15, 1L), rotrw(w15, 8L)), shrw(w15, 7L))
      s1 <- xorw(xorw(rotrw(w2, 19L), rotrw(w2, 61L)), shrw(w2, 6L))
      ws[[i + 1L]] <- addw(addw(addw(w16, s0), w7), s1)
    }
    a <- state[[1L]]
    b <- state[[2L]]
    c <- state[[3L]]
    d <- state[[4L]]
    e <- state[[5L]]
    f <- state[[6L]]
    g <- state[[7L]]
    h <- state[[8L]]
    for (i in 0:79) {
      s1 <- xorw(xorw(rotrw(e, 14L), rotrw(e, 18L)), rotrw(e, 41L))
      chv <- xorw(andw(e, f), andw(notw(e), g))
      t1 <- addw(addw(addw(addw(h, s1), chv), K512[[i + 1L]]), ws[[i + 1L]])
      s0 <- xorw(xorw(rotrw(a, 28L), rotrw(a, 34L)), rotrw(a, 39L))
      maj <- xorw(xorw(andw(a, b), andw(a, c)), andw(b, c))
      t2 <- addw(s0, maj)
      h <- g
      g <- f
      f <- e
      e <- addw(d, t1)
      d <- c
      c <- b
      b <- a
      a <- addw(t1, t2)
    }
    state[[1L]] <- addw(state[[1L]], a)
    state[[2L]] <- addw(state[[2L]], b)
    state[[3L]] <- addw(state[[3L]], c)
    state[[4L]] <- addw(state[[4L]], d)
    state[[5L]] <- addw(state[[5L]], e)
    state[[6L]] <- addw(state[[6L]], f)
    state[[7L]] <- addw(state[[7L]], g)
    state[[8L]] <- addw(state[[8L]], h)
  }
  out <- raw(0)
  for (w in state) out <- c(out, be8(w))
  out
}

raw_hex <- function(r) paste0(sprintf("%02x", as.integer(r)), collapse = "")

sha512_hex <- function(msg) raw_hex(sha512_raw(msg))

u32be_raw <- function(v) {
  v <- as.numeric(v)
  as.raw(c(
    (v %/% 16777216) %% 256,
    (v %/% 65536) %% 256,
    (v %/% 256) %% 256,
    v %% 256
  ))
}

node_raw <- function(role, tensor) {
  if (!inherits(tensor, "bigz")) stop(paste("NOT_BIGZ", role), call. = FALSE)
  if (is.null(dim(tensor))) {
    rank <- 0L
    dims <- integer(0)
    dec <- as.character(tensor)
  } else if (length(dim(tensor)) == 2L) {
    rank <- 2L
    dims <- as.integer(dim(tensor))
    dec <- c(t(as.character(tensor)))
  } else {
    stop("rank not supported", call. = FALSE)
  }
  if (any(grepl("[^0-9-]", dec))) stop("bad decimal", call. = FALSE)
  role_raw <- charToRaw(role)
  lens <- nchar(dec, type = "bytes")
  total <- 8L + 4L + length(role_raw) + 4L + 4L * rank + 4L + sum(lens + 4L)
  buf <- raw(total)
  pos <- 1L
  put <- function(r) {
    n <- length(r)
    if (n == 0L) return()
    buf[pos:(pos + n - 1L)] <<- r
    pos <<- pos + n
  }
  put(charToRaw("SRANOD01"))
  put(u32be_raw(length(role_raw)))
  put(role_raw)
  put(u32be_raw(rank))
  for (d in dims) put(u32be_raw(d))
  put(u32be_raw(length(dec)))
  for (i in seq_along(dec)) {
    put(u32be_raw(lens[i]))
    put(charToRaw(dec[i]))
  }
  if (pos != total + 1L) stop(paste("encode length", pos, total), call. = FALSE)
  buf
}

dag_raw <- function(digests) {
  n <- length(digests)
  buf <- raw(8L + 4L + 64L * n)
  buf[1:8] <- charToRaw("SRADAG01")
  buf[9:12] <- u32be_raw(n)
  pos <- 13L
  for (d in digests) {
    if (length(d) != 64L) stop("digest len", call. = FALSE)
    buf[pos:(pos + 63L)] <- d
    pos <- pos + 64L
  }
  buf
}

dag_seal_hex <- function(exact, predicted, weights, prime) {
  d1 <- sha512_raw(node_raw("exact_head", exact))
  d2 <- sha512_raw(node_raw("predicted", predicted))
  d3 <- sha512_raw(node_raw("weights", weights))
  d4 <- sha512_raw(node_raw("prime", prime))
  raw_hex(sha512_raw(dag_raw(list(d1, d2, d3, d4))))
}

verify_dag <- function(claimed, exact, predicted, weights, prime) {
  identical(claimed, dag_seal_hex(exact, predicted, weights, prime))
}

sha512_selftest <- function() {
  e <- sha512_hex(raw())
  a <- sha512_hex(charToRaw("abc"))
  g <- sha512_hex(charToRaw(NIST_LONG_MSG))
  if (!identical(e, NIST_EMPTY) || !identical(a, NIST_ABC) || !identical(g, NIST_LONG)) {
    stop(paste("SHA512_SELFTEST_FAIL", e, a, g), call. = FALSE)
  }
  invisible(TRUE)
}

sha512_selftest()
if (sys.nframe() == 0L) quit(status = 0L)
