///|
test "evaluation errors preserve a typed code and message" {
  let error = @moonfeature.EvaluationError::new(
    @moonfeature.ErrorCode::ProviderFailure,
    "provider is unavailable",
  )
  assert_eq(error.code(), @moonfeature.ErrorCode::ProviderFailure)
  assert_eq(error.message(), "provider is unavailable")
}
