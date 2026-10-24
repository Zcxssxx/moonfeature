///|
/// Snapshot hooks in broad-to-narrow scope order for one evaluation.
fn Client::hook_executions(
  self : Client,
  options : EvaluationOptions,
  provider : &Provider?,
) -> Array[HookExecution] {
  let executions : Array[HookExecution] = []
  for entry in self.api.state.val.api_hooks {
    executions.push(entry.hook.execution())
  }
  for (_, hook) in self.hooks.val {
    executions.push(hook.execution())
  }
  for hook in options.hooks {
    executions.push(hook.execution())
  }
  match provider {
    Some(provider) =>
      for hook in provider.evaluation_hooks() {
        executions.push(hook.execution())
      }
    None => ()
  }
  executions
}

///|
/// Run one typed evaluation through before, provider, after/error, and finally stages.
fn Client::resolve_with_options(
  self : Client,
  flag_key : String,
  default_value : FlagValue,
  options : EvaluationOptions,
) -> ResolutionDetails {
  let provider = self.api.provider_for_domain(self.domain)
  let executions = self.hook_executions(options, provider)
  let mut context = self.merged_context(options.context)
  let hints = clone_json(options.hints)
  let mut failure : EvaluationError? = None

  for execution in executions {
    if failure is None {
      match execution.hook.before {
        None => ()
        Some(callback) => {
          let hook_context = HookContext::new(
            flag_key,
            default_value.value_type(),
            default_value,
            context,
          )
          match
            callback(
              hook_context,
              clone_json(execution.data.val),
              clone_json(hints),
            ) {
            Ok(result) => {
              context = context.merge(result.context_changes())
              execution.data.val = result.data()
            }
            Err(error) => failure = Some(error)
          }
        }
      }
    }
  }

  let mut details = fallback_details(flag_key, default_value, None)
  match failure {
    Some(error) =>
      details = fallback_details(flag_key, default_value, Some(error))
    None =>
      match provider {
        None => ()
        Some(provider) =>
          match
            provider.resolve(flag_key, default_value.value_type(), context) {
            Ok(result) => {
              let value = result.value()
              if value.value_type() != default_value.value_type() {
                let error = EvaluationError::new(
                  ErrorCode::TypeMismatch,
                  "provider returned a value of the wrong type",
                )
                failure = Some(error)
                details = fallback_details(flag_key, default_value, Some(error))
              } else {
                details = {
                  flag_key,
                  value,
                  variant: result.variant(),
                  reason: result.reason(),
                  flag_metadata: result.flag_metadata(),
                  error_code: None,
                  error_message: None,
                }
              }
            }
            Err(error) => {
              failure = Some(error)
              details = fallback_details(flag_key, default_value, Some(error))
            }
          }
      }
  }

  let reversed = reversed_hook_executions(executions)
  if failure is None {
    for execution in reversed {
      if failure is None {
        match execution.hook.after {
          None => ()
          Some(callback) => {
            let hook_context = HookContext::new(
              flag_key,
              default_value.value_type(),
              default_value,
              context,
            )
            match
              callback(
                hook_context,
                details,
                clone_json(execution.data.val),
                clone_json(hints),
              ) {
              Ok(_) => ()
              Err(error) => {
                failure = Some(error)
                details = fallback_details(flag_key, default_value, Some(error))
              }
            }
          }
        }
      }
    }
  }

  match failure {
    None => ()
    Some(error) =>
      for execution in reversed {
        match execution.hook.error {
          None => ()
          Some(callback) => {
            let hook_context = HookContext::new(
              flag_key,
              default_value.value_type(),
              default_value,
              context,
            )
            match
              callback(
                hook_context,
                error,
                clone_json(execution.data.val),
                clone_json(hints),
              ) {
              Ok(_) => ()
              Err(hook_error) => self.api.record_hook_error(hook_error)
            }
          }
        }
      }
  }

  for execution in reversed {
    match execution.hook.on_finally {
      None => ()
      Some(callback) => {
        let hook_context = HookContext::new(
          flag_key,
          default_value.value_type(),
          default_value,
          context,
        )
        match
          callback(
            hook_context,
            details,
            clone_json(execution.data.val),
            clone_json(hints),
          ) {
          Ok(_) => ()
          Err(error) => self.api.record_hook_error(error)
        }
      }
    }
  }
  details
}
