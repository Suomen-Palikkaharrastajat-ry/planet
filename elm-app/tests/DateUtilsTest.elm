module DateUtilsTest exposing (suite)

{-| Tests for DateUtils module

-}

import Data exposing (AppItem, FeedType(..))
import DateUtils exposing (extractYearMonth, formatDate, formatMonthLabel, groupByMonth)
import Expect
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "DateUtils module"
        [ describe "extractYearMonth"
            [ test "extracts year-month from ISO date" <|
                \_ ->
                    Expect.equal "2026-01" (extractYearMonth "2026-01-08T19:27:04Z")
            , test "handles short dates" <|
                \_ ->
                    Expect.equal "2026-01" (extractYearMonth "2026-01-08")
            ]
        , describe "formatDate"
            [ test "formats ISO date to YYYY-MM-DD" <|
                \_ ->
                    Expect.equal "2026-01-08" (formatDate "2026-01-08T19:27:04Z")
            , test "handles already formatted dates" <|
                \_ ->
                    Expect.equal "2026-01-08" (formatDate "2026-01-08")
            ]
        , describe "formatMonthLabel"
            [ test "formats January in Finnish" <|
                \_ ->
                    Expect.equal "tammikuu 2026" (formatMonthLabel "2026-01-08T19:27:04Z")
            , test "formats February in Finnish" <|
                \_ ->
                    Expect.equal "helmikuu 2026" (formatMonthLabel "2026-02-15T10:00:00Z")
            , test "formats December in Finnish" <|
                \_ ->
                    Expect.equal "joulukuu 2025" (formatMonthLabel "2025-12-25T00:00:00Z")
            , test "handles invalid month" <|
                \_ ->
                    Expect.equal "Tuntematon 2026" (formatMonthLabel "2026-99-99T00:00:00Z")
            ]
        , describe "groupByMonth"
            [ test "groups items by month" <|
                \_ ->
                    let
                        items =
                            [ createTestItem "2026-01-08T19:27:04Z"
                            , createTestItem "2026-01-07T10:00:00Z"
                            , createTestItem "2025-12-25T12:00:00Z"
                            ]

                        groups =
                            groupByMonth items
                    in
                    Expect.equal 2 (List.length groups)
            , test "handles items without dates" <|
                \_ ->
                    let
                        items =
                            [ createTestItemNoDate
                            ]

                        groups =
                            groupByMonth items

                        firstGroup =
                            List.head groups
                    in
                    case firstGroup of
                        Just group ->
                            -- When there's no date, the monthKey is "0000-00" which results in special handling
                            if String.contains "Vanhemmat" group.monthLabel || String.contains "Tuntematon" group.monthLabel then
                                Expect.pass

                            else
                                Expect.fail ("Expected label to contain 'Vanhemmat' or 'Tuntematon', got: " ++ group.monthLabel)

                        Nothing ->
                            Expect.fail "Expected at least one group"
            , test "creates correct month IDs" <|
                \_ ->
                    let
                        items =
                            [ createTestItem "2026-01-08T19:27:04Z"
                            ]

                        groups =
                            groupByMonth items

                        firstGroup =
                            List.head groups
                    in
                    case firstGroup of
                        Just group ->
                            Expect.equal "m-2026-01" group.monthId

                        Nothing ->
                            Expect.fail "Expected at least one group"
            , test "empty list returns empty groups" <|
                \_ ->
                    Expect.equal [] (groupByMonth [])
            ]
        ]


{-| Helper to create a test item with a date
-}
createTestItem : String -> AppItem
createTestItem date =
    { itemTitle = "Test Item"
    , itemLink = "https://example.com"
    , itemDate = Just date
    , itemDescSnippet = Nothing
    , itemThumbnail = Nothing
    , itemSourceTitle = "Test Source"
    , itemSourceLink = Nothing
    , itemType = Feed
    }


{-| Helper to create a test item without a date
-}
createTestItemNoDate : AppItem
createTestItemNoDate =
    { itemTitle = "Test Item"
    , itemLink = "https://example.com"
    , itemDate = Nothing
    , itemDescSnippet = Nothing
    , itemThumbnail = Nothing
    , itemSourceTitle = "Test Source"
    , itemSourceLink = Nothing
    , itemType = Feed
    }
