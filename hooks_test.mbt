///|
struct HookProbeProvider {
  id : String
  value : String
  resolve_calls : @ref.Ref[Int32]
  hooks : @ref.Ref[Array[@moonfeature.Hook]]
  trace : @ref.Ref[Array[String]]
  fail_resolution : Bool
}

///|
fn hook_probe_provider(
  id : String,
  value : String,
  trace : @ref.Ref[Array[String]],
) -> HookProbeProvider {
  {
    id,
    value,
    resolve_calls: @ref.Ref(0),
    hooks: @ref.Ref([]),
    trace,
    fail_resolution: false,
  }
}

///|
impl @moonfeature.Provider for HookProbeProvider with fn metadata(self) {
  @moonfeature.ProviderMetadata::new(self.id, "1.0")
}

///|
impl @moonfeature.Provider for HookProbeProvider with fn instance_id(self) {
  self.id
}

///|
impl @moonfeature.Provider for HookProbeProvider with fn domain_scoped(_self) {
  false
}

///|
impl @moonfeature.Provider for HookProbeProvider with fn initialize(
  _self,
  _context,
  _domain,
) {
  Ok(())
}

///|
impl @moonfeature.Provider for HookProbeProvider with fn shutdown(_self) {
  Ok(())
}

///|
impl @moonfeature.Provider for HookProbeProvider with fn status(_self) {
  @moonfeature.ProviderStatus::Ready
}

///|
impl @moonfeature.Provider for HookProbeProvider with fn resolve(
  self,
  _key,
  _expected,
  context,
) {
  self.resolve_calls.val = self.resolve_calls.val + 1
  self.trace.val.push("resolve")
  if self.fail_resolution {
    return Err(
      @moonfeature.EvaluationError::new(
        @moonfeature.ErrorCode::ProviderFailure,
        "synthetic provider failure",
      ),
    )
  }
  match context.get_attribute("tier") {
    Some(@moonfeature.FlagValue::String(value)) =>
      Ok(
        @moonfeature.ProviderResolution::new(
          @moonfeature.FlagValue::String(value),
        ),
      )
    _ =>
      Ok(
        @moonfeature.ProviderResolution::new(
          @moonfeature.FlagValue::String(self.value),
        ),
      )
  }
}

///|
impl @moonfeature.Provider for HookProbeProvider with fn evaluation_hooks(self) {
  self.hooks.val
}

///|
fn hook_json_string(value : Json) -> String? {
  if value is String(text) {
    Some(text)
  } else {
    None
  }
}

///|
fn recording_hook(
  label : String,
  expected_tier : String?,
  next_tier : String,
  trace : @ref.Ref[Array[String]],
) -> @moonfeature.Hook {
  @moonfeature.Hook::new()
  .with_data_factory(fn() { Json(label) })
  .with_before(fn(hook_context, data, hints) {
    trace.val.push("before-" + label)
    let current_tier = match
      hook_context.evaluation_context().get_attribute("tier") {
      Some(@moonfeature.FlagValue::String(value)) => Some(value)
      _ => None
    }
    if hook_json_string(data) != Some(label) ||
      hints != Json::object({ "request": Json("checkout") }) ||
      current_tier != expected_tier {
      return Err(
        @moonfeature.EvaluationError::new(
          @moonfeature.ErrorCode::HookFailure,
          "before hook did not receive expected context, data, or hints",
        ),
      )
    }
    let changes = @moonfeature.EvaluationContext::empty().with_attribute(
      "tier",
      @moonfeature.FlagValue::String(next_tier),
    )
    Ok(@moonfeature.HookBeforeResult::new(changes, Json(next_tier)))
  })
  .with_after(fn(_context, _details, data, hints) {
    trace.val.push("after-" + label)
    if hook_json_string(data) == Some(next_tier) &&
      hints == Json::object({ "request": Json("checkout") }) {
      Ok(())
    } else {
      Err(
        @moonfeature.EvaluationError::new(
          @moonfeature.ErrorCode::HookFailure,
          "after hook did not receive its private data and hints",
        ),
      )
    }
  })
  .with_finally(fn(_context, details, data, _hints) {
    trace.val.push("finally-" + label)
    if hook_json_string(data) == Some(next_tier) &&
      details.value().as_string() == Some("provider") {
      Ok(())
    } else {
      Err(
        @moonfeature.EvaluationError::new(
          @moonfeature.ErrorCode::HookFailure,
          "finally hook did not receive its private data",
        ),
      )
    }
  })
}

///|
test "hooks run in scope order and share private per-evaluation data" {
  let trace : @ref.Ref[Array[String]] = @ref.Ref([])
  let api = @moonfeature.Api::new()
  let api_hook = recording_hook("api", Some("invocation"), "api", trace)
  let _ = api.add_hook(api_hook)
  let provider = hook_probe_provider("hook-order-provider", "fallback", trace)
  provider.hooks.val = [
    recording_hook("provider", Some("invocation"), "provider", trace),
  ]
  let provider_object : &@moonfeature.Provider = provider
    as &@moonfeature.Provider
  assert_eq(api.set_provider(provider_object), Ok(()))
  let client = api.client()
  let _ = client.add_hook(
    recording_hook("client", Some("api"), "client", trace),
  )
  let options = @moonfeature.EvaluationOptions::new(
      @moonfeature.EvaluationContext::empty().with_attribute(
        "tier",
        @moonfeature.FlagValue::String("invocation"),
      ),
    )
    .with_hook(
      recording_hook("invocation", Some("client"), "invocation", trace),
    )
    .with_hints(Json::object({ "request": Json("checkout") }))
  let details = client.get_string_details_with_options(
    "tier", "default", options,
  )
  assert_eq(trace.val, [
    "before-api", "before-client", "before-invocation", "before-provider", "resolve",
    "after-provider", "after-invocation", "after-client", "after-api", "finally-provider",
    "finally-invocation", "finally-client", "finally-api",
  ])
  assert_eq(details.value().as_string(), Some("provider"))
}

///|
test "before failure skips provider and contains error hook failures" {
  let trace : @ref.Ref[Array[String]] = @ref.Ref([])
  let api = @moonfeature.Api::new()
  let provider = hook_probe_provider("hook-before-failure", "unused", trace)
  let provider_object : &@moonfeature.Provider = provider
    as &@moonfeature.Provider
  assert_eq(api.set_provider(provider_object), Ok(()))
  let earlier_api_hook = @moonfeature.Hook::new().with_error(fn(
    _context,
    _error,
    _data,
    _hints,
  ) {
    trace.val.push("error-api-later")
    Ok(())
  })
  let _ = api.add_hook(earlier_api_hook)
  let api_hook = @moonfeature.Hook::new()
    .with_before(fn(_context, _data, _hints) {
      trace.val.push("before-api")
      Err(
        @moonfeature.EvaluationError::new(
          @moonfeature.ErrorCode::HookFailure,
          "before rejected evaluation",
        ),
      )
    })
    .with_error(fn(_context, _error, _data, _hints) {
      trace.val.push("error-api")
      Err(
        @moonfeature.EvaluationError::new(
          @moonfeature.ErrorCode::HookFailure,
          "error hook failed",
        ),
      )
    })
    .with_finally(fn(_context, _details, _data, _hints) {
      trace.val.push("finally-api")
      Ok(())
    })
  let _ = api.add_hook(api_hook)
  let client = api.client()
  let client_hook = @moonfeature.Hook::new()
    .with_before(fn(_context, _data, _hints) {
      trace.val.push("before-client")
      Ok(
        @moonfeature.HookBeforeResult::new(
          @moonfeature.EvaluationContext::empty(),
          Json::empty_object(),
        ),
      )
    })
    .with_error(fn(_context, _error, _data, _hints) {
      trace.val.push("error-client")
      Ok(())
    })
    .with_finally(fn(_context, _details, _data, _hints) {
      trace.val.push("finally-client")
      Err(
        @moonfeature.EvaluationError::new(
          @moonfeature.ErrorCode::HookFailure,
          "finally hook failed",
        ),
      )
    })
  let _ = client.add_hook(client_hook)
  let details = client.get_boolean_details_with_options(
    "enabled",
    true,
    @moonfeature.EvaluationOptions::new(@moonfeature.EvaluationContext::empty()),
  )
  assert_eq(details.value().as_boolean(), Some(true))
  assert_eq(details.error_code(), Some(@moonfeature.ErrorCode::HookFailure))
  assert_eq(provider.resolve_calls.val, 0)
  assert_eq(trace.val, [
    "before-api", "error-client", "error-api", "error-api-later", "finally-client",
    "finally-api",
  ])
  assert_eq(api.drain_hook_errors().length(), 2)
}

///|
test "after failure stops later after hooks then runs error and finally stages" {
  let trace : @ref.Ref[Array[String]] = @ref.Ref([])
  let api = @moonfeature.Api::new()
  let api_hook = @moonfeature.Hook::new()
    .with_after(fn(_context, _details, _data, _hints) {
      trace.val.push("after-api")
      Ok(())
    })
    .with_error(fn(_context, _error, _data, _hints) {
      trace.val.push("error-api")
      Ok(())
    })
    .with_finally(fn(_context, _details, _data, _hints) {
      trace.val.push("finally-api")
      Ok(())
    })
  let _ = api.add_hook(api_hook)
  let client = api.client()
  let client_hook = @moonfeature.Hook::new()
    .with_after(fn(_context, _details, _data, _hints) {
      trace.val.push("after-client")
      Err(
        @moonfeature.EvaluationError::new(
          @moonfeature.ErrorCode::HookFailure,
          "after rejected evaluation",
        ),
      )
    })
    .with_error(fn(_context, _error, _data, _hints) {
      trace.val.push("error-client")
      Ok(())
    })
    .with_finally(fn(_context, _details, _data, _hints) {
      trace.val.push("finally-client")
      Ok(())
    })
  let _ = client.add_hook(client_hook)
  let provider = hook_probe_provider("hook-after-failure", "resolved", trace)
  let provider_object : &@moonfeature.Provider = provider
    as &@moonfeature.Provider
  assert_eq(api.set_provider(provider_object), Ok(()))
  trace.val = []
  let details = client.get_string_details_with_options(
    "feature",
    "caller-default",
    @moonfeature.EvaluationOptions::new(@moonfeature.EvaluationContext::empty()),
  )
  assert_eq(details.value().as_string(), Some("caller-default"))
  assert_eq(details.error_code(), Some(@moonfeature.ErrorCode::HookFailure))
  assert_eq(trace.val, [
    "resolve", "after-client", "error-client", "error-api", "finally-client", "finally-api",
  ])
}

///|
test "provider failure skips after hooks and unwinds error and finally hooks" {
  let trace : @ref.Ref[Array[String]] = @ref.Ref([])
  let api = @moonfeature.Api::new()
  let api_hook = @moonfeature.Hook::new()
    .with_after(fn(_context, _details, _data, _hints) {
      trace.val.push("after-api")
      Ok(())
    })
    .with_error(fn(_context, _error, _data, _hints) {
      trace.val.push("error-api")
      Ok(())
    })
    .with_finally(fn(_context, _details, _data, _hints) {
      trace.val.push("finally-api")
      Ok(())
    })
  let _ = api.add_hook(api_hook)
  let client = api.client()
  let client_hook = @moonfeature.Hook::new()
    .with_after(fn(_context, _details, _data, _hints) {
      trace.val.push("after-client")
      Ok(())
    })
    .with_error(fn(_context, _error, _data, _hints) {
      trace.val.push("error-client")
      Ok(())
    })
    .with_finally(fn(_context, _details, _data, _hints) {
      trace.val.push("finally-client")
      Ok(())
    })
  let _ = client.add_hook(client_hook)
  let provider = {
    ..hook_probe_provider("hook-provider-failure", "unused", trace),
    fail_resolution: true,
  }
  let provider_object : &@moonfeature.Provider = provider
    as &@moonfeature.Provider
  assert_eq(api.set_provider(provider_object), Ok(()))
  trace.val = []
  let details = client.get_string_details_with_options(
    "feature",
    "caller-default",
    @moonfeature.EvaluationOptions::new(@moonfeature.EvaluationContext::empty()),
  )
  assert_eq(details.value().as_string(), Some("caller-default"))
  assert_eq(details.error_code(), Some(@moonfeature.ErrorCode::ProviderFailure))
  assert_eq(trace.val, [
    "resolve", "error-client", "error-api", "finally-client", "finally-api",
  ])
}

///|
test "API and client hooks can be removed independently" {
  let trace : @ref.Ref[Array[String]] = @ref.Ref([])
  let api = @moonfeature.Api::new()
  let api_id = api.add_hook(
    @moonfeature.Hook::new().with_before(fn(_context, _data, _hints) {
      trace.val.push("api")
      Ok(
        @moonfeature.HookBeforeResult::new(
          @moonfeature.EvaluationContext::empty(),
          Json::empty_object(),
        ),
      )
    }),
  )
  let client = api.client()
  let client_id = client.add_hook(
    @moonfeature.Hook::new().with_before(fn(_context, _data, _hints) {
      trace.val.push("client")
      Ok(
        @moonfeature.HookBeforeResult::new(
          @moonfeature.EvaluationContext::empty(),
          Json::empty_object(),
        ),
      )
    }),
  )
  assert_true(api.remove_hook(api_id))
  assert_false(api.remove_hook(api_id))
  let details = client.get_string_details_with_options(
    "flag",
    "default",
    @moonfeature.EvaluationOptions::new(@moonfeature.EvaluationContext::empty()),
  )
  assert_eq(details.value().as_string(), Some("default"))
  assert_eq(trace.val, ["client"])
  assert_true(client.remove_hook(client_id))
  trace.val = []
  let _ = client.get_string_details_with_options(
    "flag",
    "default",
    @moonfeature.EvaluationOptions::new(@moonfeature.EvaluationContext::empty()),
  )
  assert_eq(trace.val, [])
}
