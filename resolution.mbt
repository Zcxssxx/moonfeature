///|
/// Lifecycle status of a provider instance.
pub(all) enum ProviderStatus {
  NotReady
  Ready
  Error
  Fatal
  Stale
  Reconciling
  Shutdown
} derive(Eq, Debug)

///|
pub extend ProviderStatus with Eq::{equal, not_equal}

///|
pub extend ProviderStatus with Debug::{to_repr}

///|
/// Resolution reasons supported by the SDK result model.
pub(all) enum ResolutionReason {
  Static
  Default
  TargetingMatch
  Split
  Cached
  Disabled
  Stale
  Error
  Unknown
} derive(Eq, Debug)

///|
pub extend ResolutionReason with Eq::{equal, not_equal}

///|
pub extend ResolutionReason with Debug::{to_repr}

///|
/// Stable descriptive metadata for a provider implementation.
pub struct ProviderMetadata {
  name : String
  version : String
} derive(Eq, Debug)

///|
pub extend ProviderMetadata with Eq::{equal, not_equal}

///|
pub extend ProviderMetadata with Debug::{to_repr}

///|
/// Create provider metadata.
pub fn ProviderMetadata::new(
  name : String,
  version : String,
) -> ProviderMetadata {
  { name, version, }
}

///|
/// Return the provider name.
pub fn ProviderMetadata::name(self : ProviderMetadata) -> String {
  self.name
}

///|
/// Return the provider version.
pub fn ProviderMetadata::version(self : ProviderMetadata) -> String {
  self.version
}

///|
/// Provider-level result before the SDK applies caller defaults and hooks.
pub struct ProviderResolution {
  value : FlagValue
  variant : String?
  reason : ResolutionReason?
  flag_metadata : Json
} derive(Eq, Debug)

///|
pub extend ProviderResolution with Eq::{equal, not_equal}

///|
pub extend ProviderResolution with Debug::{to_repr}

///|
/// Create a provider result with an empty metadata object.
pub fn ProviderResolution::new(value : FlagValue) -> ProviderResolution {
  {
    value: value.snapshot(),
    variant: None,
    reason: None,
    flag_metadata: Json::empty_object(),
  }
}

///|
/// Return a provider result with a named variant.
pub fn ProviderResolution::with_variant(
  self : ProviderResolution,
  variant : String,
) -> ProviderResolution {
  { ..self, variant: Some(variant), }
}

///|
/// Return a provider result with a resolution reason.
pub fn ProviderResolution::with_reason(
  self : ProviderResolution,
  reason : ResolutionReason,
) -> ProviderResolution {
  { ..self, reason: Some(reason), }
}

///|
/// Return a provider result with copied flag metadata.
pub fn ProviderResolution::with_flag_metadata(
  self : ProviderResolution,
  metadata : Json,
) -> ProviderResolution {
  { ..self, flag_metadata: clone_json(metadata), }
}

///|
/// Return a detached flag value.
pub fn ProviderResolution::value(self : ProviderResolution) -> FlagValue {
  self.value.snapshot()
}

///|
/// Return the resolved variant, if supplied.
pub fn ProviderResolution::variant(self : ProviderResolution) -> String? {
  self.variant
}

///|
/// Return the provider's resolution reason, if supplied.
pub fn ProviderResolution::reason(
  self : ProviderResolution,
) -> ResolutionReason? {
  self.reason
}

///|
/// Return detached provider metadata.
pub fn ProviderResolution::flag_metadata(self : ProviderResolution) -> Json {
  clone_json(self.flag_metadata)
}

///|
/// SDK-level resolution details after defaults and type checks are applied.
pub struct ResolutionDetails {
  flag_key : String
  value : FlagValue
  variant : String?
  reason : ResolutionReason?
  flag_metadata : Json
  error_code : ErrorCode?
  error_message : String?
} derive(Eq, Debug)

///|
pub extend ResolutionDetails with Eq::{equal, not_equal}

///|
pub extend ResolutionDetails with Debug::{to_repr}

///|
/// Return the evaluated flag key.
pub fn ResolutionDetails::flag_key(self : ResolutionDetails) -> String {
  self.flag_key
}

///|
/// Return a detached typed value.
pub fn ResolutionDetails::value(self : ResolutionDetails) -> FlagValue {
  self.value.snapshot()
}

///|
/// Return the provider variant, if any.
pub fn ResolutionDetails::variant(self : ResolutionDetails) -> String? {
  self.variant
}

///|
/// Return the provider resolution reason, if any.
pub fn ResolutionDetails::reason(self : ResolutionDetails) -> ResolutionReason? {
  self.reason
}

///|
/// Return detached flag metadata.
pub fn ResolutionDetails::flag_metadata(self : ResolutionDetails) -> Json {
  clone_json(self.flag_metadata)
}

///|
/// Return the structured error category, if evaluation fell back.
pub fn ResolutionDetails::error_code(self : ResolutionDetails) -> ErrorCode? {
  self.error_code
}

///|
/// Return the error message, if evaluation fell back.
pub fn ResolutionDetails::error_message(self : ResolutionDetails) -> String? {
  self.error_message
}
