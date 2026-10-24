///|
test "context merge overlays attributes and targeting key" {
  let global = @moonfeature.EvaluationContext::empty()
    .with_targeting_key("tenant-a")
    .with_attribute("region", @moonfeature.FlagValue::String("us"))
    .with_attribute("theme", @moonfeature.FlagValue::String("light"))
  let invocation = @moonfeature.EvaluationContext::empty()
    .with_targeting_key("user-17")
    .with_attribute("theme", @moonfeature.FlagValue::String("dark"))

  let merged = global.merge(invocation)
  assert_eq(merged.targeting_key(), Some("user-17"))
  assert_eq(
    merged.get_attribute("region"),
    Some(@moonfeature.FlagValue::String("us")),
  )
  assert_eq(
    merged.get_attribute("theme"),
    Some(@moonfeature.FlagValue::String("dark")),
  )
}

///|
test "context merge leaves source contexts unchanged" {
  let base = @moonfeature.EvaluationContext::empty()
    .with_targeting_key("global-user")
    .with_attribute("tier", @moonfeature.FlagValue::String("free"))
  let overlay = @moonfeature.EvaluationContext::empty().with_attribute(
    "tier",
    @moonfeature.FlagValue::String("paid"),
  )
  let _ = base.merge(overlay)

  assert_eq(base.targeting_key(), Some("global-user"))
  assert_eq(
    base.get_attribute("tier"),
    Some(@moonfeature.FlagValue::String("free")),
  )
  assert_eq(
    overlay.get_attribute("tier"),
    Some(@moonfeature.FlagValue::String("paid")),
  )
}

///|
test "reading a JSON context attribute cannot mutate the stored snapshot" {
  let profile = Json::object({ "tier": Json("gold") })
  let context = @moonfeature.EvaluationContext::empty().with_attribute(
    "profile",
    @moonfeature.FlagValue::Json(profile),
  )

  let changed_copy = match context.get_attribute("profile") {
    Some(@moonfeature.FlagValue::Json(Json::Object(fields))) => {
      fields.set("tier", Json("changed"))
      true
    }
    _ => false
  }
  assert_true(changed_copy)
  assert_eq(
    context.get_attribute("profile"),
    Some(@moonfeature.FlagValue::Json(Json::object({ "tier": Json("gold") }))),
  )
}
