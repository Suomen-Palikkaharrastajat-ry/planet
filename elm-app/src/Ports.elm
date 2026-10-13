port module Ports exposing (focusMobileSearch, onScroll, performSearch, reportError, saveSelectedFeedTypes, saveViewMode, scrollToElement, scrollToTop, searchResults, setDocumentLang)

{-| Ports for communicating with JavaScript for localStorage persistence, search, and scroll
-}


{-| Send view mode to JavaScript to save in localStorage
-}
port saveViewMode : String -> Cmd msg


{-| Send selected feed types to JavaScript to save in localStorage
-}
port saveSelectedFeedTypes : String -> Cmd msg


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


{-| Sets the document's `lang` attribute to the language being shown.
-}
port setDocumentLang : String -> Cmd msg


{-| Writes a problem the visitor cannot act on (unreadable configuration) to
the browser console.
-}
port reportError : String -> Cmd msg
