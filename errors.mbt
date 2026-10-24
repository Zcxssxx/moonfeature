///|
/// Error categories surfaced by typed evaluation and configuration APIs.
pub(all) enum ErrorCode {
  FlagNotFound
  TypeMismatch
  InvalidContext
  ProviderNotReady
  ProviderFailure
  InvalidConfiguration
  HookFailure
} derive(Eq, Debug)

///|
pub extend ErrorCode with Eq::{equal, not_equal}

///|
pub extend ErrorCode with Debug::{to_repr}

///|
/// Structured error information for failed resolution or configuration.
pub struct EvaluationError {
  code : ErrorCode
  message : String
} derive(Eq, Debug)

///|
pub extend EvaluationError with Eq::{equal, not_equal}

///|
pub extend EvaluationError with Debug::{to_repr}

///|
/// Create an error with a stable category and human-readable message.
pub fn EvaluationError::new(
  code : ErrorCode,
  message : String,
) -> EvaluationError {
  { code, message, }
}

///|
/// Return this error's stable category.
pub fn EvaluationError::code(self : EvaluationError) -> ErrorCode {
  self.code
}

///|
/// Return this error's message.
pub fn EvaluationError::message(self : EvaluationError) -> String {
  self.message
}
