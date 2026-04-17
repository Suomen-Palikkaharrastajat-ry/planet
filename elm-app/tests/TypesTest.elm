module TypesTest exposing (suite)

{-| Tests for Types module

-}

import Data exposing (FeedType(..))
import Expect
import RemoteData
import Test exposing (Test, describe, test)
import Types exposing (Model, MonthGroup, Msg(..), ViewMode(..))


suite : Test
suite =
    describe "Types module"
        [ describe "Model"
            [ test "Model contains items, generatedAt, selectedFeedTypes, and searchText" <|
                \_ ->
                    let
                        model =
                            { items = []
                            , generatedAt = "2026-01-09"
                            , selectedFeedTypes = [ Feed ]
                            , searchText = ""
                            , viewMode = Types.Full
                            , visibleGroups = []
                            , isSidebarVisible = False
                            , searchIndex = RemoteData.NotAsked
                            , searchedIds = []
                            , scrollY = 0
                            , navKey = Nothing
                            , lang = Types.Fi
                            , currentGroup = "fi"
                            }
                    in
                    Expect.equal model.generatedAt "2026-01-09"
            ]
        , describe "MonthGroup"
            [ test "MonthGroup contains month metadata and items" <|
                \_ ->
                    let
                        group : MonthGroup
                        group =
                            { monthLabel = "tammikuu 2026"
                            , monthId = "m-2026-01"
                            , items = []
                            }
                    in
                    Expect.equal group.monthLabel "tammikuu 2026"
            ]
        , describe "Msg"
            [ test "NoOp message exists" <|
                \_ ->
                    Expect.equal NoOp NoOp
            , test "ToggleFeedType message exists" <|
                \_ ->
                    Expect.equal (ToggleFeedType Feed) (ToggleFeedType Feed)
            , test "UpdateSearchText message exists" <|
                \_ ->
                    Expect.equal (UpdateSearchText "test") (UpdateSearchText "test")
            , test "ToggleSidebar message exists" <|
                \_ ->
                    Expect.equal ToggleSidebar ToggleSidebar
            ]
        ]
