{-# LANGUAGE OverloadedStrings #-}

-- | Upsert logic for syncing AppItems into PocketBase.
module PocketBaseSync
    ( UpsertAction (..)
    , SyncReport (..)
    , buildUpsertAction
    , syncItemsToPb
    , fetchAllAppItemsFromPb
    , printSyncReport
    ) where

import Control.Concurrent.Async (mapConcurrently)
import Control.Concurrent.STM
    ( STM
    , TVar
    , atomically
    , modifyTVar'
    , newTVarIO
    , readTVarIO
    )
import Data.Aeson (Value (..))
import qualified Data.Aeson.KeyMap as KM
import Data.Either (lefts, rights)
import Data.List (sortOn)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Ord (Down (..))
import Data.Text (Text)

import I18n (AppItem (..))
import PocketBase
    ( PbConfig
    , createRecord
    , decodeAppItemFromPb
    , encodeAppItemToPb
    , fetchAll
    , updateRecord
    )

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

data UpsertAction
    = Create
    | Update Text  -- existing PocketBase record id
    deriving (Show, Eq)

data SyncReport = SyncReport
    { syncCreated :: Int
    , syncUpdated :: Int
    , syncFailed  :: Int
    } deriving (Show, Eq)

-- ---------------------------------------------------------------------------
-- Pure upsert decision
-- ---------------------------------------------------------------------------

-- | Given a pre-fetched link → id map and an AppItem, determine what to do.
-- When a link appears more than once in the map, the first match wins.
buildUpsertAction :: Map Text Text -> AppItem -> UpsertAction
buildUpsertAction linkMap item =
    maybe Create Update (Map.lookup (itemLink item) linkMap)

-- ---------------------------------------------------------------------------
-- Sync
-- ---------------------------------------------------------------------------

-- | Sync a list of AppItems to PocketBase with bounded concurrency (8 workers).
syncItemsToPb :: PbConfig -> [AppItem] -> IO SyncReport
syncItemsToPb cfg items = do
    linkMap   <- buildLinkMapFromPb cfg
    let actions = map (\item -> (item, buildUpsertAction linkMap item)) items
    reportVar <- newTVarIO (SyncReport 0 0 0)
    mapM_ (executeChunk cfg reportVar) (chunksOf 8 actions)
    readTVarIO reportVar

chunksOf :: Int -> [a] -> [[a]]
chunksOf _ [] = []
chunksOf n xs = take n xs : chunksOf n (drop n xs)

executeChunk :: PbConfig -> TVar SyncReport -> [(AppItem, UpsertAction)] -> IO ()
executeChunk cfg reportVar chunk = do
    results <- mapConcurrently (executeOne cfg) chunk
    atomically $ mapM_ (applyResult reportVar) results

executeOne :: PbConfig -> (AppItem, UpsertAction) -> IO (Either String UpsertAction)
executeOne cfg (item, Create) = do
    result <- createRecord cfg "feed_items" (encodeAppItemToPb item)
    return $ case result of
        Left err -> Left err
        Right _  -> Right Create
executeOne cfg (item, Update rid) = do
    result <- updateRecord cfg "feed_items" rid (encodeAppItemToPb item)
    return $ case result of
        Left err -> Left err
        Right () -> Right (Update rid)

applyResult :: TVar SyncReport -> Either String UpsertAction -> STM ()
applyResult var (Left _)           = modifyTVar' var $ \r -> r { syncFailed  = syncFailed  r + 1 }
applyResult var (Right Create)     = modifyTVar' var $ \r -> r { syncCreated = syncCreated r + 1 }
applyResult var (Right (Update _)) = modifyTVar' var $ \r -> r { syncUpdated = syncUpdated r + 1 }

-- ---------------------------------------------------------------------------
-- Link map
-- ---------------------------------------------------------------------------

-- | Build a link → PB-record-id map from all existing feed_items records.
buildLinkMapFromPb :: PbConfig -> IO (Map Text Text)
buildLinkMapFromPb cfg = do
    vals <- fetchAll cfg "feed_items"
    return $ Map.fromListWith (\_ old -> old) $ concatMap extractLinkId vals

extractLinkId :: Value -> [(Text, Text)]
extractLinkId (Object km) =
    case (KM.lookup "link" km, KM.lookup "id" km) of
        (Just (String lnk), Just (String rid)) -> [(lnk, rid)]
        _                                       -> []
extractLinkId _ = []

-- ---------------------------------------------------------------------------
-- Fetch all AppItems from PocketBase
-- ---------------------------------------------------------------------------

-- | Fetch all feed_items records, decode each, log failures, return sorted list.
fetchAllAppItemsFromPb :: PbConfig -> IO [AppItem]
fetchAllAppItemsFromPb cfg = do
    vals <- fetchAll cfg "feed_items"
    let results  = map decodeAppItemFromPb vals
        failures = lefts  results
        items    = rights results
    mapM_ (\err -> putStrLn $ "Warning: failed to decode PB record: " <> err) failures
    return $ sortOn (Down . itemDate) items

-- ---------------------------------------------------------------------------
-- Print sync report
-- ---------------------------------------------------------------------------

printSyncReport :: SyncReport -> IO ()
printSyncReport r = do
    putStrLn "PocketBase sync complete:"
    putStrLn $ "  Created: " <> show (syncCreated r)
    putStrLn $ "  Updated: " <> show (syncUpdated r)
    putStrLn $ "  Failed:  " <> show (syncFailed  r)
