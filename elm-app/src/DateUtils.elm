module DateUtils exposing (extractYearMonth, formatDate, formatMonthLabel, groupByMonth)

{-| Date utilities for formatting and grouping feed items

@docs extractYearMonth, formatDate, formatMonthLabel, groupByMonth

-}

import Data exposing (AppItem)
import I18n
import Lang exposing (Lang)
import Types exposing (MonthGroup)


{-| Extract year-month from ISO date string (e.g., "2026-01-08T19:27:04Z" -> "2026-01")
-}
extractYearMonth : String -> String
extractYearMonth dateStr =
    String.left 7 dateStr


{-| Month heading for an ISO date string, in the given language
("2026-01-08…" → "tammikuu 2026").
-}
formatMonthLabel : Lang -> String -> String
formatMonthLabel lang dateStr =
    let
        month =
            String.slice 5 7 dateStr
                |> String.toInt
                |> Maybe.withDefault 0
    in
    I18n.monthName lang month ++ " " ++ String.left 4 dateStr


{-| Format date for display (e.g., "2026-01-08T19:27:04Z" -> "2026-01-08")
-}
formatDate : String -> String
formatDate dateStr =
    String.left 10 dateStr


{-| Group items by month
-}
groupByMonth : Lang -> List AppItem -> List MonthGroup
groupByMonth lang items =
    let
        getMonthKey item =
            case item.itemDate of
                Just d ->
                    extractYearMonth d

                Nothing ->
                    "0000-00"

        sortedItems =
            items

        grouped =
            groupWhile (\a b -> getMonthKey a == getMonthKey b) sortedItems
    in
    List.map
        (\groupItems ->
            let
                first =
                    List.head groupItems
                        |> Maybe.andThen .itemDate
                        |> Maybe.withDefault ""

                monthKey =
                    extractYearMonth first
            in
            { monthLabel =
                if monthKey == "0000-00" then
                    I18n.translate lang I18n.UndatedItems

                else
                    formatMonthLabel lang first
            , monthId = "m-" ++ monthKey
            , items = groupItems
            }
        )
        grouped


{-| Group consecutive elements that satisfy a predicate
-}
groupWhile : (a -> a -> Bool) -> List a -> List (List a)
groupWhile pred list =
    case list of
        [] ->
            []

        first :: rest ->
            let
                ( group, remaining ) =
                    spanWhile (pred first) rest
            in
            (first :: group) :: groupWhile pred remaining


{-| Take elements while predicate is true
-}
spanWhile : (a -> Bool) -> List a -> ( List a, List a )
spanWhile pred list =
    case list of
        [] ->
            ( [], [] )

        x :: xs ->
            if pred x then
                let
                    ( taken, remaining ) =
                        spanWhile pred xs
                in
                ( x :: taken, remaining )

            else
                ( [], list )
