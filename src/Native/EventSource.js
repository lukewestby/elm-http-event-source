var _lukewestby$elm_http_event_source$Native_EventSource = (function () {

  function closeHelp(eventSource) {
    if (eventSource.readyState === eventSource.CLOSED) {
      return;
    }
    eventSource.close();
    eventSource.dispatchEvent(new Event('close'));
  }

  function open (url, settings) {
    return _elm_lang$core$Native_Scheduler.nativeBinding(function (callback) {
      var eventSource = new EventSource(url, {
        withCredentials: !!settings.withCredentials,
      });

      eventSource.addEventListener('open', function onOpen() {
        eventSource.removeEventListener('open', onOpen);
        callback(_elm_lang$core$Native_Scheduler.succeed(eventSource));
      });

  		eventSource.addEventListener('close', function(event) {
  			_elm_lang$core$Native_Scheduler.rawSpawn(settings.onClose(_elm_lang$core$Native_Utils.Tuple0));
  		});

  		return function() {
  			if (eventSource && eventSource.close) {
  				closeHelp(eventSource);
  			}
  		};
    });
  }

  function on(eventType, toTask, eventSource) {
    return _elm_lang$core$Native_Scheduler.nativeBinding(function (callback) {
      function onMessage (ev) {
        _elm_lang$core$Native_Scheduler.rawSpawn(toTask(ev.data));
      }
      eventSource.addEventListener(eventType, onMessage);
      eventSource.addEventListener('close', function () {
        eventSource.removeEventListener(eventType, onMessage);
      });

      return function () {
        eventSource.removeEventListener(eventType, onMessage);
      }
    });
  }

  function close(eventSource) {
  	return _elm_lang$core$Native_Scheduler.nativeBinding(function(callback) {
  	  closeHelp(eventSource);
  		callback(_elm_lang$core$Native_Scheduler.succeed(_elm_lang$core$Native_Utils.Tuple0));
  	});
  }

  return {
  	open: F2(open),
    on: F3(on),
    close: close,
  };
}());
