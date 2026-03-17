{-# LANGUAGE BangPatterns #-}
-- BFS benchmark — barebones (mutable unboxed vectors, unsafeRead/unsafeWrite)
module Main where

import qualified Data.ByteString.Char8 as BS
import qualified Data.Vector.Unboxed.Mutable as MV
import qualified Data.Vector.Unboxed as V
import Data.Int (Int64)
import System.Environment (getArgs)
import System.Clock (getTime, Clock(Monotonic), toNanoSecs)

readInt :: BS.ByteString -> (Int, BS.ByteString)
readInt !bs = case BS.readInt (BS.dropWhile (< '0') bs) of
    Just (!n, !rest) -> (n, rest)
    Nothing -> error "parse error"

main :: IO ()
main = do
    args <- getArgs
    case args of
      [file] -> run file
      _ -> putStrLn "Usage: bfs_barebones <graph_file>"

run :: FilePath -> IO ()
run file = do
    -- ── Read ─────────────────────────────────────────────────────────────
    t0 <- getTime Monotonic
    contents <- BS.readFile file

    let (!n, r0) = readInt contents
        (!m, r1) = readInt r0

    -- Count degrees
    deg <- MV.replicate n (0 :: Int)
    let readEdges !buf !rem !i
          | i >= m    = return rem
          | otherwise = do
              let (!u, r2) = readInt rem
                  (!v, r3) = readInt r2
              MV.unsafeWrite buf (2*i) u
              MV.unsafeWrite buf (2*i+1) v
              MV.unsafeRead deg u >>= MV.unsafeWrite deg u . (+1)
              MV.unsafeRead deg v >>= MV.unsafeWrite deg v . (+1)
              readEdges buf r3 (i+1)

    edgeBuf <- MV.new (2*m)
    _ <- readEdges edgeBuf r1 0

    -- Build CSR
    offset <- MV.new (n+1) :: IO (MV.IOVector Int)
    MV.unsafeWrite offset 0 0
    let buildOffset !i
          | i >= n    = return ()
          | otherwise = do
              !prev <- MV.unsafeRead offset i
              !d    <- MV.unsafeRead deg i
              MV.unsafeWrite offset (i+1) (prev + d)
              buildOffset (i+1)
    buildOffset 0

    total <- MV.unsafeRead offset n
    adj <- MV.new total :: IO (MV.IOVector Int)
    pos <- MV.replicate n (0 :: Int)

    let fillAdj !i
          | i >= m    = return ()
          | otherwise = do
              !u <- MV.unsafeRead edgeBuf (2*i)
              !v <- MV.unsafeRead edgeBuf (2*i+1)
              !ou <- MV.unsafeRead offset u
              !pu <- MV.unsafeRead pos u
              MV.unsafeWrite adj (ou+pu) v
              MV.unsafeWrite pos u (pu+1)
              !ov <- MV.unsafeRead offset v
              !pv <- MV.unsafeRead pos v
              MV.unsafeWrite adj (ov+pv) u
              MV.unsafeWrite pos v (pv+1)
              fillAdj (i+1)
    fillAdj 0

    t1 <- getTime Monotonic
    let readMs = fromIntegral (toNanoSecs t1 - toNanoSecs t0) / 1e6 :: Double

    -- ── Compute ──────────────────────────────────────────────────────────
    t2 <- getTime Monotonic

    visited <- MV.replicate n False
    dist <- MV.replicate n (0 :: Int64)
    queue <- MV.new n :: IO (MV.IOVector Int)
    MV.unsafeWrite visited 0 True
    MV.unsafeWrite queue 0 0

    let bfs !qh !qt !dsum
          | qh >= qt  = return (qt, dsum)
          | otherwise = do
              !v <- MV.unsafeRead queue qh
              !lo <- MV.unsafeRead offset v
              !hi <- MV.unsafeRead offset (v+1)
              !dv <- MV.unsafeRead dist v
              let inner !j !qt' !ds
                    | j >= hi   = bfs (qh+1) qt' ds
                    | otherwise = do
                        !w <- MV.unsafeRead adj j
                        !vis <- MV.unsafeRead visited w
                        if vis then inner (j+1) qt' ds
                        else do
                          MV.unsafeWrite visited w True
                          let !dw = dv + 1
                          MV.unsafeWrite dist w dw
                          MV.unsafeWrite queue qt' w
                          inner (j+1) (qt'+1) (ds + dw)
              inner lo qt dsum
    (!nvisited, !distSum) <- bfs 0 1 0

    t3 <- getTime Monotonic
    let computeMs = fromIntegral (toNanoSecs t3 - toNanoSecs t2) / 1e6 :: Double

    putStrLn $ "read=" ++ show readMs ++ "ms compute=" ++ show computeMs
              ++ "ms checksum=" ++ show distSum ++ " visited=" ++ show nvisited
