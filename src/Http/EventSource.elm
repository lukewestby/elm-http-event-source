effect module Http.EventSource where { subscription = MySub } exposing (listen)

{-|

@docs listen
-}

import Process
import Dict exposing (Dict)
import Task exposing (Task)
import Platform exposing (Router)
import Http.EventSource.LowLevel as LowLevel exposing (EventSource, Settings)


{-| -}
listen : String -> String -> (String -> msg) -> Sub msg
listen url eventName listener =
    subscription (MySub url eventName listener)


andThen : (a -> Task x b) -> Task x a -> Task x b
andThen =
    flip Task.andThen


type MySub msg
    = MySub String String (String -> msg)


subMap : (a -> b) -> MySub a -> MySub b
subMap mapper (MySub channel eventName toMsg) =
    MySub channel eventName <| toMsg >> mapper


categorize : List (MySub msg) -> Dict String (Dict String (List (String -> msg)))
categorize subs =
    let
        innerUpdateFn listener maybeList =
            maybeList
                |> (Maybe.withDefault [] >> Just)
                |> Maybe.map (\list -> listener :: list)

        outerUpdateFn eventName listener maybeListenersDict =
            maybeListenersDict
                |> (Maybe.withDefault Dict.empty >> Just)
                |> Maybe.map (Dict.update eventName (innerUpdateFn listener))

        foldFn (MySub url eventName listener) dict =
            Dict.update url (outerUpdateFn eventName listener) dict
    in
        List.foldl foldFn Dict.empty subs


type alias Watcher msg =
    { pid : Process.Id
    , listeners : List (String -> msg)
    }


type alias SourceHandler msg =
    { eventSource : EventSource
    , watchers : Dict String (Watcher msg)
    }


type alias State msg =
    Dict String (SourceHandler msg)


type SelfMsg
    = Receive String String String
    | Close String


init : Task Never (State msg)
init =
    Task.succeed Dict.empty


onEffects : Router msg SelfMsg -> List (MySub msg) -> State msg -> Task Never (State msg)
onEffects router newSubs oldState =
    let
        innerLeftStep eventName watcher task =
            Process.kill watcher.pid
                |> andThen (always task)

        innerBothStep eventName watcher listeners task =
            task
                |> andThen (\watchers -> Task.succeed (Dict.insert eventName ({ watcher | listeners = listeners }) watchers))

        innerRightStep eventSource url eventName listeners task =
            let
                afterTask watchers =
                    Process.spawn (LowLevel.on eventName (Receive url eventName >> Platform.sendToSelf router) eventSource)
                        |> andThen (\pid -> Task.succeed (Dict.insert eventName (Watcher pid listeners) watchers))
            in
                task |> andThen afterTask

        leftStep url sourceHandler task =
            LowLevel.close sourceHandler.eventSource
                |> andThen (always task)

        bothStep url sourceHandler eventHandlers task =
            task
                |> andThen
                    (\state ->
                        let
                            watchersTask =
                                Dict.merge innerLeftStep
                                    innerBothStep
                                    (innerRightStep sourceHandler.eventSource url)
                                    sourceHandler.watchers
                                    eventHandlers
                                    (Task.succeed Dict.empty)
                        in
                            watchersTask
                                |> andThen (\watchers -> Task.succeed (Dict.insert url { sourceHandler | watchers = watchers } state))
                    )

        rightStep url eventHandlers task =
            let
                settings =
                    { withCredentials = False
                    , onClose = \() -> Platform.sendToSelf router (Close url)
                    }

                afterTask state =
                    LowLevel.open url settings
                        |> andThen (\eventSource -> Task.succeed (SourceHandler eventSource Dict.empty))
                        |> andThen (\sourceHandler -> bothStep url sourceHandler eventHandlers (Task.succeed state))
            in
                task
                    |> andThen afterTask
    in
        Dict.merge leftStep
            bothStep
            rightStep
            oldState
            (categorize newSubs)
            (Task.succeed Dict.empty)


onSelfMsg : Router msg SelfMsg -> SelfMsg -> State msg -> Task Never (State msg)
onSelfMsg router msg state =
    case msg of
        Receive url eventName data ->
            Dict.get url state
                |> Maybe.map .watchers
                |> Maybe.withDefault Dict.empty
                |> Dict.get eventName
                |> Maybe.map .listeners
                |> Maybe.withDefault []
                |> List.map (\listener -> Platform.sendToApp router (listener data))
                |> Task.sequence
                |> andThen (always (Task.succeed state))

        Close url ->
            Task.succeed state
