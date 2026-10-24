///|
struct LocalProviderState {
  config : Config
  status : @moonfeature.ProviderStatus
  next_subscription_id : Int32
  listeners : Array[(Int32, @moonfeature.ProviderEventSink)]
}

///|
/// Deterministic synchronous provider backed by a validated in-memory config.
pub struct LocalProvider {
  id : String
  state : @ref.Ref[LocalProviderState]
}

///|
pub extend LocalProvider with @moonfeature.Provider::{
  unsubscribe_events,
  resolve,
  evaluation_hooks,
  instance_id,
  domain_scoped,
  initialize,
  status,
  subscribe_events,
  shutdown,
  metadata,
}

///|
/// Create a local rules provider. The identifier must be unique within its API.
pub fn LocalProvider::new(id : String, config : Config) -> LocalProvider {
  {
    id,
    state: @ref.Ref({
      config,
      status: @moonfeature.ProviderStatus::NotReady,
      next_subscription_id: 1,
      listeners: [],
    }),
  }
}

///|
/// Replace the validated config and announce a broad configuration change.
pub fn LocalProvider::replace_config(
  self : LocalProvider,
  config : Config,
) -> Unit {
  let current = self.state.val
  self.state.val = { ..current, config, }
  self.emit(
    @moonfeature.ProviderEvent::new(
      @moonfeature.ProviderEventKind::ConfigurationChanged,
    ).with_message("local configuration replaced"),
  )
}

///|
/// Return metadata through the public provider contract.
pub fn LocalProvider::provider_metadata(
  self : LocalProvider,
) -> @moonfeature.ProviderMetadata {
  let provider : &@moonfeature.Provider = self as &@moonfeature.Provider
  provider.metadata()
}

///|
fn LocalProvider::emit(
  self : LocalProvider,
  event : @moonfeature.ProviderEvent,
) -> Unit {
  let listeners = self.state.val.listeners.copy()
  for (_, listener) in listeners {
    listener(event)
  }
}

///|
fn result_for(
  value : @moonfeature.FlagValue,
  reason : @moonfeature.ResolutionReason,
  variant : String?,
) -> @moonfeature.ProviderResolution {
  let resolution = @moonfeature.ProviderResolution::new(value).with_reason(
    reason,
  )
  match variant {
    Some(name) => resolution.with_variant(name)
    None => resolution
  }
}

///|
pub impl @moonfeature.Provider for LocalProvider with fn metadata(_self) {
  @moonfeature.ProviderMetadata::new("moonfeature-local", "0.1.0")
}

///|
pub impl @moonfeature.Provider for LocalProvider with fn instance_id(self) {
  self.id
}

///|
pub impl @moonfeature.Provider for LocalProvider with fn domain_scoped(_self) {
  false
}

///|
pub impl @moonfeature.Provider for LocalProvider with fn initialize(
  self,
  _context,
  _domain,
) {
  self.state.val = {
    ..self.state.val,
    status: @moonfeature.ProviderStatus::Ready,
  }
  self.emit(
    @moonfeature.ProviderEvent::new(
      @moonfeature.ProviderEventKind::ProviderReady,
    ),
  )
  Ok(())
}

///|
pub impl @moonfeature.Provider for LocalProvider with fn shutdown(self) {
  self.state.val = {
    ..self.state.val,
    status: @moonfeature.ProviderStatus::Shutdown,
  }
  Ok(())
}

///|
pub impl @moonfeature.Provider for LocalProvider with fn status(self) {
  self.state.val.status
}

///|
pub impl @moonfeature.Provider for LocalProvider with fn resolve(
  self,
  key,
  expected,
  context,
) {
  let state = self.state.val
  match state.config.flags.get(key) {
    None =>
      Err(
        @moonfeature.EvaluationError::new(
          @moonfeature.ErrorCode::FlagNotFound,
          "flag is not present in the local configuration",
        ),
      )
    Some(definition) => {
      if expected != definition.default_value.value_type() {
        return Err(
          @moonfeature.EvaluationError::new(
            @moonfeature.ErrorCode::TypeMismatch,
            "requested type does not match the local flag definition",
          ),
        )
      }
      let mut matched = false
      let mut resolution = result_for(
        definition.default_value,
        @moonfeature.ResolutionReason::Default,
        None,
      )
      for rule in definition.rules {
        if !matched && rule.matches(context) {
          matched = true
          resolution = result_for(
            rule.value,
            @moonfeature.ResolutionReason::TargetingMatch,
            rule.variant,
          )
        }
      }
      if matched {
        Ok(resolution)
      } else {
        match definition.rollout {
          None => Ok(resolution)
          Some(rollout) =>
            match context.targeting_key() {
              None =>
                Err(
                  @moonfeature.EvaluationError::new(
                    @moonfeature.ErrorCode::InvalidContext,
                    "percentage rollout requires a targeting key",
                  ),
                )
              Some(targeting_key) =>
                if rollout_matches(key, targeting_key, rollout.percentage) {
                  Ok(
                    result_for(
                      rollout.value,
                      @moonfeature.ResolutionReason::Split,
                      rollout.variant,
                    ),
                  )
                } else {
                  Ok(resolution)
                }
            }
        }
      }
    }
  }
}

///|
pub impl @moonfeature.Provider for LocalProvider with fn subscribe_events(
  self,
  sink,
) {
  let current = self.state.val
  let id = current.next_subscription_id
  let listeners = current.listeners.copy()
  listeners.push((id, sink))
  self.state.val = { ..current, next_subscription_id: id + 1, listeners, }
  id
}

///|
pub impl @moonfeature.Provider for LocalProvider with fn unsubscribe_events(
  self,
  id,
) {
  let current = self.state.val
  let listeners : Array[(Int32, @moonfeature.ProviderEventSink)] = []
  for (current_id, sink) in current.listeners {
    if current_id != id {
      listeners.push((current_id, sink))
    }
  }
  self.state.val = { ..current, listeners, }
}
