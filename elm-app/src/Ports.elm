port module Ports exposing (focusMobileSearch, loadSelectedFeedTypes, loadViewMode, onScroll, performSearch, saveSelectedFeedTypes, saveViewMode, scrollToElement, scrollToTop, searchResults)

{-| Ports for communicating with JavaScript for localStorage persistence, search, and scroll
-}


{-| Send view mode to JavaScript to save in localStorage
-}
port saveViewMode : String -> Cmd msg


{-| Receive view mode from JavaScript on app initialization
-}
port loadViewMode : (String -> msg) -> Sub msg


{-| Send selected feed types to JavaScript to save in localStorage
-}
port saveSelectedFeedTypes : String -> Cmd msg


{-| Receive selected feed types from JavaScript on app initialization
-}
port loadSelectedFeedTypes : (String -> msg) -> Sub msg


{-| Send search query to JavaScript for lunr.js search
-}
port performSearch : String -> Cmd msg


{-| Receive search results from JavaScript
-}
port searchResults : (List Int -> msg) -> Sub msg


{-| Send command to scroll to top
-}
port scrollToTop : () -> Cmd msg


{-| Receive scroll position from JavaScript
-}
port onScroll : (Float -> msg) -> Sub msg


{-| Send command to focus mobile search input
-}
port focusMobileSearch : () -> Cmd msg


{-| Send command to scroll to element by ID
-}
port scrollToElement : String -> Cmd msg
