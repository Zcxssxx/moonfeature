///|
/// Synchronous provider contract for server-side flag resolution.
/// Implementations must keep resolve non-blocking and return cached/local results.
pub(open) trait Provider {
  fn metadata(Self) -> ProviderMetadata
  fn initialize(Self, EvaluationContext, String?) -> Result[
    Unit,
    EvaluationError,
  ]
  fn shutdown(Self) -> Result[Unit, EvaluationError]
  fn status(Self) -> ProviderStatus
  fn resolve(Self, String, ValueType, EvaluationContext) -> Result[
    ProviderResolution,
    EvaluationError,
  ]
}
