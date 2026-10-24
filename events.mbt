///|
/// Event kinds emitted by providers according to the OpenFeature event model.
pub(all) enum ProviderEventKind {
  ProviderReady
  ProviderError
  ConfigurationChanged
  ProviderStale
  ProviderReconciling
  ContextChanged
} derive(Eq, Debug)

///|
pub extend ProviderEventKind with Eq::{equal, not_equal}

///|
pub extend ProviderEventKind with Debug::{to_repr}

///|
/// A provider lifecycle or configuration-change event.
pub struct ProviderEvent {
  kind : ProviderEventKind
  message : String?
  changed_flags : Array[String]
}

///|
/// Create an event with no message or changed flag list.
pub fn ProviderEvent::new(kind : ProviderEventKind) -> ProviderEvent {
  { kind, message: None, changed_flags: [], }
}

///|
/// Return a copy of the event with a message.
pub fn ProviderEvent::with_message(
  self : ProviderEvent,
  message : String,
) -> ProviderEvent {
  { ..self, message: Some(message), changed_flags: self.changed_flags.copy(), }
}

///|
/// Return a copy with the identifiers of changed flags.
pub fn ProviderEvent::with_changed_flags(
  self : ProviderEvent,
  changed_flags : Array[String],
) -> ProviderEvent {
  { ..self, changed_flags: changed_flags.copy(), }
}

///|
/// Return the event kind.
pub fn ProviderEvent::kind(self : ProviderEvent) -> ProviderEventKind {
  self.kind
}

///|
/// Return the optional message.
pub fn ProviderEvent::message(self : ProviderEvent) -> String? {
  self.message
}

///|
/// Return a detached list of changed flag identifiers.
pub fn ProviderEvent::changed_flags(self : ProviderEvent) -> Array[String] {
  self.changed_flags.copy()
}

///|
/// Callback registered by an API or client for provider events.
pub type ProviderEventHandler = (ProviderEvent) -> Result[Unit, EvaluationError]

///|
/// Sink registered by an API on a provider instance.
pub type ProviderEventSink = (ProviderEvent) -> Unit

///|
/// Make a detached copy so each handler receives an independent flag list.
fn ProviderEvent::snapshot(self : ProviderEvent) -> ProviderEvent {
  {
    kind: self.kind,
    message: self.message,
    changed_flags: self.changed_flags.copy(),
  }
}

///|
priv struct ApiEventHandlerEntry {
  id : Int32
  handler : ProviderEventHandler
}

///|
priv struct ClientEventHandlerEntry {
  id : Int32
  domain : String?
  handler : ProviderEventHandler
}

///|
/// Register a handler for every provider event emitted through this API.
pub fn Api::add_event_handler(
  self : Api,
  handler : ProviderEventHandler,
) -> Int32 {
  let current = self.state.val
  let id = current.next_event_handler_id
  let api_event_handlers = current.api_event_handlers.copy()
  api_event_handlers.push(ApiEventHandlerEntry::{ id, handler, })
  self.state.val = {
    ..current,
    api_event_handlers,
    next_event_handler_id: id + 1,
  }
  id
}

///|
/// Remove an API event handler. Returns false when the identifier is unknown.
pub fn Api::remove_event_handler(self : Api, id : Int32) -> Bool {
  let current = self.state.val
  let mut found = false
  let api_event_handlers = current.api_event_handlers.filter(fn(entry) {
    if entry.id == id {
      found = true
      false
    } else {
      true
    }
  })
  if found {
    self.state.val = { ..current, api_event_handlers, }
  }
  found
}

///|
/// Return and clear errors raised by event handlers.
pub fn Api::drain_event_handler_errors(self : Api) -> Array[EvaluationError] {
  let current = self.state.val
  let errors = current.event_handler_errors
  self.state.val = { ..current, event_handler_errors: [], }
  errors
}

///|
/// Register a handler for events emitted by this client's selected provider.
pub fn Client::add_event_handler(
  self : Client,
  handler : ProviderEventHandler,
) -> Int32 {
  let current = self.api.state.val
  let id = current.next_event_handler_id
  let client_event_handlers = current.client_event_handlers.copy()
  client_event_handlers.push(ClientEventHandlerEntry::{
    id,
    domain: self.domain,
    handler,
  })
  self.api.state.val = {
    ..current,
    client_event_handlers,
    next_event_handler_id: id + 1,
  }
  id
}

///|
/// Remove this client's event handler. Returns false when the identifier is unknown.
pub fn Client::remove_event_handler(self : Client, id : Int32) -> Bool {
  let current = self.api.state.val
  let mut found = false
  let client_event_handlers = current.client_event_handlers.filter(fn(entry) {
    if entry.id == id && entry.domain == self.domain {
      found = true
      false
    } else {
      true
    }
  })
  if found {
    self.api.state.val = { ..current, client_event_handlers, }
  }
  found
}

///|
/// Route one provider event to a stable snapshot of matching handlers.
fn Api::dispatch_provider_event(
  self : Api,
  provider_id : String,
  event : ProviderEvent,
) -> Unit {
  let state = self.state.val
  let handlers : Array[ProviderEventHandler] = []
  for entry in state.api_event_handlers {
    handlers.push(entry.handler)
  }
  for entry in state.client_event_handlers {
    if self.provider_id_for_domain(entry.domain) == Some(provider_id) {
      handlers.push(entry.handler)
    }
  }
  for handler in handlers {
    match handler(event.snapshot()) {
      Ok(_) => ()
      Err(error) => self.record_event_handler_error(error)
    }
  }
}

///|
fn Api::record_event_handler_error(self : Api, error : EvaluationError) -> Unit {
  let current = self.state.val
  let event_handler_errors = current.event_handler_errors.copy()
  event_handler_errors.push(error)
  self.state.val = { ..current, event_handler_errors, }
}
