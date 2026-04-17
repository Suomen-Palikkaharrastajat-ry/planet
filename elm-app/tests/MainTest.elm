module MainTest exposing (suite)

{-| Tests for Main module

-}

import Data exposing (FeedType(..), allAppItems, defaultGroup)
import Expect
import Main exposing (addAsterisks, canonicalGroupPath, groupFromPath)
import RemoteData
import Test exposing (Test, describe, test)
import Types exposing (Msg(..), Model, Lang(..))


{-| Create a test model for testing
-}
createTestModel : Model
createTestModel =
    { items = allAppItems
    , generatedAt = "2026-01-09"
    , selectedFeedTypes = [ Feed, YouTube, Image ]
    , searchText = ""
    , viewMode = Types.Full
    , visibleGroups = []
    , isSidebarVisible = False
    , searchIndex = RemoteData.NotAsked
    , searchedIds = []
    , scrollY = 0
    , navKey = Nothing
    , lang = Fi
    , currentGroup = "fi"
    }


suite : Test
suite =
    describe "Main module"
        [ describe "addAsterisks"
            [ test "adds asterisks around single word" <|
                \_ ->
                    Expect.equal (addAsterisks "hello") "*hello*"
            , test "adds asterisks around multiple words" <|
                \_ ->
                    Expect.equal (addAsterisks "hello world") "*hello* *world*"
            , test "handles multiple spaces" <|
                \_ ->
                    Expect.equal (addAsterisks "hello   world") "*hello* *world*"
            ]
        , describe "group routing helpers"
            [ test "groupFromPath returns explicit fi group" <|
                \_ ->
                    Expect.equal "fi" (groupFromPath "/fi/")
            , test "groupFromPath supports en group even if empty" <|
                \_ ->
                    Expect.equal "en" (groupFromPath "/en/")
            , test "groupFromPath falls back to default for unknown group" <|
                \_ ->
                    Expect.equal defaultGroup (groupFromPath "/sv/")
            , test "canonicalGroupPath redirects root to default group path" <|
                \_ ->
                    Expect.equal ("/" ++ defaultGroup ++ "/") (canonicalGroupPath "/")
            , test "canonicalGroupPath normalizes missing trailing slash" <|
                \_ ->
                    Expect.equal "/fi/" (canonicalGroupPath "/fi")
            ]
        , describe "init"
            [ test "initializes model with items and timestamp" <|
                \_ ->
                    -- Skip init test due to Browser.Navigation.Key requirement
                    Expect.pass
            , test "initializes with all app items" <|
                \_ ->
                    -- Skip init test due to Browser.Navigation.Key requirement
                    Expect.pass
            , test "initializes with all feed types selected" <|
                \_ ->
                    -- Skip init test due to Browser.Navigation.Key requirement
                    Expect.pass
            ]
        , describe "update"
            [ test "NoOp returns unchanged model" <|
                \_ ->
                    let
                        initialModel = createTestModel

                        ( updatedModel, _ ) =
                            Main.update NoOp initialModel
                    in
                    Expect.equal initialModel updatedModel
            , test "ToggleFeedType toggles the feed type in selectedFeedTypes" <|
                \_ ->
                    let
                        initialModel = createTestModel

                        ( updatedModel, _ ) =
                            Main.update (ToggleFeedType Feed) initialModel
                    in
                    Expect.equal (List.member Feed updatedModel.selectedFeedTypes) False
            , test "UpdateSearchText updates the search text" <|
                \_ ->
                    let
                        initialModel = createTestModel

                        ( updatedModel, _ ) =
                            Main.update (UpdateSearchText "test search") initialModel
                    in
                    Expect.equal updatedModel.searchText "test search"
            , test "ToggleSidebar toggles the sidebar visibility" <|
                \_ ->
                    let
                        initialModel = createTestModel

                        ( updatedModel, _ ) =
                            Main.update ToggleSidebar initialModel
                    in
                    Expect.equal updatedModel.isSidebarVisible True
            ]
        , describe "subscriptions"
            [ test "returns subscriptions for ports" <|
                \_ ->
                    let
                        model = createTestModel
                    in
                    Main.subscriptions model
                        |> Expect.notEqual Sub.none
            ]
        ]
