module Page.Home exposing (Model, Msg, init, subscriptions, toSession, update, view)

{-| The homepage. You can get here via either the / or /#/ routes.
-}

import Article
import Article.Feed as Feed
import Article.FeedSources as FeedSources exposing (FeedSources, Source(..))
import Article.Tag as Tag exposing (Tag)
import Html exposing (..)
import Html.Attributes exposing (attribute, class, classList, href, id, placeholder)
import Html.Events exposing (onClick)
import Http
import Loading
import Log
import Page
import Session exposing (Session)
import Task exposing (Task)
import Time
import Viewer.Cred as Cred exposing (Cred)


-- MODEL


type alias Model =
    { session : Session
    , timeZone : Time.Zone

    -- Loaded independently from server
    , tags : Status (List Tag)
    , feed : Status Feed.Model
    }


type Status a
    = Loading
    | Loaded a
    | Failed


init : Session -> ( Model, Cmd Msg )
init session =
    let
        feedSources =
            case Session.cred session of
                Just cred ->
                    FeedSources.fromLists (YourFeed cred) [ GlobalFeed ]

                Nothing ->
                    FeedSources.fromLists GlobalFeed []

        loadTags =
            Tag.list
                |> Http.toTask
    in
        ( { session = session
          , timeZone = Time.utc
          , tags = Loading
          , feed = Loading
          }
        , Cmd.batch
            [ Feed.init session feedSources
                |> Task.attempt CompletedFeedLoad
            , Tag.list
                |> Http.send CompletedTagsLoad
            , Task.perform GotTimeZone Time.here
            ]
        )



-- VIEW


view : Model -> { title : String, content : Html Msg }
view model =
    { title = "Conduit"
    , content =
        div [ class "home-page" ]
            [ viewBanner
            , div [ class "container page" ]
                [ div [ class "row" ]
                    [ div [ class "col-md-9" ]
                        (viewFeed model.feed model.timeZone)
                    , div [ class "col-md-3" ]
                        [ div [ class "sidebar" ] <|
                            case model.tags of
                                Loaded tags ->
                                    [ p [] [ text "Popular Tags" ]
                                    , viewTags tags
                                    ]

                                Loading ->
                                    [ Loading.icon ]

                                Failed ->
                                    [ Loading.error "tags" ]
                        ]
                    ]
                ]
            ]
    }


viewBanner : Html msg
viewBanner =
    div [ class "banner" ]
        [ div [ class "container" ]
            [ h1 [ class "logo-font" ] [ text "conduit" ]
            , p [] [ text "A place to share your knowledge." ]
            ]
        ]


{-| 👉 TODO refactor this to accept narrower types than the entire Model.

💡 HINT: It may end up with multiple arguments!

-}
viewFeed : Status Feed.Model -> Time.Zone -> List (Html Msg)
viewFeed feed timezone =
    case feed of
        Loaded feedP ->
            div [ class "feed-toggle" ]
                [ Feed.viewFeedSources feedP |> Html.map GotFeedMsg ]
                :: (Feed.viewArticles timezone feedP |> List.map (Html.map GotFeedMsg))

        Loading ->
            [ Loading.icon ]

        Failed ->
            [ Loading.error "feed" ]


viewTags : List Tag -> Html Msg
viewTags tags =
    div [ class "tag-list" ] (List.map viewTag tags)


viewTag : Tag -> Html Msg
viewTag tagName =
    a
        [ class "tag-pill tag-default"
        , onClick (ClickedTag tagName)

        -- The RealWorld CSS requires an href to work properly.
        , href ""
        ]
        [ text (Tag.toString tagName) ]



-- UPDATE


type Msg
    = ClickedTag Tag
    | CompletedFeedLoad (Result Http.Error Feed.Model)
    | CompletedTagsLoad (Result Http.Error (List Tag))
    | GotTimeZone Time.Zone
    | GotFeedMsg Feed.Msg
    | GotSession Session


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ClickedTag tagName ->
            let
                subCmd =
                    Feed.selectTag (Session.cred model.session) tagName
            in
                ( model, Cmd.map GotFeedMsg subCmd )

        CompletedFeedLoad (Ok feed) ->
            ( { model | feed = Loaded feed }, Cmd.none )

        CompletedFeedLoad (Err error) ->
            ( { model | feed = Failed }, Cmd.none )

        CompletedTagsLoad (Ok tags) ->
            ( { model | tags = Loaded tags }, Cmd.none )

        CompletedTagsLoad (Err error) ->
            ( { model | tags = Failed }
            , Log.error
            )

        GotFeedMsg subMsg ->
            case model.feed of
                Loaded feed ->
                    let
                        ( newFeed, subCmd ) =
                            Feed.update (Session.cred model.session) subMsg feed
                    in
                        ( { model | feed = Loaded newFeed }
                        , Cmd.map GotFeedMsg subCmd
                        )

                Loading ->
                    ( model, Log.error )

                Failed ->
                    ( model, Log.error )

        GotTimeZone tz ->
            ( { model | timeZone = tz }, Cmd.none )

        GotSession session ->
            ( { model | session = session }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Session.changes GotSession (Session.navKey model.session)



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
