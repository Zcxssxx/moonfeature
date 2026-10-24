///|
/// Shared mutable state owned by one API instance.
priv struct ProviderEntry {
  provider : &Provider
  event_subscription_id : Int32
}

///|
struct ApiState {
  context : EvaluationContext
  default_provider_id : String?
  domain_providers : Map[String, String]
  providers : Map[String, ProviderEntry]
  scoped_domains : Map[String, String]
  api_event_handlers : Array[ApiEventHandlerEntry]
  client_event_handlers : Array[ClientEventHandlerEntry]
  event_handler_errors : Array[EvaluationError]
  next_event_handler_id : Int32
}

///|
fn ApiState::empty() -> ApiState {
  {
    context: EvaluationContext::empty(),
    default_provider_id: None,
    domain_providers: Map([]),
    providers: Map([]),
    scoped_domains: Map([]),
    api_event_handlers: [],
    client_event_handlers: [],
    event_handler_errors: [],
    next_event_handler_id: 1,
  }
}

///|
/// An isolated OpenFeature API instance. Copying this handle shares its state.
pub struct Api {
  state : @ref.Ref[ApiState]
}

///|
/// Create an isolated API instance with no provider and an empty context.
pub fn Api::new() -> Api {
  { state: @ref.Ref(ApiState::empty()), }
}

///|
/// Set the global evaluation context for this API instance.
pub fn Api::set_context(self : Api, context : EvaluationContext) -> Unit {
  let current = self.state.val
  self.state.val = { ..current, context, }
}

///|
/// Read this API instance's global context.
pub fn Api::context(self : Api) -> EvaluationContext {
  self.state.val.context
}

///|
/// Bind the default provider and initialize it before replacing the current one.
pub fn Api::set_provider(
  self : Api,
  provider : &Provider,
) -> Result[Unit, EvaluationError] {
  self.bind_provider(None, provider)
}

///|
/// Bind a provider to one domain and initialize it before replacing the current one.
pub fn Api::set_provider_for_domain(
  self : Api,
  domain : String,
  provider : &Provider,
) -> Result[Unit, EvaluationError] {
  self.bind_provider(Some(domain), provider)
}

///|
/// Remove a domain binding and shut down its provider if no bindings remain.
pub fn Api::remove_provider_for_domain(
  self : Api,
  domain : String,
) -> Result[Unit, EvaluationError] {
  let state = self.state.val
  match state.domain_providers.get(domain) {
    None => Ok(())
    Some(provider_id) => {
      let domain_providers = state.domain_providers.copy()
      domain_providers.update(domain, fn(_) { None })
      self.state.val = { ..state, domain_providers, }
      self.shutdown_provider_if_unused(provider_id)
    }
  }
}

///|
/// Create a client using this API instance.
pub fn Api::client(self : Api) -> Client {
  { api: self, domain: None, context: @ref.Ref(EvaluationContext::empty()), }
}

///|
/// Create a client associated with a provider domain.
pub fn Api::client_for_domain(self : Api, domain : String) -> Client {
  {
    api: self,
    domain: Some(domain),
    context: @ref.Ref(EvaluationContext::empty()),
  }
}

///|
/// Look up provider metadata for a domain, falling back to the default provider.
pub fn Api::provider_metadata(
  self : Api,
  domain : String?,
) -> ProviderMetadata? {
  match self.provider_for_domain(domain) {
    Some(provider) => Some(provider.metadata())
    None => None
  }
}

///|
/// Return the shared process-wide API handle.
pub fn Api::global() -> Api {
  process_api
}

///|
let process_api : Api = Api::new()

///|
fn Api::provider_for_domain(self : Api, domain : String?) -> &Provider? {
  let state = self.state.val
  let provider_id = self.provider_id_for_domain(domain)
  match provider_id {
    Some(id) =>
      match state.providers.get(id) {
        Some(entry) => Some(entry.provider)
        None => None
      }
    None => None
  }
}

///|
fn Api::provider_id_for_domain(self : Api, domain : String?) -> String? {
  let state = self.state.val
  match domain {
    Some(domain) =>
      match state.domain_providers.get(domain) {
        Some(id) => Some(id)
        None => state.default_provider_id
      }
    None => state.default_provider_id
  }
}

///|
fn Api::is_provider_bound(self : Api, provider_id : String) -> Bool {
  let state = self.state.val
  if state.default_provider_id == Some(provider_id) {
    return true
  }
  for (_, current_id) in state.domain_providers.to_array() {
    if current_id == provider_id {
      return true
    }
  }
  false
}
