{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Test.Tasty (defaultMain, testGroup)

import ConfigSpec (configTests)
import ElmGenSpec (elmGenTests)
import FeedParserSpec (feedParserTests)
import HtmlSanitizerSpec (htmlSanitizerTests)
import I18nSpec (i18nTests)
import PlanetSpec (planetTests)

main :: IO ()
main =
    defaultMain $
        testGroup
            "Planet Tests"
            [ configTests
            , i18nTests
            , feedParserTests
            , elmGenTests
            , htmlSanitizerTests
            , planetTests
            ]
