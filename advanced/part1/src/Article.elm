module Article
    exposing
        ( Article
        , Full
        , Preview
        , author
        , body
        , favorite
        , favoriteButton
        , fetch
        , fromPreview
        , fullDecoder
        , mapAuthor
        , metadata
        , previewDecoder
        , slug
        , unfavorite
        , unfavoriteButton
        , url
        )

{-| The interface to the Article data structure.

This includes:

  - The Article type itself
  - Ways to make HTTP requests to retrieve and modify articles
  - Ways to access information about an article
  - Converting between various types

-}

import Api
import Article.Body as Body exposing (Body)
import Article.Slug as Slug exposing (Slug)
import Article.Tag as Tag exposing (Tag)
import Author exposing (Author)
import Html exposing (Attribute, Html, i)
import Html.Attributes exposing (class)
import Html.Events exposing (stopPropagationOn)
import Http
import HttpBuilder exposing (RequestBuilder, withBody, withExpect, withQueryParams)
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (custom, hardcoded, required)
import Json.Encode as Encode
import Markdown
import Profile exposing (Profile)
import Time
import Timestamp
import Username as Username exposing (Username)
import Viewer exposing (Viewer)
import Viewer.Cred as Cred exposing (Cred)


-- TYPES


type Article extraInfo
    = Article Internals extraInfo



-- 💡 HINT: We can use these `Preview` and/or `Full` types to store information...


type Preview
    = Preview


type Full
    = Full Body


type alias Metadata =
    { description : String
    , title : String
    , tags : List String
    , createdAt : Time.Posix
    , favorited : Bool
    , favoritesCount : Int
    }


type alias Internals =
    { slug : Slug
    , author : Author
    , metadata : Metadata
    }



-- INFO


author : Article a -> Author
author (Article internals _) =
    internals.author


metadata : Article a -> Metadata
metadata (Article internals _) =
    internals.metadata


slug : Article a -> Slug
slug (Article internals _) =
    internals.slug


body : Article Full -> Body
body (Article _ (Full bod)) =
    bod



-- TRANSFORM


{-| This is the only way you can transform an existing article:
you can change its author (e.g. to follow or unfollow them).
All other article data necessarily comes from the server!

We can tell this for sure by looking at the types of the exposed functions
in this module.

-}
mapAuthor : (Author -> Author) -> Article a -> Article a
mapAuthor transform (Article info extras) =
    Article { info | author = transform info.author } extras


fromPreview : Body -> Article Preview -> Article Full
fromPreview bod (Article internals Preview) =
    Article internals bod



-- SERIALIZATION


previewDecoder : Maybe Cred -> Decoder (Article Preview)
previewDecoder maybeCred =
    Decode.succeed Article
        |> custom (internalsDecoder maybeCred)
        |> hardcoded Preview


fullDecoder : Maybe Cred -> Decoder (Article Full)
fullDecoder maybeCred =
    Decode.succeed Article
        |> custom (internalsDecoder maybeCred)
        |> required "body" (Decode.map Full Body.decoder)


internalsDecoder : Maybe Cred -> Decoder Internals
internalsDecoder maybeCred =
    Decode.succeed Internals
        |> required "slug" Slug.decoder
        |> required "author" (Author.decoder maybeCred)
        |> custom metadataDecoder


metadataDecoder : Decoder Metadata
metadataDecoder =
    Decode.succeed Metadata
        |> required "description" (Decode.map (Maybe.withDefault "") (Decode.nullable Decode.string))
        |> required "title" Decode.string
        |> required "tagList" (Decode.list Decode.string)
        |> required "createdAt" Timestamp.iso8601Decoder
        |> required "favorited" Decode.bool
        |> required "favoritesCount" Decode.int



-- SINGLE


fetch : Maybe Cred -> Slug -> Http.Request (Article Full)
fetch maybeCred articleSlug =
    let
        expect =
            fullDecoder maybeCred
                |> Decode.field "article"
                |> Http.expectJson
    in
        url articleSlug []
            |> HttpBuilder.get
            |> HttpBuilder.withExpect expect
            |> Cred.addHeaderIfAvailable maybeCred
            |> HttpBuilder.toRequest



-- FAVORITE


favorite : Slug -> Cred -> Http.Request (Article Preview)
favorite articleSlug cred =
    buildFavorite HttpBuilder.post articleSlug cred


unfavorite : Slug -> Cred -> Http.Request (Article Preview)
unfavorite articleSlug cred =
    buildFavorite HttpBuilder.delete articleSlug cred


buildFavorite :
    (String -> RequestBuilder a)
    -> Slug
    -> Cred
    -> Http.Request (Article Preview)
buildFavorite builderFromUrl articleSlug cred =
    let
        expect =
            previewDecoder (Just cred)
                |> Decode.field "article"
                |> Http.expectJson
    in
        builderFromUrl (url articleSlug [ "favorite" ])
            |> Cred.addHeader cred
            |> withExpect expect
            |> HttpBuilder.toRequest


{-| This is a "build your own element" API.

You pass it some configuration, followed by a `List (Attribute msg)` and a
`List (Html msg)`, just like any standard Html element.

-}
favoriteButton : Cred -> msg -> List (Attribute msg) -> List (Html msg) -> Html msg
favoriteButton _ msg attrs kids =
    toggleFavoriteButton "btn btn-sm btn-outline-primary" msg attrs kids


unfavoriteButton : Cred -> msg -> List (Attribute msg) -> List (Html msg) -> Html msg
unfavoriteButton _ msg attrs kids =
    toggleFavoriteButton "btn btn-sm btn-primary" msg attrs kids


toggleFavoriteButton :
    String
    -> msg
    -> List (Attribute msg)
    -> List (Html msg)
    -> Html msg
toggleFavoriteButton classStr msg attrs kids =
    Html.button
        (class classStr :: onClickStopPropagation msg :: attrs)
        (i [ class "ion-heart" ] [] :: kids)


onClickStopPropagation : msg -> Attribute msg
onClickStopPropagation msg =
    stopPropagationOn "click"
        (Decode.succeed ( msg, True ))



-- URLS


url : Slug -> List String -> String
url articleSlug paths =
    allArticlesUrl (Slug.toString articleSlug :: paths)


allArticlesUrl : List String -> String
allArticlesUrl paths =
    Api.url ("articles" :: paths)
