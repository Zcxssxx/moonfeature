///|
struct SinkState {
  next_id : Int32
  listeners : Array[(Int32, @moonfeature.ProviderEventSink)]
}

///|
struct EventProvider {
  id : String
  value : String
  state : @ref.Ref[SinkState]
}

///|
fn event_provider(id : String, value : String) -> EventProvider {
  { id, value, state: @ref.Ref({ next_id: 1, listeners: [], }), }
}

///|
fn EventProvider::emit(
  self : EventProvider,
  event : @moonfeature.ProviderEvent,
) -> Unit {
  let listeners = self.state.val.listeners.copy()
  for (_, listener) in listeners {
    listener(event)
  }
}

///|
fn EventProvider::listener_count(self : EventProvider) -> Int32 {
  self.state.val.listeners.length()
}

///|
impl @moonfeature.Provider for EventProvider with fn metadata(self) {
  @moonfeature.ProviderMetadata::new(self.id, "1.0")
}

///|
impl @moonfeature.Provider for EventProvider with fn instance_id(self) {
  self.id
}

///|
impl @moonfeature.Provider for EventProvider with fn domain_scoped(_self) {
  false
}

///|
impl @moonfeature.Provider for EventProvider with fn initialize(
  self,
  _context,
  _domain,
) {
  self.emit(
    @moonfeature.ProviderEvent::new(
      @moonfeature.ProviderEventKind::ProviderReady,
    ),
  )
  Ok(())
}

///|
impl @moonfeature.Provider for EventProvider with fn shutdown(_self) {
  Ok(())
}

///|
impl @moonfeature.Provider for EventProvider with fn status(_self) {
  @moonfeature.ProviderStatus::Ready
}

///|
impl @moonfeature.Provider for EventProvider with fn resolve(
  self,
  _key,
  _expected,
  _context,
) {
  Ok(
    @moonfeature.ProviderResolution::new(
      @moonfeature.FlagValue::String(self.value),
    ).with_reason(@moonfeature.ResolutionReason::Static),
  )
}

///|
impl @moonfeature.Provider for EventProvider with fn subscribe_events(
  self,
  listener,
) {
  let state = self.state.val
  let id = state.next_id
  let listeners = state.listeners.copy()
  listeners.push((id, listener))
  self.state.val = { next_id: id + 1, listeners, }
  id
}

///|
impl @moonfeature.Provider for EventProvider with fn unsubscribe_events(
  self,
  id,
) {
  let state = self.state.val
  let listeners : Array[(Int32, @moonfeature.ProviderEventSink)] = []
  for (current_id, listener) in state.listeners {
    if current_id != id {
      listeners.push((current_id, listener))
    }
  }
  self.state.val = { ..state, listeners, }
}

///|
test "events route to API and clients bound to the emitting provider" {
  let api = @moonfeature.Api::new()
  let default_provider = event_provider("events-default", "default")
  let default_object : &@moonfeature.Provider = default_provider
    as &@moonfeature.Provider
  assert_eq(api.set_provider(default_object), Ok(()))
  let tenant_provider = event_provider("events-tenant", "tenant")
  let tenant_object : &@moonfeature.Provider = tenant_provider
    as &@moonfeature.Provider
  assert_eq(api.set_provider_for_domain("tenant-a", tenant_object), Ok(()))

  let trace : @ref.Ref[Array[String]] = @ref.Ref([])
  let api_handler = api.add_event_handler(fn(_event) {
    trace.val.push("api")
    Ok(())
  })
  let default_client = api.client()
  let default_handler = default_client.add_event_handler(fn(_event) {
    trace.val.push("default")
    Ok(())
  })
  let fallback_client = api.client_for_domain("unknown")
  let fallback_handler = fallback_client.add_event_handler(fn(_event) {
    trace.val.push("fallback")
    Ok(())
  })
  let tenant_client = api.client_for_domain("tenant-a")
  let tenant_handler = tenant_client.add_event_handler(fn(_event) {
    trace.val.push("tenant")
    Ok(())
  })

  default_provider.emit(
    @moonfeature.ProviderEvent::new(
      @moonfeature.ProviderEventKind::ConfigurationChanged,
    ),
  )
  assert_eq(trace.val, ["api", "default", "fallback"])
  trace.val = []
  tenant_provider.emit(
    @moonfeature.ProviderEvent::new(
      @moonfeature.ProviderEventKind::ProviderReady,
    ),
  )
  assert_eq(trace.val, ["api", "tenant"])

  assert_true(api.remove_event_handler(api_handler))
  assert_true(default_client.remove_event_handler(default_handler))
  assert_true(fallback_client.remove_event_handler(fallback_handler))
  assert_true(tenant_client.remove_event_handler(tenant_handler))
}

///|
test "a failing event handler is recorded without stopping later handlers" {
  let api = @moonfeature.Api::new()
  let provider = event_provider("event-errors", "value")
  let provider_object : &@moonfeature.Provider = provider
    as &@moonfeature.Provider
  assert_eq(api.set_provider(provider_object), Ok(()))
  let called = @ref.Ref(0)
  let failing_id = api.add_event_handler(fn(_event) {
    Err(
      @moonfeature.EvaluationError::new(
        @moonfeature.ErrorCode::HookFailure,
        "handler rejected event",
      ),
    )
  })
  let succeeding_id = api.add_event_handler(fn(_event) {
    called.val = called.val + 1
    Ok(())
  })
  provider.emit(
    @moonfeature.ProviderEvent::new(
      @moonfeature.ProviderEventKind::ProviderError,
    ),
  )
  assert_eq(called.val, 1)
  assert_eq(api.drain_event_handler_errors().length(), 1)
  assert_true(api.remove_event_handler(failing_id))
  assert_true(api.remove_event_handler(succeeding_id))
}

///|
test "events emitted during initialization are delivered after activation" {
  let api = @moonfeature.Api::new()
  let provider = event_provider("event-initialize", "value")
  let trace : @ref.Ref[Array[String]] = @ref.Ref([])
  let handler_id = api.add_event_handler(fn(event) {
    trace.val.push(event.kind().to_repr().to_string())
    Ok(())
  })
  let provider_object : &@moonfeature.Provider = provider
    as &@moonfeature.Provider
  assert_eq(api.set_provider(provider_object), Ok(()))
  assert_eq(trace.val, ["ProviderReady"])
  assert_true(api.remove_event_handler(handler_id))
  assert_eq(api.shutdown(), Ok(()))
  assert_eq(provider.listener_count(), 0)
}

///|
test "retired providers are unsubscribed and stop routing events" {
  let api = @moonfeature.Api::new()
  let old_provider = event_provider("event-old", "old")
  let old_object : &@moonfeature.Provider = old_provider
    as &@moonfeature.Provider
  assert_eq(api.set_provider(old_object), Ok(()))
  let trace : @ref.Ref[Array[String]] = @ref.Ref([])
  let handler_id = api.add_event_handler(fn(_event) {
    trace.val.push("event")
    Ok(())
  })
  let new_provider = event_provider("event-new", "new")
  let new_object : &@moonfeature.Provider = new_provider
    as &@moonfeature.Provider
  assert_eq(api.set_provider(new_object), Ok(()))
  assert_eq(trace.val, ["event"])
  trace.val = []
  assert_eq(old_provider.listener_count(), 0)
  old_provider.emit(
    @moonfeature.ProviderEvent::new(
      @moonfeature.ProviderEventKind::ProviderStale,
    ),
  )
  assert_eq(trace.val, [])
  new_provider.emit(
    @moonfeature.ProviderEvent::new(
      @moonfeature.ProviderEventKind::ProviderStale,
    ),
  )
  assert_eq(trace.val, ["event"])
  assert_true(api.remove_event_handler(handler_id))
  assert_eq(api.shutdown(), Ok(()))
  assert_eq(new_provider.listener_count(), 0)
}
