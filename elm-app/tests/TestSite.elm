module TestSite exposing (site)

{-| This app's `config.toml`, resolved and decoded for the tests.
-}

import Json.Decode as Decode
import Lang exposing (Lang)
import SiteFixture
import SiteSettings exposing (SiteSettings)


{-| The site settings in a language, hidden languages included (the default
one when it is not declared).
-}
site : Lang -> SiteSettings
site lang =
    case Decode.decodeString (Decode.at [ "configs", Lang.toString lang ] SiteSettings.decoder) SiteFixture.json of
        Ok settings ->
            settings

        Err _ ->
            Decode.decodeString SiteSettings.localizedDecoder SiteFixture.json
                |> Result.toMaybe
                |> Maybe.andThen (SiteSettings.forLang lang)
                |> Maybe.withDefault (SiteSettings.placeholder lang)
