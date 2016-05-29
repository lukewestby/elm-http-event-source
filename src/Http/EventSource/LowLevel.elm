module Http.EventSource.LowLevel
    exposing
        ( EventSource
        , Settings
        , open
        , on
        , close
        )

import Task exposing (Task)
import Native.EventSource


type EventSource
    = EventSource


type alias Settings =
    { withCredentials : Bool
    , onClose : () -> Task Never ()
    }


open : String -> Settings -> Task Never EventSource
open =
    Native.EventSource.open


on : String -> (String -> Task Never ()) -> EventSource -> Task Never Never
on =
    Native.EventSource.on


close : EventSource -> Task Never ()
close =
    Native.EventSource.close
