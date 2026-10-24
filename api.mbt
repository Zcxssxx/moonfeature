///|
/// Shared mutable state owned by one API instance.
struct ApiState {
  context : EvaluationContext
  default_provider : &Provider?
}

///|
/// An isolated OpenFeature API instance. Copying this handle shares its state.
pub struct Api {
  state : @ref.Ref[ApiState]
}

///|
/// Create an isolated API instance with no provider and an empty context.
pub fn Api::new() -> Api {
  {
    state: @ref.Ref({
      context: EvaluationContext::empty(),
      default_provider: None,
    }),
  }
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
/// Register the default provider for this API instance.
/// Lifecycle guarantees are applied by the provider-binding layer.
pub fn Api::set_provider(self : Api, provider : &Provider) -> Unit {
  let current = self.state.val
  self.state.val = { ..current, default_provider: Some(provider), }
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
/// Return the shared process-wide API handle.
pub fn Api::global() -> Api {
  process_api
}

///|
let process_api : Api = Api::new()

///|
fn Api::default_provider(self : Api) -> &Provider? {
  self.state.val.default_provider
}
