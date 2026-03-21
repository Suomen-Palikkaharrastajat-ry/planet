{-# LANGUAGE OverloadedStrings #-}

module Planet (main) where

import Control.Concurrent.Async (mapConcurrently)
import qualified Data.ByteString.Lazy as LBS
import Data.List (sortOn)
import qualified Data.Map as Map
import Data.Maybe (fromMaybe)
import Data.Ord (Down (..))
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import qualified Data.Text.Lazy as LT
import qualified Data.Text.Lazy.Encoding as LT
import System.Directory (createDirectoryIfMissing)
import qualified Text.XML as XML

import Config
import ElmGen
import FeedParser
import I18n

generateOpml :: Config -> LT.Text
generateOpml config =
    XML.renderText XML.def $
        XML.Document
            { XML.documentPrologue = XML.Prologue [] Nothing []
            , XML.documentRoot =
                XML.Element
                    { XML.elementName = XML.Name "opml" Nothing (Just "http://www.opml.org/spec2")
                    , XML.elementAttributes = Map.fromList [(XML.Name "version" Nothing Nothing, "2.0")]
                    , XML.elementNodes =
                        [ XML.NodeElement $
                            XML.Element
                                { XML.elementName = XML.Name "head" Nothing Nothing
                                , XML.elementAttributes = Map.empty
                                , XML.elementNodes =
                                    [ XML.NodeElement $
                                        XML.Element
                                            { XML.elementName = XML.Name "title" Nothing Nothing
                                            , XML.elementAttributes = Map.empty
                                            , XML.elementNodes = [XML.NodeContent $ configTitle config]
                                            }
                                    ]
                                }
                        , XML.NodeElement $
                            XML.Element
                                { XML.elementName = XML.Name "body" Nothing Nothing
                                , XML.elementAttributes = Map.empty
                                , XML.elementNodes = map feedToOutline (configFeeds config)
                                }
                        ]
                    }
            , XML.documentEpilogue = []
            }

feedToOutline :: FeedConfig -> XML.Node
feedToOutline feed =
    XML.NodeElement $
        XML.Element
            { XML.elementName = XML.Name "outline" Nothing Nothing
            , XML.elementAttributes =
                Map.fromList
                    [ (XML.Name "type" Nothing Nothing, "rss")
                    , (XML.Name "text" Nothing Nothing, fromMaybe (feedUrl feed) (feedTitle feed))
                    , (XML.Name "xmlUrl" Nothing Nothing, feedUrl feed)
                    ]
            , XML.elementNodes = []
            }

main :: IO ()
main = do
    configContent <- TIO.readFile "planet.toml"
    case parseConfig configContent of
        Left err -> TIO.putStrLn $ "Error parsing configuration: " <> err
        Right config -> do
            putStrLn $ "Generating planet for: " ++ T.unpack (configTitle config)
            putStrLn $ "Locale: " ++ show (configLocale config)
            putStrLn $ "Found " ++ show (length $ configFeeds config) ++ " feeds."

            -- Fetch feeds concurrently
            allItems <- concat <$> mapConcurrently fetchFeed (configFeeds config)

            -- Sort by date descending
            let sortedItems = sortOn (Down . itemDate) allItems

            let elmModule = generateElmModule sortedItems

            -- Generate search index
            let searchIndex = generateSearchIndex sortedItems
            createDirectoryIfMissing True "elm-app/public"
            LBS.writeFile "elm-app/public/search-index.json" searchIndex
            putStrLn "Search index generated in elm-app/public/search-index.json"

            -- Generate OPML export
            let opmlContent = generateOpml config
            LBS.writeFile "elm-app/public/opml.xml" $ LT.encodeUtf8 opmlContent
            putStrLn "OPML export generated in elm-app/public/opml.xml"

            -- No longer creating public/data.json
            createDirectoryIfMissing True "elm-app/src"
            TIO.writeFile "elm-app/src/Data.elm" elmModule
            putStrLn "Elm data module generated in elm-app/src/Data.elm"
