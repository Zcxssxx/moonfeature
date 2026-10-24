///|
/// Information available to a hook for one flag evaluation.
pub struct HookContext {
  flag_key : String
  value_type : ValueType
  default_value : FlagValue
  evaluation_context : EvaluationContext
}

///|
fn HookContext::new(
  flag_key : String,
  value_type : ValueType,
  default_value : FlagValue,
  evaluation_context : EvaluationContext,
) -> HookContext {
  {
    flag_key,
    value_type,
    default_value: default_value.snapshot(),
    evaluation_context,
  }
}

///|
/// Return the evaluated flag key.
pub fn HookContext::flag_key(self : HookContext) -> String {
  self.flag_key
}

///|
/// Return the requested value type.
pub fn HookContext::value_type(self : HookContext) -> ValueType {
  self.value_type
}

///|
/// Return a detached caller default.
pub fn HookContext::default_value(self : HookContext) -> FlagValue {
  self.default_value.snapshot()
}

///|
/// Return the current merged evaluation context.
pub fn HookContext::evaluation_context(self : HookContext) -> EvaluationContext {
  self.evaluation_context
}

///|
/// Result of a before hook: an overlay context and updated private data.
pub struct HookBeforeResult {
  context_changes : EvaluationContext
  data : Json
}

///|
/// Create a before-hook result.
pub fn HookBeforeResult::new(
  context_changes : EvaluationContext,
  data : Json,
) -> HookBeforeResult {
  { context_changes, data: clone_json(data), }
}

///|
fn HookBeforeResult::context_changes(
  self : HookBeforeResult,
) -> EvaluationContext {
  self.context_changes
}

///|
fn HookBeforeResult::data(self : HookBeforeResult) -> Json {
  clone_json(self.data)
}

///|
/// Before callbacks may add evaluation-context values and update hook data.
pub type BeforeHook = (HookContext, Json, Json) -> Result[
  HookBeforeResult,
  EvaluationError,
]

///|
/// After callbacks observe successful resolution details.
pub type AfterHook = (HookContext, ResolutionDetails, Json, Json) -> Result[
  Unit,
  EvaluationError,
]

///|
/// Error callbacks observe a failed before, provider, or after stage.
pub type ErrorHook = (HookContext, EvaluationError, Json, Json) -> Result[
  Unit,
  EvaluationError,
]

///|
/// Finally callbacks run after after/error processing.
pub type FinallyHook = (HookContext, Json, Json) -> Result[
  Unit,
  EvaluationError,
]

///|
/// A factory creates data private to one hook's single evaluation.
pub type HookDataFactory = () -> Json

///|
/// A reusable set of callbacks. Each evaluation receives fresh hook data.
pub struct Hook {
  before : BeforeHook?
  after : AfterHook?
  error : ErrorHook?
  on_finally : FinallyHook?
  data_factory : HookDataFactory?
}

///|
/// Create a hook with no callbacks and empty-object private data.
pub fn Hook::new() -> Hook {
  {
    before: None,
    after: None,
    error: None,
    on_finally: None,
    data_factory: None,
  }
}

///|
/// Return a copy with a before callback.
pub fn Hook::with_before(self : Hook, callback : BeforeHook) -> Hook {
  { ..self, before: Some(callback), }
}

///|
/// Return a copy with an after callback.
pub fn Hook::with_after(self : Hook, callback : AfterHook) -> Hook {
  { ..self, after: Some(callback), }
}

///|
/// Return a copy with an error callback.
pub fn Hook::with_error(self : Hook, callback : ErrorHook) -> Hook {
  { ..self, error: Some(callback), }
}

///|
/// Return a copy with a finally callback.
pub fn Hook::with_finally(self : Hook, callback : FinallyHook) -> Hook {
  { ..self, on_finally: Some(callback), }
}

///|
/// Return a copy with a per-evaluation private-data factory.
pub fn Hook::with_data_factory(self : Hook, factory : HookDataFactory) -> Hook {
  { ..self, data_factory: Some(factory), }
}

///|
/// Evaluation context, invocation hooks, and read-only hint data for one call.
pub struct EvaluationOptions {
  context : EvaluationContext
  hooks : Array[Hook]
  hints : Json
}

///|
/// Create evaluation options with the invocation context and no extra hooks.
pub fn EvaluationOptions::new(context : EvaluationContext) -> EvaluationOptions {
  { context, hooks: [], hints: Json::empty_object(), }
}

///|
/// Return options with one invocation-scoped hook appended.
pub fn EvaluationOptions::with_hook(
  self : EvaluationOptions,
  hook : Hook,
) -> EvaluationOptions {
  let hooks = self.hooks.copy()
  hooks.push(hook)
  { ..self, hooks, }
}

///|
/// Return options with detached read-only hint data.
pub fn EvaluationOptions::with_hints(
  self : EvaluationOptions,
  hints : Json,
) -> EvaluationOptions {
  { ..self, hints: clone_json(hints), }
}

///|
priv struct ApiHookEntry {
  id : Int32
  hook : Hook
}

///|
priv struct HookExecution {
  hook : Hook
  data : @ref.Ref[Json]
}

///|
fn Hook::execution(self : Hook) -> HookExecution {
  let initial_data = match self.data_factory {
    Some(factory) => factory()
    None => Json::empty_object()
  }
  { hook: self, data: @ref.Ref(clone_json(initial_data)), }
}

///|
fn Api::allocate_hook_id(self : Api) -> Int32 {
  let current = self.state.val
  let id = current.next_hook_id
  self.state.val = { ..current, next_hook_id: id + 1, }
  id
}

///|
/// Register a hook for every evaluation made through this API.
pub fn Api::add_hook(self : Api, hook : Hook) -> Int32 {
  let id = self.allocate_hook_id()
  let current = self.state.val
  let api_hooks = current.api_hooks.copy()
  api_hooks.push(ApiHookEntry::{ id, hook, })
  self.state.val = { ..current, api_hooks, }
  id
}

///|
/// Remove an API hook by its registration identifier.
pub fn Api::remove_hook(self : Api, id : Int32) -> Bool {
  let current = self.state.val
  let mut found = false
  let api_hooks = current.api_hooks.filter(fn(entry) {
    if entry.id == id {
      found = true
      false
    } else {
      true
    }
  })
  if found {
    self.state.val = { ..current, api_hooks, }
  }
  found
}

///|
/// Return and clear errors reported by error/finally hook callbacks.
pub fn Api::drain_hook_errors(self : Api) -> Array[EvaluationError] {
  let current = self.state.val
  let errors = current.hook_errors
  self.state.val = { ..current, hook_errors: [], }
  errors
}

///|
/// Register a hook for evaluations made through this client.
pub fn Client::add_hook(self : Client, hook : Hook) -> Int32 {
  let id = self.api.allocate_hook_id()
  let hooks = self.hooks.val.copy()
  hooks.push((id, hook))
  self.hooks.val = hooks
  id
}

///|
/// Remove a client hook by its registration identifier.
pub fn Client::remove_hook(self : Client, id : Int32) -> Bool {
  let current = self.hooks.val
  let mut found = false
  let hooks = current.filter(fn(entry) {
    match entry {
      (current_id, _) =>
        if current_id == id {
          found = true
          false
        } else {
          true
        }
    }
  })
  if found {
    self.hooks.val = hooks
  }
  found
}

///|
fn Api::record_hook_error(self : Api, error : EvaluationError) -> Unit {
  let current = self.state.val
  let hook_errors = current.hook_errors.copy()
  hook_errors.push(error)
  self.state.val = { ..current, hook_errors, }
}

///|
fn reverse_hook_executions(
  executions : Array[HookExecution],
  remaining : Int32,
  reversed : Array[HookExecution],
) -> Unit {
  if remaining > 0 {
    reversed.push(executions[remaining - 1])
    reverse_hook_executions(executions, remaining - 1, reversed)
  }
}

///|
fn reversed_hook_executions(
  executions : Array[HookExecution],
) -> Array[HookExecution] {
  let reversed : Array[HookExecution] = []
  reverse_hook_executions(executions, executions.length(), reversed)
  reversed
}
