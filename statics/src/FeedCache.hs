{- | On-disk cache of the last successfully parsed body of each feed.

Some upstreams (notably YouTube) answer 404 for hours at a time. The
generator stores every good response here and falls back to it when a
fetch fails. CI persists the directory between runs with actions/cache.
-}
module FeedCache (
    feedCachePath,
    pruneFeedCache,
    readFeedCache,
    writeFeedCache,
) where

import Control.Concurrent (myThreadId)
import Control.Exception (IOException, try)
import Control.Monad (forM_, when)
import Data.Bits (xor)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as LBS
import Data.Char (isDigit)
import Data.List (isSuffixOf)
import Data.Text (Text)
import Data.Text.Encoding (encodeUtf8)
import Data.Time (UTCTime)
import Data.Word (Word64)
import System.Directory (
    createDirectoryIfMissing,
    doesDirectoryExist,
    doesFileExist,
    getModificationTime,
    listDirectory,
    removeFile,
    renameFile,
 )
import System.FilePath (takeDirectory, (<.>), (</>))
import Text.Printf (printf)

{- | Cache file for a feed URL: a stable FNV-1a hash keeps names short and
filesystem-safe whatever the URL contains.
-}
feedCachePath :: FilePath -> Text -> FilePath
feedCachePath cacheDir url = cacheDir </> printf "%016x" (fnv1a64 (encodeUtf8 url)) <.> "xml"

fnv1a64 :: BS.ByteString -> Word64
fnv1a64 = BS.foldl' step 0xcbf29ce484222325
  where
    step h b = (h `xor` fromIntegral b) * 0x100000001b3

-- | The cached body and when it was stored, if a readable copy exists.
readFeedCache :: FilePath -> IO (Maybe (UTCTime, LBS.ByteString))
readFeedCache path = do
    exists <- doesFileExist path
    if not exists
        then return Nothing
        else do
            result <- try $ do
                body <- BS.readFile path
                stamp <- getModificationTime path
                return (stamp, LBS.fromStrict body)
            return $ either (const Nothing) Just (result :: Either IOException (UTCTime, LBS.ByteString))

{- | Store a body atomically (write + rename) so an interrupted run never
leaves a truncated copy behind. The temp name is unique per thread in
case one URL is fetched twice concurrently. Failures are reported, not
thrown: a broken cache must not break the build.
-}
writeFeedCache :: FilePath -> LBS.ByteString -> IO ()
writeFeedCache path body = do
    threadNo <- filter isDigit . show <$> myThreadId
    let tmp = path <.> threadNo <.> "tmp"
    result <- try $ do
        createDirectoryIfMissing True (takeDirectory path)
        LBS.writeFile tmp body
        renameFile tmp path
    case result :: Either IOException () of
        Left err -> putStrLn $ "Warning: could not write feed cache " ++ path ++ ": " ++ show err
        Right () -> return ()

{- | Remove cached copies of feeds no longer configured (and leftover temp
files), so the directory persisted by CI does not grow without bound.
-}
pruneFeedCache :: FilePath -> [Text] -> IO ()
pruneFeedCache cacheDir urls = do
    exists <- doesDirectoryExist cacheDir
    when exists $ do
        let keep = map (feedCachePath cacheDir) urls
        files <- map (cacheDir </>) <$> listDirectory cacheDir
        forM_ files $ \file ->
            when ((".xml" `isSuffixOf` file || ".tmp" `isSuffixOf` file) && file `notElem` keep) $ do
                result <- try (removeFile file)
                case result :: Either IOException () of
                    Left err -> putStrLn $ "Warning: could not prune feed cache " ++ file ++ ": " ++ show err
                    Right () -> putStrLn $ "Pruned stale feed cache " ++ file
