module Page.Profile exposing (Model, Msg, init, subscriptions, toSession, update, view)

{-| An Author's profile.
-}

import Article.Feed as Feed exposing (ListConfig)
import Article.FeedSources as FeedSources exposing (FeedSources, Source(..))
import Author exposing (Author(..), FollowedAuthor, UnfollowedAuthor)
import Avatar exposing (Avatar)
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Loading
import Log
import Page
import Profile exposing (Profile)
import Session exposing (Session)
import Task exposing (Task)
import Time
import Username exposing (Username)
import Viewer exposing (Viewer)
import Viewer.Cred as Cred exposing (Cred)



-- MODEL


type alias Model =
    { session : Session
    , timeZone : Time.Zone
    , errors : List String

    -- Loaded independently from server
    , author : Status Author
    , feed : Status Feed.Model
    }


type Status a
    = Loading Username
    | Loaded a
    | Failed Username


init : Session -> Username -> ( Model, Cmd Msg )
init session username =
    let
        maybeCred =
            Session.cred session
    in
    ( { session = session
      , timeZone = Time.utc
      , errors = []
      , author = Loading username
      , feed = Loading username
      }
    , Cmd.batch
        [ Author.fetch username maybeCred
            |> Http.toTask
            |> Task.mapError (Tuple.pair username)
            |> Task.attempt CompletedAuthorLoad
        , defaultFeedSources username
            |> Feed.init session
            |> Task.mapError (Tuple.pair username)
            |> Task.attempt CompletedFeedLoad
        , Task.perform GotTimeZone Time.here
        ]
    )



-- VIEW


view : Model -> { title : String, content : Html Msg }
view model =
    let
        title =
            case model.author of
                Loaded (IsViewer _ _) ->
                    myProfileTitle

                Loaded ((IsFollowing followedAuthor) as author) ->
                    titleForOther (Author.username author)

                Loaded ((IsNotFollowing unfollowedAuthor) as author) ->
                    titleForOther (Author.username author)

                Loading username ->
                    if Just username == Maybe.map Cred.username (Session.cred model.session) then
                        myProfileTitle

                    else
                        defaultTitle

                Failed username ->
                    -- We can't follow if it hasn't finished loading yet
                    if Just username == Maybe.map Cred.username (Session.cred model.session) then
                        myProfileTitle

                    else
                        defaultTitle
    in
    { title = title
    , content =
        case model.author of
            Loaded author ->
                let
                    profile =
                        Author.profile author

                    username =
                        Author.username author

                    followButton =
                        case Session.cred model.session of
                            Just cred ->
                                case author of
                                    IsViewer _ _ ->
                                        -- We can't follow ourselves!
                                        text ""

                                    IsFollowing followedAuthor ->
                                        Author.unfollowButton (ClickedUnfollow cred) followedAuthor

                                    IsNotFollowing unfollowedAuthor ->
                                        Author.followButton (ClickedFollow cred) unfollowedAuthor

                            Nothing ->
                                -- We can't follow if we're logged out
                                text ""
                in
                div [ class "profile-page" ]
                    [ Page.viewErrors ClickedDismissErrors model.errors
                    , div [ class "user-info" ]
                        [ div [ class "container" ]
                            [ div [ class "row" ]
                                [ div [ class "col-xs-12 col-md-10 offset-md-1" ]
                                    [ img [ class "user-img", Avatar.src (Profile.avatar profile) ] []
                                    , h4 [] [ Username.toHtml username ]
                                    , p [] [ text (Maybe.withDefault "" (Profile.bio profile)) ]
                                    , followButton
                                    ]
                                ]
                            ]
                        ]
                    , case model.feed of
                        Loaded feed ->
                            div [ class "container" ]
                                [ div [ class "row" ] [ viewFeed model.timeZone feed ] ]

                        Loading _ ->
                            Loading.icon

                        Failed _ ->
                            Loading.error "feed"
                    ]

            Loading _ ->
                Loading.icon

            Failed _ ->
                Loading.error "profile"
    }



-- PAGE TITLE


titleForOther : Username -> String
titleForOther otherUsername =
    "Profile — " ++ Username.toString otherUsername


myProfileTitle : String
myProfileTitle =
    "My Profile"


defaultTitle : String
defaultTitle =
    "Profile"



-- FEED


viewFeed : Time.Zone -> Feed.Model -> Html Msg
viewFeed timeZone feed =
    div [ class "col-xs-12 col-md-10 offset-md-1" ] <|
        div [ class "articles-toggle" ]
            [ Feed.viewFeedSources feed |> Html.map GotFeedMsg ]
            :: (Feed.viewArticles timeZone feed |> List.map (Html.map GotFeedMsg))



-- UPDATE


type Msg
    = ClickedDismissErrors
    | ClickedFollow Cred UnfollowedAuthor
    | ClickedUnfollow Cred FollowedAuthor
    | CompletedFollowChange (Result Http.Error Author)
    | CompletedAuthorLoad (Result ( Username, Http.Error ) Author)
    | CompletedFeedLoad (Result ( Username, Http.Error ) Feed.Model)
    | GotTimeZone Time.Zone
    | GotFeedMsg Feed.Msg
    | GotSession Session


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ClickedDismissErrors ->
            ( { model | errors = [] }, Cmd.none )

        ClickedUnfollow cred followedAuthor ->
            ( model
            , Author.requestUnfollow followedAuthor cred
                |> Http.send CompletedFollowChange
            )

        ClickedFollow cred unfollowedAuthor ->
            ( model
            , Author.requestFollow unfollowedAuthor cred
                |> Http.send CompletedFollowChange
            )

        CompletedFollowChange (Ok newAuthor) ->
            ( { model | author = Loaded newAuthor }
            , Cmd.none
            )

        CompletedFollowChange (Err error) ->
            ( model
            , Log.error
            )

        CompletedAuthorLoad (Ok author) ->
            ( { model | author = Loaded author }, Cmd.none )

        CompletedAuthorLoad (Err ( username, err )) ->
            ( { model | author = Failed username }
            , Log.error
            )

        CompletedFeedLoad (Ok feed) ->
            ( { model | feed = Loaded feed }
            , Cmd.none
            )

        CompletedFeedLoad (Err ( username, err )) ->
            ( { model | feed = Failed username }
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

                Loading _ ->
                    ( model, Log.error )

                Failed _ ->
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



-- INTERNAL


defaultFeedSources : Username -> FeedSources
defaultFeedSources username =
    FeedSources.fromLists (AuthorFeed username) [ FavoritedFeed username ]
