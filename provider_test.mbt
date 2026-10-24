///|
struct FixedProvider {}

///|
impl @moonfeature.Provider for FixedProvider with fn metadata(_self) {
  @moonfeature.ProviderMetadata::new("fixed-test", "1.0")
}

///|
impl @moonfeature.Provider for FixedProvider with fn initialize(
  _self,
  _context,
  _domain,
) {
  Ok(())
}

///|
impl @moonfeature.Provider for FixedProvider with fn shutdown(_self) {
  Ok(())
}

///|
impl @moonfeature.Provider for FixedProvider with fn status(_self) {
  @moonfeature.ProviderStatus::Ready
}

///|
impl @moonfeature.Provider for FixedProvider with fn resolve(
  _self,
  _key,
  _expected,
  _context,
) {
  Ok(
    @moonfeature.ProviderResolution::new(@moonfeature.FlagValue::Boolean(true))
    .with_variant("enabled")
    .with_reason(@moonfeature.ResolutionReason::Static),
  )
}

///|
test "provider trait objects dispatch metadata lifecycle and resolution" {
  let provider : &@moonfeature.Provider = FixedProvider::{ }
    as &@moonfeature.Provider
  assert_eq(provider.metadata().name(), "fixed-test")
  assert_eq(provider.metadata().version(), "1.0")
  assert_eq(provider.status(), @moonfeature.ProviderStatus::Ready)
  assert_eq(
    provider.initialize(@moonfeature.EvaluationContext::empty(), None),
    Ok(()),
  )
  match
    provider.resolve(
      "checkout",
      @moonfeature.ValueType::Boolean,
      @moonfeature.EvaluationContext::empty(),
    ) {
    Ok(resolution) => {
      assert_eq(resolution.value(), @moonfeature.FlagValue::Boolean(true))
      assert_eq(resolution.variant(), Some("enabled"))
      assert_eq(
        resolution.reason(),
        Some(@moonfeature.ResolutionReason::Static),
      )
    }
    Err(_) => assert_true(false)
  }
  assert_eq(provider.shutdown(), Ok(()))
}
