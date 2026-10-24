///|
struct ProviderCounts {
  initialize_calls : Int32
  shutdown_calls : Int32
}

///|
struct ProbeProvider {
  id : String
  value : String
  fail_initialize : Bool
  scoped : Bool
  counts : @ref.Ref[ProviderCounts]
}

///|
fn probe_provider(
  id : String,
  value : String,
  fail_initialize : Bool,
  scoped : Bool,
) -> ProbeProvider {
  {
    id,
    value,
    fail_initialize,
    scoped,
    counts: @ref.Ref({ initialize_calls: 0, shutdown_calls: 0, }),
  }
}

///|
impl @moonfeature.Provider for ProbeProvider with fn metadata(self) {
  @moonfeature.ProviderMetadata::new(self.id, "1.0")
}

///|
impl @moonfeature.Provider for ProbeProvider with fn instance_id(self) {
  self.id
}

///|
impl @moonfeature.Provider for ProbeProvider with fn domain_scoped(self) {
  self.scoped
}

///|
impl @moonfeature.Provider for ProbeProvider with fn initialize(
  self,
  _context,
  _domain,
) {
  let counts = self.counts.val
  self.counts.val = { ..counts, initialize_calls: counts.initialize_calls + 1, }
  if self.fail_initialize {
    Err(
      @moonfeature.EvaluationError::new(
        @moonfeature.ErrorCode::InvalidConfiguration,
        "initialization rejected",
      ),
    )
  } else {
    Ok(())
  }
}

///|
impl @moonfeature.Provider for ProbeProvider with fn shutdown(self) {
  let counts = self.counts.val
  self.counts.val = { ..counts, shutdown_calls: counts.shutdown_calls + 1, }
  Ok(())
}

///|
impl @moonfeature.Provider for ProbeProvider with fn status(self) {
  let counts = self.counts.val
  if counts.shutdown_calls > 0 {
    @moonfeature.ProviderStatus::Shutdown
  } else if counts.initialize_calls > 0 && !self.fail_initialize {
    @moonfeature.ProviderStatus::Ready
  } else {
    @moonfeature.ProviderStatus::NotReady
  }
}

///|
impl @moonfeature.Provider for ProbeProvider with fn resolve(
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
test "failed replacement keeps the active provider and successful replacement shuts it down" {
  let api = @moonfeature.Api::new()
  let old_provider = probe_provider("old", "old-value", false, false)
  let old_object : &@moonfeature.Provider = old_provider
    as &@moonfeature.Provider
  assert_eq(api.set_provider(old_object), Ok(()))
  let client = api.client()
  let failed_provider = probe_provider("bad", "bad-value", true, false)
  let failed_object : &@moonfeature.Provider = failed_provider
    as &@moonfeature.Provider
  match api.set_provider(failed_object) {
    Err(error) =>
      assert_eq(error.code(), @moonfeature.ErrorCode::InvalidConfiguration)
    Ok(_) => assert_true(false)
  }
  assert_eq(
    client.get_string_value(
      "checkout",
      "fallback",
      @moonfeature.EvaluationContext::empty(),
    ),
    "old-value",
  )
  assert_eq(old_provider.counts.val.shutdown_calls, 0)

  let new_provider = probe_provider("new", "new-value", false, false)
  let new_object : &@moonfeature.Provider = new_provider
    as &@moonfeature.Provider
  assert_eq(api.set_provider(new_object), Ok(()))
  assert_eq(old_provider.counts.val.shutdown_calls, 1)
  assert_eq(new_provider.counts.val.initialize_calls, 1)
  assert_eq(
    client.get_string_value(
      "checkout",
      "fallback",
      @moonfeature.EvaluationContext::empty(),
    ),
    "new-value",
  )
}

///|
test "domain providers override the default and scoped providers cannot span domains" {
  let api = @moonfeature.Api::new()
  let default_provider = probe_provider(
    "default", "default-value", false, false,
  )
  let default_object : &@moonfeature.Provider = default_provider
    as &@moonfeature.Provider
  assert_eq(api.set_provider(default_object), Ok(()))

  let scoped_provider = probe_provider("tenant", "tenant-value", false, true)
  let scoped_object : &@moonfeature.Provider = scoped_provider
    as &@moonfeature.Provider
  assert_eq(api.set_provider_for_domain("tenant-a", scoped_object), Ok(()))
  assert_eq(
    api
    .client_for_domain("tenant-a")
    .get_string_value(
      "checkout",
      "fallback",
      @moonfeature.EvaluationContext::empty(),
    ),
    "tenant-value",
  )
  assert_eq(
    api
    .client_for_domain("tenant-b")
    .get_string_value(
      "checkout",
      "fallback",
      @moonfeature.EvaluationContext::empty(),
    ),
    "default-value",
  )
  match api.set_provider_for_domain("tenant-b", scoped_object) {
    Err(error) =>
      assert_eq(error.code(), @moonfeature.ErrorCode::InvalidConfiguration)
    Ok(_) => assert_true(false)
  }
  assert_eq(
    api
    .client_for_domain("tenant-a")
    .get_string_value(
      "checkout",
      "fallback",
      @moonfeature.EvaluationContext::empty(),
    ),
    "tenant-value",
  )
}

///|
test "API shutdown stops providers once and restores default behavior" {
  let api = @moonfeature.Api::new()
  let provider = probe_provider("shutdown", "enabled", false, false)
  let provider_object : &@moonfeature.Provider = provider
    as &@moonfeature.Provider
  assert_eq(api.set_provider(provider_object), Ok(()))
  assert_eq(api.client().status(), @moonfeature.ProviderStatus::Ready)
  assert_eq(api.shutdown(), Ok(()))
  assert_eq(provider.counts.val.shutdown_calls, 1)
  assert_eq(api.client().status(), @moonfeature.ProviderStatus::NotReady)
  assert_eq(
    api
    .client()
    .get_string_value(
      "checkout",
      "fallback",
      @moonfeature.EvaluationContext::empty(),
    ),
    "fallback",
  )
}

///|
test "a shared provider instance initializes and shuts down once across bindings" {
  let api = @moonfeature.Api::new()
  let provider = probe_provider("shared", "value", false, false)
  let provider_object : &@moonfeature.Provider = provider
    as &@moonfeature.Provider
  assert_eq(api.set_provider(provider_object), Ok(()))
  assert_eq(api.set_provider_for_domain("tenant-a", provider_object), Ok(()))
  assert_eq(provider.counts.val.initialize_calls, 1)
  assert_eq(api.shutdown(), Ok(()))
  assert_eq(provider.counts.val.shutdown_calls, 1)
}

///|
test "provider metadata lookup follows the same domain fallback as evaluation" {
  let api = @moonfeature.Api::new()
  assert_eq(api.provider_metadata(None), None)
  let fallback = probe_provider("fallback", "default", false, false)
  let fallback_object : &@moonfeature.Provider = fallback
    as &@moonfeature.Provider
  assert_eq(api.set_provider(fallback_object), Ok(()))
  let tenant = probe_provider("tenant-meta", "tenant", false, false)
  let tenant_object : &@moonfeature.Provider = tenant as &@moonfeature.Provider
  assert_eq(api.set_provider_for_domain("tenant-a", tenant_object), Ok(()))
  match api.provider_metadata(Some("tenant-a")) {
    Some(metadata) => assert_eq(metadata.name(), "tenant-meta")
    None => assert_true(false)
  }
  match api.provider_metadata(Some("unknown")) {
    Some(metadata) => assert_eq(metadata.name(), "fallback")
    None => assert_true(false)
  }
}
