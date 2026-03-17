{-# LANGUAGE BangPatterns #-}
-- Face enumeration from vertex-facet incidence benchmark
module Main where

import qualified Data.ByteString.Char8 as BS
import qualified Data.Set as Set
import qualified Data.Vector.Mutable as VM
import Data.Bits ((.&.), (.|.), shiftL, popCount)
import Data.Int (Int64)
import Data.Word (Word64)
import Data.IORef
import System.Environment (getArgs)
import System.Clock (getTime, Clock(Monotonic), toNanoSecs)
import Numeric (showFFloat)

data Face = Face {-# UNPACK #-} !Word64 {-# UNPACK #-} !Word64
  deriving (Eq, Ord)

emptyFace :: Face
emptyFace = Face 0 0

setBit' :: Face -> Int -> Face
setBit' (Face lo hi) v
  | v < 64    = Face (lo .|. shiftL 1 v) hi
  | otherwise = Face lo (hi .|. shiftL 1 (v - 64))

intersectFace :: Face -> Face -> Face
intersectFace (Face lo1 hi1) (Face lo2 hi2) = Face (lo1 .&. lo2) (hi1 .&. hi2)
{-# INLINE intersectFace #-}

popcountFace :: Face -> Int
popcountFace (Face lo hi) = popCount lo + popCount hi
{-# INLINE popcountFace #-}

parseLine :: BS.ByteString -> Face
parseLine !line = go line emptyFace
  where
    go !bs !face
      | BS.null bs = face
      | otherwise  = case BS.readInt (BS.dropWhile (== ' ') bs) of
          Just (!v, !rest) -> go rest (setBit' face v)
          Nothing          -> face

main :: IO ()
main = do
    args <- getArgs
    case args of
      [file] -> run file
      _ -> putStrLn "Usage: face_enum <incidence_file>"

run :: FilePath -> IO ()
run file = do
    t0 <- getTime Monotonic
    contents <- BS.readFile file

    let allLines = BS.lines contents
        headerLine = head allLines
        facetLines = take nf (tail allLines)
        (!_nv, r0) = case BS.readInt headerLine of
                       Just (!n, !r) -> (n, r)
                       Nothing -> error "parse nv"
        !nf = case BS.readInt (BS.dropWhile (== ' ') r0) of
                Just (!n, _) -> n
                Nothing -> error "parse nf"
        facets = map parseLine facetLines

    t1 <- getTime Monotonic
    let readMs = fromIntegral (toNanoSecs t1 - toNanoSecs t0) / 1e6 :: Double

    t2 <- getTime Monotonic

    -- Growable worklist using boxed mutable vector
    let initCap = max (nf * 16) 256
    wl <- VM.new initCap
    wlRef <- newIORef wl
    capRef <- newIORef initCap
    szRef <- newIORef 0
    allFacesRef <- newIORef Set.empty

    -- Helper: push a face onto the worklist (grow if needed)
    let push !face = do
          sz <- readIORef szRef
          cap <- readIORef capRef
          curWl <- readIORef wlRef
          wl' <- if sz >= cap
                 then do
                   let cap' = cap * 2
                   v' <- VM.grow curWl cap
                   writeIORef capRef cap'
                   writeIORef wlRef v'
                   return v'
                 else return curWl
          VM.write wl' sz face
          writeIORef szRef (sz + 1)
    let addFacets [] = return ()
        addFacets (f:fs) = do
          af <- readIORef allFacesRef
          if Set.member f af
            then addFacets fs
            else do
              writeIORef allFacesRef (Set.insert f af)
              push f
              addFacets fs
    addFacets facets

    -- BFS-style closure
    let processFrom !processed = do
          sz <- readIORef szRef
          if processed >= sz then return ()
          else do
            wl' <- readIORef wlRef
            current <- VM.read wl' processed
            let tryJ !j = do
                  if j > processed then processFrom (processed + 1)
                  else do
                    wl'' <- readIORef wlRef
                    other <- VM.read wl'' j
                    let inter = intersectFace current other
                    if popcountFace inter > 0
                      then do
                        af <- readIORef allFacesRef
                        if not (Set.member inter af)
                          then do
                            writeIORef allFacesRef (Set.insert inter af)
                            push inter
                            tryJ (j+1)
                          else tryJ (j+1)
                      else tryJ (j+1)
            tryJ 0
    processFrom 0

    finalSet <- readIORef allFacesRef
    let !checksum = Set.foldl' (\acc f -> acc + fromIntegral (popcountFace f)) (0 :: Int64) finalSet

    t3 <- getTime Monotonic
    let computeMs = fromIntegral (toNanoSecs t3 - toNanoSecs t2) / 1e6 :: Double

    putStrLn $ "read=" ++ showFFloat (Just 1) readMs "" ++ "ms compute="
              ++ showFFloat (Just 1) computeMs "" ++ "ms faces=" ++ show (Set.size finalSet)
              ++ " checksum=" ++ show checksum
