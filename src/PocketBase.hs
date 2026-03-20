{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# OPTIONS_GHC -Wno-orphans #-}

-- | HTTP client for PocketBase REST API.
-- Authentication is via a bearer API token (PocketBase >= 0.22).
module PocketBase
    ( PbConfig (..)
    , PbList (..)
    , loadPbConfig
    , authHeaders
    , fetchPage
    , fetchAll
    , createRecord
    , updateRecord
    , lookupByLink
    , decodeAppItemFromPb
    , encodeAppItemToPb
    , urlEncodeFilter
    ) where

import Data.Aeson
    ( FromJSON (..)
    , Value (..)
    , eitherDecode
    , encode
    , object
    , withObject
    , (.:)
    , (.:?)
    , (.=)
    )
import Data.Aeson.Types (fromJSON, Result (..))
import qualified Data.Aeson.KeyMap as KM
import qualified Data.ByteString.Char8 as BS8
import Data.Char (isAlphaNum, ord, toUpper)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time.Format.ISO8601 (iso8601ParseM)
import GHC.Generics (Generic)
import Network.HTTP.Simple
    ( addRequestHeader
    , getResponseBody
    , getResponseStatusCode
    , httpLBS
    , parseRequest
    , setRequestBodyLBS
    )
import Network.HTTP.Types (Header, hAuthorization, hContentType)
import System.Environment (lookupEnv)

import I18n (AppItem (..), FeedType (..))

-- ---------------------------------------------------------------------------
-- Config
-- ---------------------------------------------------------------------------

data PbConfig = PbConfig
    { pbBaseUrl  :: Text  -- e.g. "http://localhost:8090"
    , pbApiToken :: Text  -- superuser bearer token
    }

-- | Read PocketBase config from environment variables.
-- Returns Nothing if POCKETBASE_URL or POCKETBASE_API_KEY is absent.
loadPbConfig :: IO (Maybe PbConfig)
loadPbConfig = do
    url <- lookupEnv "POCKETBASE_URL"
    key <- lookupEnv "POCKETBASE_API_KEY"
    return $ PbConfig . T.pack <$> url <*> (T.pack <$> key)

-- ---------------------------------------------------------------------------
-- Auth
-- ---------------------------------------------------------------------------

authHeaders :: PbConfig -> [Header]
authHeaders cfg =
    [ (hAuthorization, "Bearer " <> TE.encodeUtf8 (pbApiToken cfg))
    , (hContentType,   "application/json")
    ]

-- ---------------------------------------------------------------------------
-- PbList — envelope returned by PocketBase list endpoints
-- ---------------------------------------------------------------------------

data PbList a = PbList
    { pbItems      :: [a]
    , pbTotalItems :: Int
    , pbPage       :: Int
    , pbPerPage    :: Int
    } deriving (Show, Eq, Generic)

instance FromJSON a => FromJSON (PbList a) where
    parseJSON = withObject "PbList" $ \o ->
        PbList
            <$> o .: "items"
            <*> o .: "totalItems"
            <*> o .: "page"
            <*> o .: "perPage"

-- ---------------------------------------------------------------------------
-- Low-level HTTP helpers
-- ---------------------------------------------------------------------------

collectionUrl :: PbConfig -> Text -> Text
collectionUrl cfg col =
    pbBaseUrl cfg <> "/api/collections/" <> col <> "/records"

-- | Fetch one page of records (up to 500) from a collection.
fetchPage :: PbConfig -> Text -> Int -> IO (PbList Value)
fetchPage cfg col pageNum = do
    let url = T.unpack $
                  collectionUrl cfg col
                  <> "?perPage=500&page=" <> T.pack (show pageNum)
                  <> "&sort=-pub_date"
    req0 <- parseRequest url
    let req = foldr (uncurry addRequestHeader) req0 (authHeaders cfg)
    resp <- httpLBS req
    let body = getResponseBody resp
    case eitherDecode body of
        Left err  -> fail $ "fetchPage decode error: " <> err
        Right lst -> return lst

-- | Fetch ALL records by paginating until exhausted.
fetchAll :: PbConfig -> Text -> IO [Value]
fetchAll cfg col = go 1 []
  where
    go pageNum acc = do
        lst <- fetchPage cfg col pageNum
        let collected = acc ++ pbItems lst
        if length collected >= pbTotalItems lst || null (pbItems lst)
            then return collected
            else go (pageNum + 1) collected

-- | POST a new record; returns the PocketBase record id on success.
createRecord :: PbConfig -> Text -> Value -> IO (Either String Text)
createRecord cfg col body = do
    let url = T.unpack $ collectionUrl cfg col
    req0 <- parseRequest ("POST " <> url)
    let req  = foldr (uncurry addRequestHeader) req0 (authHeaders cfg)
        req' = setRequestBodyLBS (encode body) req
    resp <- httpLBS req'
    let code     = getResponseStatusCode resp
        respBody = getResponseBody resp
    if code >= 200 && code < 300
        then case eitherDecode respBody :: Either String Value of
                 Left err -> return $ Left $ "createRecord decode: " <> err
                 Right (Object km) ->
                     case KM.lookup "id" km of
                         Just (String i) -> return $ Right i
                         _               -> return $ Left "createRecord: no id in response"
                 Right _ -> return $ Left "createRecord: unexpected response shape"
        else return $ Left $ "createRecord HTTP " <> show code

-- | PATCH an existing record by id.
updateRecord :: PbConfig -> Text -> Text -> Value -> IO (Either String ())
updateRecord cfg col recId body = do
    let url = T.unpack $ collectionUrl cfg col <> "/" <> recId
    req0 <- parseRequest ("PATCH " <> url)
    let req  = foldr (uncurry addRequestHeader) req0 (authHeaders cfg)
        req' = setRequestBodyLBS (encode body) req
    resp <- httpLBS req'
    let code = getResponseStatusCode resp
    if code >= 200 && code < 300
        then return $ Right ()
        else return $ Left $ "updateRecord HTTP " <> show code

-- | Look up a record by its link field; returns the PB record id if found.
lookupByLink :: PbConfig -> Text -> Text -> IO (Maybe Text)
lookupByLink cfg col link = do
    let filterStr = "link=\"" <> link <> "\""
        encoded   = urlEncodeFilter filterStr
        url = T.unpack $
                  collectionUrl cfg col
                  <> "?filter=" <> encoded
                  <> "&perPage=1&fields=id,link"
    req0 <- parseRequest url
    let req = foldr (uncurry addRequestHeader) req0 (authHeaders cfg)
    resp <- httpLBS req
    let code = getResponseStatusCode resp
    if code /= 200
        then return Nothing
        else case eitherDecode (getResponseBody resp) :: Either String (PbList Value) of
                 Left _    -> return Nothing
                 Right lst ->
                     case pbItems lst of
                         (Object km : _) ->
                             case KM.lookup "id" km of
                                 Just (String i) -> return $ Just i
                                 _               -> return Nothing
                         _ -> return Nothing

-- ---------------------------------------------------------------------------
-- AppItem <-> PocketBase JSON
-- ---------------------------------------------------------------------------

feedTypeText :: FeedType -> Text
feedTypeText Feed    = "feed"
feedTypeText YouTube = "youtube"
feedTypeText Image   = "image"

parseFeedType :: Text -> Either String FeedType
parseFeedType "feed"    = Right Feed
parseFeedType "youtube" = Right YouTube
parseFeedType "image"   = Right Image
parseFeedType t         = Left $ "Unknown feed_type: " <> T.unpack t

encodeAppItemToPb :: AppItem -> Value
encodeAppItemToPb item = object $
    [ "link"         .= itemLink item
    , "title"        .= itemTitle item
    , "source_title" .= itemSourceTitle item
    , "feed_type"    .= feedTypeText (itemType item)
    ]
    <> maybe [] (\d -> ["pub_date"     .= T.pack (show d)]) (itemDate item)
    <> maybe [] (\h -> ["desc_html"    .= h]) (itemDesc item)
    <> maybe [] (\t -> ["desc_text"    .= t]) (itemDescText item)
    <> maybe [] (\s -> ["desc_snippet" .= s]) (itemDescSnippet item)
    <> maybe [] (\th -> ["thumbnail"   .= th]) (itemThumbnail item)
    <> maybe [] (\sl -> ["source_link" .= sl]) (itemSourceLink item)

decodeAppItemFromPb :: Value -> Either String AppItem
decodeAppItemFromPb val =
    case fromJSON val of
        Error   err  -> Left err
        Success item -> Right item

instance FromJSON AppItem where
    parseJSON = withObject "AppItem" $ \o -> do
        link        <- o .:  "link"
        title       <- o .:  "title"
        sourceTitle <- o .:  "source_title"
        feedTypeStr <- o .:  "feed_type"
        feedType    <- case parseFeedType feedTypeStr of
                           Left err -> fail err
                           Right ft -> return ft
        pubDateStr  <- o .:? "pub_date"
        let mDate = pubDateStr >>= \s ->
                        if T.null s
                            then Nothing
                            else iso8601ParseM (T.unpack s)
        descHtml    <- o .:? "desc_html"
        descText    <- o .:? "desc_text"
        descSnippet <- o .:? "desc_snippet"
        thumbnail   <- o .:? "thumbnail"
        sourceLink  <- o .:? "source_link"
        return $ AppItem
            { itemTitle       = title
            , itemLink        = link
            , itemDate        = mDate
            , itemDesc        = descHtml
            , itemDescText    = descText
            , itemDescSnippet = descSnippet
            , itemThumbnail   = thumbnail
            , itemSourceTitle = sourceTitle
            , itemSourceLink  = sourceLink
            , itemType        = feedType
            }

-- ---------------------------------------------------------------------------
-- URL encoding for PocketBase filter strings
-- ---------------------------------------------------------------------------

-- | Percent-encode a PocketBase filter string.
-- Keeps alphanumeric and '-', '_', '.', '~' unencoded; everything else becomes %HH.
--
-- >>> urlEncodeFilter "link=\"https://example.com\""
-- "link%3D%22https%3A%2F%2Fexample.com%22"
urlEncodeFilter :: Text -> Text
urlEncodeFilter = T.concatMap encodeChar
  where
    encodeChar c
        | isAlphaNum c || c `elem` ("-_.~" :: String) = T.singleton c
        | otherwise =
            let bytes = BS8.unpack $ TE.encodeUtf8 $ T.singleton c
            in T.concat $ map pctEncode bytes

    pctEncode :: Char -> Text
    pctEncode c =
        let n  = ord c
            hi = toHexDigit (n `div` 16)
            lo = toHexDigit (n `mod` 16)
        in T.pack ['%', hi, lo]

    toHexDigit :: Int -> Char
    toHexDigit n
        | n < 10    = toEnum (n + fromEnum '0')
        | otherwise = toEnum (n - 10 + fromEnum 'A')
