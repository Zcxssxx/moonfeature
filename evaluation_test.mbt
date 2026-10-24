///|
struct ContextProvider {}

///|
impl @moonfeature.Provider for ContextProvider with fn metadata(_self) {
  @moonfeature.ProviderMetadata::new("context-test", "1.0")
}

///|
impl @moonfeature.Provider for ContextProvider with fn initialize(
  _self,
  _context,
  _domain,
) {
  Ok(())
}

///|
impl @moonfeature.Provider for ContextProvider with fn shutdown(_self) {
  Ok(())
}

///|
impl @moonfeature.Provider for ContextProvider with fn status(_self) {
  @moonfeature.ProviderStatus::Ready
}

///|
impl @moonfeature.Provider for ContextProvider with fn resolve(
  _self,
  key,
  expected,
  context,
) {
  if key == "missing" {
    return Err(
      @moonfeature.EvaluationError::new(
        @moonfeature.ErrorCode::FlagNotFound,
        "unknown flag",
      ),
    )
  }
  let value = if key == "wrong" {
    @moonfeature.FlagValue::String("not a boolean")
  } else if key == "tier" {
    match context.get_attribute("tier") {
      Some(value) => value
      None => @moonfeature.FlagValue::String("none")
    }
  } else {
    match expected {
      @moonfeature.ValueType::Boolean => @moonfeature.FlagValue::Boolean(true)
      @moonfeature.ValueType::Number => @moonfeature.FlagValue::Number(42.5)
      @moonfeature.ValueType::String =>
        @moonfeature.FlagValue::String("variant")
      @moonfeature.ValueType::Json =>
        @moonfeature.FlagValue::Json(Json::object({ "enabled": Json(true) }))
    }
  }
  Ok(
    @moonfeature.ProviderResolution::new(value)
    .with_variant("v1")
    .with_reason(@moonfeature.ResolutionReason::Static),
  )
}

///|
test "an API without a provider returns all four caller defaults" {
  let client = @moonfeature.Api::new().client()
  let context = @moonfeature.EvaluationContext::empty()
  assert_eq(client.get_boolean_value("enabled", false, context), false)
  assert_eq(client.get_number_value("limit", 2.5, context), 2.5)
  assert_eq(client.get_string_value("color", "blue", context), "blue")
  assert_eq(
    client.get_json_value(
      "settings",
      Json::object({ "mode": Json("safe") }),
      context,
    ),
    Json::object({ "mode": Json("safe") }),
  )
  let details = client.get_string_details("color", "blue", context)
  assert_eq(details.value().as_string(), Some("blue"))
  assert_eq(details.reason(), Some(@moonfeature.ResolutionReason::Default))
  assert_eq(details.error_code(), None)
}

///|
test "API and client contexts merge before provider resolution" {
  let api = @moonfeature.Api::new()
  let provider : &@moonfeature.Provider = ContextProvider::{ }
    as &@moonfeature.Provider
  api.set_provider(provider)
  api.set_context(
    @moonfeature.EvaluationContext::empty().with_attribute(
      "tier",
      @moonfeature.FlagValue::String("global"),
    ),
  )
  let client = api.client()
  client.set_context(
    @moonfeature.EvaluationContext::empty().with_attribute(
      "tier",
      @moonfeature.FlagValue::String("client"),
    ),
  )
  let invocation = @moonfeature.EvaluationContext::empty().with_attribute(
    "tier",
    @moonfeature.FlagValue::String("request"),
  )
  assert_eq(client.get_string_value("tier", "default", invocation), "request")
  assert_eq(
    client.get_string_value(
      "tier",
      "default",
      @moonfeature.EvaluationContext::empty(),
    ),
    "client",
  )
}

///|
test "typed evaluations preserve provider details and safely fall back" {
  let api = @moonfeature.Api::new()
  let provider : &@moonfeature.Provider = ContextProvider::{ }
    as &@moonfeature.Provider
  api.set_provider(provider)
  let client = api.client()
  let context = @moonfeature.EvaluationContext::empty()
  assert_eq(client.get_boolean_value("enabled", false, context), true)
  assert_eq(client.get_number_value("limit", 0.0, context), 42.5)
  assert_eq(client.get_string_value("color", "default", context), "variant")
  let json = client.get_json_value("settings", Json::null(), context)
  assert_eq(json, Json::object({ "enabled": Json(true) }))
  let details = client.get_boolean_details("enabled", false, context)
  assert_eq(details.flag_key(), "enabled")
  assert_eq(details.variant(), Some("v1"))
  assert_eq(details.reason(), Some(@moonfeature.ResolutionReason::Static))
  assert_eq(client.get_boolean_value("wrong", false, context), false)
  assert_eq(
    client.get_boolean_details("wrong", false, context).error_code(),
    Some(@moonfeature.ErrorCode::TypeMismatch),
  )
  assert_eq(client.get_string_value("missing", "safe", context), "safe")
  assert_eq(
    client.get_string_details("missing", "safe", context).error_code(),
    Some(@moonfeature.ErrorCode::FlagNotFound),
  )
}

///|
test "API instances keep their global contexts isolated" {
  let first = @moonfeature.Api::new()
  let second = @moonfeature.Api::new()
  first.set_context(
    @moonfeature.EvaluationContext::empty().with_targeting_key("first-user"),
  )
  assert_eq(first.context().targeting_key(), Some("first-user"))
  assert_eq(second.context().targeting_key(), None)
}
