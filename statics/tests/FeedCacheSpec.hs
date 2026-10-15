{-# LANGUAGE OverloadedStrings #-}

module FeedCacheSpec (feedCacheTests) where

import Control.Exception (bracket_)
import qualified Data.ByteString.Lazy as LBS
import Data.Char (isDigit)
import Data.Text (Text)
import Data.Time (addUTCTime, getCurrentTime)
import System.Directory (
    createDirectoryIfMissing,
    doesFileExist,
    getTemporaryDirectory,
    removePathForcibly,
    setModificationTime,
 )
import System.FilePath (takeDirectory, (</>))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

import Config
import FeedCache
import FeedParser
import I18n

feedCacheTests :: TestTree
feedCacheTests =
    testGroup
        "FeedCache"
        [ testCase "feedCachePath is stable and distinct per URL" $ do
            feedCachePath "c" "https://a.example/feed" @?= feedCachePath "c" "https://a.example/feed"
            assertBool "different URLs map to different files" $
                feedCachePath "c" "https://a.example/feed" /= feedCachePath "c" "https://b.example/feed"
            takeDirectory (feedCachePath "c" "https://a.example/feed") @?= "c"
        , testCase "successful fetch stores the body in the cache" $ withCacheDir "store" $ \dir -> do
            items <- fetchFeedWith (respond 200 (atomFeed "Fresh")) dir testFeed
            map itemTitle items @?= ["Fresh"]
            stored <- doesFileExist (feedCachePath dir (feedUrl testFeed))
            assertBool "cache file written" stored
        , testCase "404 falls back to the cached copy" $ withCacheDir "404" $ \dir -> do
            _ <- fetchFeedWith (respond 200 (atomFeed "Cached")) dir testFeed
            items <- fetchFeedWith (respond 404 "<html>Not Found</html>") dir testFeed
            map itemTitle items @?= ["Cached"]
        , testCase "network error falls back to the cached copy" $ withCacheDir "neterr" $ \dir -> do
            _ <- fetchFeedWith (respond 200 (atomFeed "Cached")) dir testFeed
            items <- fetchFeedWith (const (return (Left "connection refused"))) dir testFeed
            map itemTitle items @?= ["Cached"]
        , testCase "non-2xx statuses fall back to the cached copy" $ withCacheDir "status" $ \dir -> do
            _ <- fetchFeedWith (respond 200 (atomFeed "Cached")) dir testFeed
            redirect <- fetchFeedWith (respond 301 (atomFeed "Moved")) dir testFeed
            map itemTitle redirect @?= ["Cached"]
            serverError <- fetchFeedWith (respond 503 (atomFeed "Broken")) dir testFeed
            map itemTitle serverError @?= ["Cached"]
        , testCase "empty feed does not overwrite the cache" $ withCacheDir "emptyfeed" $ \dir -> do
            _ <- fetchFeedWith (respond 200 (atomFeed "Cached")) dir testFeed
            items <- fetchFeedWith (respond 200 emptyAtomFeed) dir testFeed
            map itemTitle items @?= ["Cached"]
            later <- fetchFeedWith (respond 404 "") dir testFeed
            map itemTitle later @?= ["Cached"]
        , testCase "cached copy older than maxCacheAge is ignored" $ withCacheDir "stale" $ \dir -> do
            _ <- fetchFeedWith (respond 200 (atomFeed "Old")) dir testFeed
            now <- getCurrentTime
            setModificationTime
                (feedCachePath dir (feedUrl testFeed))
                (addUTCTime (negate (maxCacheAge + 60)) now)
            items <- fetchFeedWith (respond 404 "") dir testFeed
            items @?= []
        , testCase "corrupt cached copy yields no items" $ withCacheDir "corrupt" $ \dir -> do
            createDirectoryIfMissing True dir
            LBS.writeFile (feedCachePath dir (feedUrl testFeed)) "not a feed"
            items <- fetchFeedWith (respond 404 "") dir testFeed
            items @?= []
        , testCase "unwritable cache does not break fetching" $ withCacheDir "unwritable" $ \dir -> do
            -- A plain file where the cache directory should be.
            createDirectoryIfMissing True (takeDirectory dir)
            LBS.writeFile dir ""
            items <- fetchFeedWith (respond 200 (atomFeed "Fresh")) dir testFeed
            map itemTitle items @?= ["Fresh"]
        , testCase "pruneFeedCache removes unconfigured feeds only" $ withCacheDir "prune" $ \dir -> do
            let other = "https://gone.example/feed"
            _ <- fetchFeedWith (respond 200 (atomFeed "Kept")) dir testFeed
            _ <- fetchFeedWith (respond 200 (atomFeed "Gone")) dir testFeed{feedUrl = other}
            LBS.writeFile (dir </> "leftover.1.tmp") ""
            pruneFeedCache dir [feedUrl testFeed]
            kept <- doesFileExist (feedCachePath dir (feedUrl testFeed))
            gone <- doesFileExist (feedCachePath dir other)
            leftover <- doesFileExist (dir </> "leftover.1.tmp")
            (kept, gone, leftover) @?= (True, False, False)
        , testCase "unparseable 200 does not overwrite the cache" $ withCacheDir "garbage" $ \dir -> do
            _ <- fetchFeedWith (respond 200 (atomFeed "Cached")) dir testFeed
            garbage <- fetchFeedWith (respond 200 "<html>bot check</html>") dir testFeed
            map itemTitle garbage @?= ["Cached"]
            items <- fetchFeedWith (respond 404 "") dir testFeed
            map itemTitle items @?= ["Cached"]
        , testCase "failure without a cached copy yields no items" $ withCacheDir "empty" $ \dir -> do
            items <- fetchFeedWith (respond 404 "") dir testFeed
            items @?= []
        , testCase "exclusions apply to cached items too" $ withCacheDir "exclude" $ \dir -> do
            _ <- fetchFeedWith (respond 200 (atomFeed "Spam video")) dir testFeed
            let excluding = testFeed{feedExcludeKeywords = ["spam"]}
            items <- fetchFeedWith (respond 404 "") dir excluding
            items @?= []
        ]

testFeed :: FeedConfig
testFeed =
    FeedConfig
        YouTube
        (Just "Test Channel")
        "https://www.youtube.com/feeds/videos.xml?channel_id=X"
        "fi"
        []
        []
        Nothing

respond :: Int -> LBS.ByteString -> FeedConfig -> IO (Either Text Download)
respond status body _ = return $ Right (Download status "application/atom+xml" body)

{- | Run with a fresh cache path (not yet created) that is removed afterwards,
even on failure. The clock suffix keeps concurrent suite runs apart.
-}
withCacheDir :: String -> (FilePath -> IO a) -> IO a
withCacheDir name action = do
    tmp <- getTemporaryDirectory
    stamp <- filter isDigit . show <$> getCurrentTime
    let root = tmp </> ("planet-feed-cache-test-" ++ name ++ "-" ++ stamp)
    bracket_ (return ()) (removePathForcibly root) (action (root </> "cache"))

emptyAtomFeed :: LBS.ByteString
emptyAtomFeed =
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\
    \<feed xmlns=\"http://www.w3.org/2005/Atom\">\
    \<id>urn:test</id><title>Test Channel</title><updated>2026-10-01T00:00:00Z</updated>\
    \</feed>"

atomFeed :: LBS.ByteString -> LBS.ByteString
atomFeed title =
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\
    \<feed xmlns=\"http://www.w3.org/2005/Atom\">\
    \<id>urn:test</id><title>Test Channel</title><updated>2026-10-01T00:00:00Z</updated>\
    \<entry><id>urn:test:1</id><title>"
        <> title
        <> "</title><link href=\"https://example.com/1\"/>\
           \<updated>2026-10-01T00:00:00Z</updated></entry>\
           \</feed>"
