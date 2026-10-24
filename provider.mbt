///|
/// Synchronous provider contract for server-side flag resolution.
/// Implementations must keep resolve non-blocking and return cached/local results.
/// instance_id must remain unique per live provider instance within an API.
pub(open) trait Provider {
  fn metadata(Self) -> ProviderMetadata
  fn instance_id(Self) -> String
  fn domain_scoped(Self) -> Bool
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
  fn subscribe_events(Self, ProviderEventSink) -> Int32 = _
  fn unsubscribe_events(Self, Int32) -> Unit = _
}

///|
impl Provider with fn subscribe_events(_self, _sink) {
  0
}

///|
impl Provider with fn unsubscribe_events(_self, _id) {

}
