module Config (FeedConfig (..), Config (..), parseConfig) where

import qualified Data.HashMap.Strict as HM
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Vector as V
import qualified Text.Toml as Toml

import I18n

data FeedConfig = FeedConfig
    { feedType :: FeedType
    , feedTitle :: Maybe Text
    , feedUrl :: Text
    }
    deriving (Show)

data Config = Config
    { configTitle :: Text
    , configFeeds :: [FeedConfig]
    , configLocale :: Locale
    , configTimezone :: Text
    }
    deriving (Show)

-- TOML Parsing helpers
parseConfig :: Text -> Either Text Config
parseConfig content = do
    toml <- case Toml.parseTomlDoc "config.toml" content of
        Left err -> Left $ T.pack $ show err
        Right t -> Right t

    let title = fromMaybe (T.pack "Planet") $ HM.lookup (T.pack "title") toml >>= extractText
    let localeStr = fromMaybe (T.pack "fi") $ HM.lookup (T.pack "locale") toml >>= extractText
    let locale = parseLocale localeStr
    let timezone = fromMaybe (T.pack "Europe/Helsinki") $ HM.lookup (T.pack "timezone") toml >>= extractText

    feeds <- case HM.lookup (T.pack "feeds") toml of
        Just (Toml.VTArray nodes) ->
            mapM (parseFeedConfig . Toml.VTable) (V.toList nodes)
        _ -> Right []

    return $ Config title feeds locale timezone
  where
    extractText (Toml.VString t) = Just t
    extractText _ = Nothing

    parseFeedConfig node = do
        let lookupKey k = case node of
                Toml.VTable t -> HM.lookup (T.pack k) t
                _ -> Nothing

        typeStr <- case lookupKey "type" of
            Just (Toml.VString t) -> Right t
            _ -> Right $ T.pack "rss" -- Default to "rss" if not specified
        ft <- case () of
            () | typeStr == T.pack "rss" -> Right Feed
            () | typeStr == T.pack "blog" -> Right Feed
            () | typeStr == T.pack "default" -> Right Feed
            () | typeStr == T.pack "atom" -> Right Feed
            () | typeStr == T.pack "youtube" -> Right YouTube
            () | typeStr == T.pack "flickr" -> Right Image
            () | typeStr == T.pack "kuvatfi" -> Right Image
            _ -> Left $ T.pack "Unknown feed type: " <> typeStr

        let title = case lookupKey "title" of
                Just (Toml.VString t) -> Just t
                _ -> Nothing

        url <- case lookupKey "url" of
            Just (Toml.VString t) -> Right t
            _ -> Left $ T.pack "Missing or invalid feed url"

        return $ FeedConfig ft title url
