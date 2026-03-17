{-# LANGUAGE BangPatterns #-}

-- Point-in-convex-hull (2D) benchmark
module Main where

import qualified Data.ByteString.Char8 as BS
import Data.Int (Int64)
import qualified Data.Vector.Unboxed.Mutable as MV
import Numeric (showFFloat)
import System.Clock (Clock (Monotonic), getTime, toNanoSecs)
import System.Environment (getArgs)

readSignedInt :: BS.ByteString -> (Int64, BS.ByteString)
readSignedInt !bs =
    let !bs' = BS.dropWhile (\c -> c /= '-' && (c < '0' || c > '9')) bs
     in case BS.readInt bs' of
            Just (!n, !rest) -> (fromIntegral n, rest)
            Nothing -> error "parse error"

main :: IO ()
main = do
    args <- getArgs
    case args of
        [file] -> run file
        _ -> putStrLn "Usage: point_in_hull <polygon_file>"

run :: FilePath -> IO ()
run file = do
    -- ── Read ─────────────────────────────────────────────────────────────
    t0 <- getTime Monotonic
    contents <- BS.readFile file

    let (!np64, r0) = readSignedInt contents
        (!nq64, r1) = readSignedInt r0
        !np = fromIntegral np64 :: Int
        !nq = fromIntegral nq64 :: Int

    px <- MV.new np :: IO (MV.IOVector Int64)
    py <- MV.new np :: IO (MV.IOVector Int64)
    let readPoly !rem !i
            | i >= np = return rem
            | otherwise = do
                let (!x, r2) = readSignedInt rem
                    (!y, r3) = readSignedInt r2
                MV.write px i x
                MV.write py i y
                readPoly r3 (i + 1)
    r2 <- readPoly r1 0

    qx <- MV.new nq :: IO (MV.IOVector Int64)
    qy <- MV.new nq :: IO (MV.IOVector Int64)
    let readQueries !rem !i
            | i >= nq = return ()
            | otherwise = do
                let (!x, r3) = readSignedInt rem
                    (!y, r4) = readSignedInt r3
                MV.write qx i x
                MV.write qy i y
                readQueries r4 (i + 1)
    readQueries r2 0

    t1 <- getTime Monotonic
    let readMs = fromIntegral (toNanoSecs t1 - toNanoSecs t0) / 1e6 :: Double

    -- ── Compute ──────────────────────────────────────────────────────────
    t2 <- getTime Monotonic

    let checkQuery !q !count
            | q >= nq = return count
            | otherwise = do
                !x <- MV.read qx q
                !y <- MV.read qy q
                let checkEdge !i
                        | i >= np = return True
                        | otherwise = do
                            let !j = if i + 1 >= np then 0 else i + 1
                            !pxi <- MV.read px i
                            !pyi <- MV.read py i
                            !pxj <- MV.read px j
                            !pyj <- MV.read py j
                            let !cross = (pxj - pxi) * (y - pyi) - (pyj - pyi) * (x - pxi)
                            if cross < 0
                                then return False
                                else checkEdge (i + 1)
                !isIn <- checkEdge 0
                checkQuery (q + 1) (if isIn then count + 1 else count)
    !inside <- checkQuery 0 (0 :: Int)

    t3 <- getTime Monotonic
    let computeMs = fromIntegral (toNanoSecs t3 - toNanoSecs t2) / 1e6 :: Double

    putStrLn $
        "read="
            ++ showFFloat (Just 1) readMs ""
            ++ "ms compute="
            ++ showFFloat (Just 1) computeMs ""
            ++ "ms inside="
            ++ show inside
            ++ " total="
            ++ show nq
