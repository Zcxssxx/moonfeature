///|
/// Initialize and bind a provider, then retire the prior binding if unused.
fn Api::bind_provider(
  self : Api,
  domain : String?,
  provider : &Provider,
) -> Result[Unit, EvaluationError] {
  if domain is Some("") {
    return Err(
      EvaluationError::new(
        ErrorCode::InvalidConfiguration,
        "provider domain must not be empty",
      ),
    )
  }
  let provider_id = provider.instance_id()
  if provider_id == "" {
    return Err(
      EvaluationError::new(
        ErrorCode::InvalidConfiguration,
        "provider instance id must not be empty",
      ),
    )
  }
  if provider.domain_scoped() {
    match domain {
      None =>
        return Err(
          EvaluationError::new(
            ErrorCode::InvalidConfiguration,
            "domain-scoped providers require a domain binding",
          ),
        )
      Some(new_domain) =>
        match self.state.val.scoped_domains.get(provider_id) {
          Some(existing_domain) if existing_domain != new_domain =>
            return Err(
              EvaluationError::new(
                ErrorCode::InvalidConfiguration,
                "domain-scoped provider instance is already bound to another domain",
              ),
            )
          _ => ()
        }
    }
  }

  let already_registered = match self.state.val.providers.get(provider_id) {
    Some(_) => true
    None => false
  }
  let active = @ref.Ref(false)
  let pending_events : @ref.Ref[Array[ProviderEvent]] = @ref.Ref([])
  let mut event_subscription_id : Int32 = 0
  if !already_registered {
    let sink : ProviderEventSink = fn(event) {
      if active.val {
        self.dispatch_provider_event(provider_id, event)
      } else {
        pending_events.val.push(event.snapshot())
      }
    }
    event_subscription_id = provider.subscribe_events(sink)
    match provider.initialize(self.state.val.context, domain) {
      Ok(_) => ()
      Err(error) => {
        provider.unsubscribe_events(event_subscription_id)
        let _ = provider.shutdown()
        return Err(error)
      }
    }
  }

  let current = self.state.val
  let previous_id = match domain {
    None => current.default_provider_id
    Some(domain) => current.domain_providers.get(domain)
  }
  if previous_id == Some(provider_id) {
    return Ok(())
  }

  let providers = current.providers.copy()
  if !already_registered {
    providers.set(provider_id, ProviderEntry::{
      provider,
      event_subscription_id,
    })
  }
  let mut default_provider_id = current.default_provider_id
  let domain_providers = current.domain_providers.copy()
  let scoped_domains = current.scoped_domains.copy()
  match domain {
    None => default_provider_id = Some(provider_id)
    Some(domain) => {
      domain_providers.set(domain, provider_id)
      if provider.domain_scoped() {
        scoped_domains.set(provider_id, domain)
      }
    }
  }
  self.state.val = {
    ..current,
    default_provider_id,
    domain_providers,
    providers,
    scoped_domains,
  }
  if !already_registered {
    active.val = true
    for event in pending_events.val {
      self.dispatch_provider_event(provider_id, event)
    }
  }
  match previous_id {
    Some(old_id) => self.shutdown_provider_if_unused(old_id)
    None => Ok(())
  }
}

///|
/// Shut down and remove a provider only after its last binding is gone.
fn Api::shutdown_provider_if_unused(
  self : Api,
  provider_id : String,
) -> Result[Unit, EvaluationError] {
  if self.is_provider_bound(provider_id) {
    return Ok(())
  }
  let current = self.state.val
  match current.providers.get(provider_id) {
    None => Ok(())
    Some(entry) => {
      entry.provider.unsubscribe_events(entry.event_subscription_id)
      let result = entry.provider.shutdown()
      let providers = current.providers.copy()
      providers.update(provider_id, fn(_) { None })
      let scoped_domains = current.scoped_domains.copy()
      scoped_domains.update(provider_id, fn(_) { None })
      self.state.val = { ..current, providers, scoped_domains, }
      result
    }
  }
}

///|
/// Shut down each registered provider once and restore the empty no-op state.
pub fn Api::shutdown(self : Api) -> Result[Unit, EvaluationError] {
  let current = self.state.val
  let entries = current.providers.to_array()
  let mut first_error : EvaluationError? = None
  for (_, entry) in entries {
    entry.provider.unsubscribe_events(entry.event_subscription_id)
    match entry.provider.shutdown() {
      Ok(_) => ()
      Err(error) => if first_error is None { first_error = Some(error) }
    }
  }
  self.state.val = ApiState::empty()
  match first_error {
    Some(error) => Err(error)
    None => Ok(())
  }
}
