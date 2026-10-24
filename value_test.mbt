///|
test "flag values expose only their matching scalar type" {
  let enabled = @moonfeature.FlagValue::Boolean(true)
  assert_eq(enabled.as_boolean(), Some(true))
  assert_eq(enabled.as_number(), None)

  let threshold = @moonfeature.FlagValue::Number(0.75)
  assert_eq(threshold.as_number(), Some(0.75))
  assert_eq(threshold.as_string(), None)

  let label = @moonfeature.FlagValue::String("canary")
  assert_eq(label.as_string(), Some("canary"))
  assert_eq(label.as_boolean(), None)
}

///|
test "flag values preserve nested JSON" {
  let nested = Json({ "tier": ["gold"] })
  let value = @moonfeature.FlagValue::Json(nested)
  assert_eq(value.as_json(), Some(nested))
}

///|
test "flag values report their semantic type" {
  assert_eq(
    @moonfeature.FlagValue::Boolean(true).value_type(),
    @moonfeature.ValueType::Boolean,
  )
  assert_eq(
    @moonfeature.FlagValue::Number(1.5).value_type(),
    @moonfeature.ValueType::Number,
  )
  assert_eq(
    @moonfeature.FlagValue::String("variant").value_type(),
    @moonfeature.ValueType::String,
  )
  assert_eq(
    @moonfeature.FlagValue::Json(Json::null()).value_type(),
    @moonfeature.ValueType::Json,
  )
}
