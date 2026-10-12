module TestSite exposing (site)

{-| This app's `config.toml`, resolved and decoded for the tests.
-}

import Json.Decode as Decode
import Lang exposing (Lang)
import SiteFixture
import SiteSettings exposing (SiteSettings)


{-| The site settings in a language (the default one when it is not declared).
-}
site : Lang -> SiteSettings
site lang =
    Decode.decodeString SiteSettings.localizedDecoder SiteFixture.json
        |> Result.toMaybe
        |> Maybe.andThen (SiteSettings.forLang lang)
        |> Maybe.withDefault (SiteSettings.placeholder lang)
