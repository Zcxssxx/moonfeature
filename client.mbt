///|
/// Per-application client with explicit evaluation context and optional domain.
pub struct Client {
  api : Api
  domain : String?
  context : @ref.Ref[EvaluationContext]
}

///|
/// Return the immutable domain assigned to this client.
pub fn Client::domain(self : Client) -> String? {
  self.domain
}

///|
/// Read this client's evaluation context.
pub fn Client::context(self : Client) -> EvaluationContext {
  self.context.val
}

///|
/// Replace this client's evaluation context.
pub fn Client::set_context(self : Client, context : EvaluationContext) -> Unit {
  self.context.val = context
}

///|
/// Merge API, client, and invocation contexts in order of increasing priority.
fn Client::merged_context(
  self : Client,
  invocation_context : EvaluationContext,
) -> EvaluationContext {
  self.api.context().merge(self.context.val).merge(invocation_context)
}

///|
/// Produce a caller-default resolution with optional failure details.
fn fallback_details(
  flag_key : String,
  default_value : FlagValue,
  error : EvaluationError?,
) -> ResolutionDetails {
  let reason = match error {
    Some(_) => Some(ResolutionReason::Error)
    None => Some(ResolutionReason::Default)
  }
  let error_code = match error {
    Some(value) => Some(value.code())
    None => None
  }
  let error_message = match error {
    Some(value) => Some(value.message())
    None => None
  }
  {
    flag_key,
    value: default_value.snapshot(),
    variant: None,
    reason,
    flag_metadata: Json::empty_object(),
    error_code,
    error_message,
  }
}

///|
/// Resolve a flag and apply provider/default/type-safety semantics.
fn Client::resolve(
  self : Client,
  flag_key : String,
  default_value : FlagValue,
  invocation_context : EvaluationContext,
) -> ResolutionDetails {
  let context = self.merged_context(invocation_context)
  match self.api.provider_for_domain(self.domain) {
    None => fallback_details(flag_key, default_value, None)
    Some(provider) =>
      match provider.resolve(flag_key, default_value.value_type(), context) {
        Ok(result) => {
          let value = result.value()
          if value.value_type() != default_value.value_type() {
            fallback_details(
              flag_key,
              default_value,
              Some(
                EvaluationError::new(
                  ErrorCode::TypeMismatch,
                  "provider returned a value of the wrong type",
                ),
              ),
            )
          } else {
            {
              flag_key,
              value,
              variant: result.variant(),
              reason: result.reason(),
              flag_metadata: result.flag_metadata(),
              error_code: None,
              error_message: None,
            }
          }
        }
        Err(error) => fallback_details(flag_key, default_value, Some(error))
      }
  }
}

///|
/// Evaluate a Boolean flag and return the caller's default on failure.
pub fn Client::get_boolean_value(
  self : Client,
  flag_key : String,
  default_value : Bool,
  context : EvaluationContext,
) -> Bool {
  match self.get_boolean_details(flag_key, default_value, context).value() {
    FlagValue::Boolean(value) => value
    _ => default_value
  }
}

///|
/// Evaluate a Boolean flag and return full resolution details.
pub fn Client::get_boolean_details(
  self : Client,
  flag_key : String,
  default_value : Bool,
  context : EvaluationContext,
) -> ResolutionDetails {
  self.resolve(flag_key, FlagValue::Boolean(default_value), context)
}

///|
/// Evaluate a Number flag and return the caller's default on failure.
pub fn Client::get_number_value(
  self : Client,
  flag_key : String,
  default_value : Double,
  context : EvaluationContext,
) -> Double {
  match self.get_number_details(flag_key, default_value, context).value() {
    FlagValue::Number(value) => value
    _ => default_value
  }
}

///|
/// Evaluate a Number flag and return full resolution details.
pub fn Client::get_number_details(
  self : Client,
  flag_key : String,
  default_value : Double,
  context : EvaluationContext,
) -> ResolutionDetails {
  self.resolve(flag_key, FlagValue::Number(default_value), context)
}

///|
/// Evaluate a String flag and return the caller's default on failure.
pub fn Client::get_string_value(
  self : Client,
  flag_key : String,
  default_value : String,
  context : EvaluationContext,
) -> String {
  match self.get_string_details(flag_key, default_value, context).value() {
    FlagValue::String(value) => value
    _ => default_value
  }
}

///|
/// Evaluate a String flag and return full resolution details.
pub fn Client::get_string_details(
  self : Client,
  flag_key : String,
  default_value : String,
  context : EvaluationContext,
) -> ResolutionDetails {
  self.resolve(flag_key, FlagValue::String(default_value), context)
}

///|
/// Evaluate a JSON flag and return the caller's default on failure.
pub fn Client::get_json_value(
  self : Client,
  flag_key : String,
  default_value : Json,
  context : EvaluationContext,
) -> Json {
  let fallback = clone_json(default_value)
  match self.get_json_details(flag_key, default_value, context).value() {
    FlagValue::Json(value) => value
    _ => fallback
  }
}

///|
/// Evaluate a JSON flag and return full resolution details.
pub fn Client::get_json_details(
  self : Client,
  flag_key : String,
  default_value : Json,
  context : EvaluationContext,
) -> ResolutionDetails {
  self.resolve(flag_key, FlagValue::Json(default_value), context)
}

///|
/// Return the active provider status for this client's domain.
pub fn Client::status(self : Client) -> ProviderStatus {
  match self.api.provider_for_domain(self.domain) {
    Some(provider) => provider.status()
    None => ProviderStatus::NotReady
  }
}

///|
/// Return metadata for the provider selected by this client.
pub fn Client::provider_metadata(self : Client) -> ProviderMetadata? {
  self.api.provider_metadata(self.domain)
}
