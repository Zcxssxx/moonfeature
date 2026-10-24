///|

///|
fn copy_flag_value(value : @moonfeature.FlagValue) -> @moonfeature.FlagValue {
  match value {
    @moonfeature.FlagValue::Boolean(boolean) =>
      @moonfeature.FlagValue::Boolean(boolean)
    @moonfeature.FlagValue::Number(number) =>
      @moonfeature.FlagValue::Number(number)
    @moonfeature.FlagValue::String(string) =>
      @moonfeature.FlagValue::String(string)
    @moonfeature.FlagValue::Json(_) =>
      match value.as_json() {
        Some(json) => @moonfeature.FlagValue::Json(json)
        None => @moonfeature.FlagValue::Json(Json::null())
      }
  }
}

///|
/// A predicate against one named evaluation-context attribute.
pub struct Condition {
  attribute : String
  expected : @moonfeature.FlagValue?
  exists_only : Bool
}

///|
/// Match when an attribute equals a typed value.
pub fn Condition::equals(
  attribute : String,
  value : @moonfeature.FlagValue,
) -> Condition {
  { attribute, expected: Some(copy_flag_value(value)), exists_only: false, }
}

///|
/// Match when an attribute is present, regardless of its value.
pub fn Condition::exists(attribute : String) -> Condition {
  { attribute, expected: None, exists_only: true, }
}

///|
/// An ordered rule that returns a value when all of its conditions match.
pub struct Rule {
  conditions : Array[Condition]
  value : @moonfeature.FlagValue
  variant : String?
}

///|
/// Create a rule with no conditions, which matches every context.
pub fn Rule::new(value : @moonfeature.FlagValue) -> Rule {
  { conditions: [], value: copy_flag_value(value), variant: None, }
}

///|
/// Return a copy with one additional AND condition.
pub fn Rule::with_condition(self : Rule, condition : Condition) -> Rule {
  let conditions = self.conditions.copy()
  conditions.push(condition)
  { ..self, conditions, }
}

///|
/// Return a copy with a variant identifier.
pub fn Rule::with_variant(self : Rule, variant : String) -> Rule {
  { ..self, variant: Some(variant), }
}

///|
/// A stable single-value percentage rollout.
pub struct PercentageRollout {
  percentage : Double
  value : @moonfeature.FlagValue
  variant : String?
}

///|
/// Create a rollout that returns value for the configured share of identities.
pub fn PercentageRollout::new(
  percentage : Double,
  value : @moonfeature.FlagValue,
) -> PercentageRollout {
  { percentage, value: copy_flag_value(value), variant: None, }
}

///|
/// Return a copy with a variant identifier for users inside the rollout.
pub fn PercentageRollout::with_variant(
  self : PercentageRollout,
  variant : String,
) -> PercentageRollout {
  { ..self, variant: Some(variant), }
}

///|
/// One flag's fallback, ordered targeting rules, and optional rollout.
pub struct FlagDefinition {
  key : String
  default_value : @moonfeature.FlagValue
  rules : Array[Rule]
  rollout : PercentageRollout?
}

///|
/// Create a flag definition with a fallback value.
pub fn FlagDefinition::new(
  key : String,
  default_value : @moonfeature.FlagValue,
) -> FlagDefinition {
  {
    key,
    default_value: copy_flag_value(default_value),
    rules: [],
    rollout: None,
  }
}

///|
/// Return a copy with a targeting rule appended in precedence order.
pub fn FlagDefinition::with_rule(
  self : FlagDefinition,
  rule : Rule,
) -> FlagDefinition {
  let rules = self.rules.copy()
  rules.push(rule)
  { ..self, rules, }
}

///|
/// Return a copy with a rollout applied after all explicit rules.
pub fn FlagDefinition::with_rollout(
  self : FlagDefinition,
  rollout : PercentageRollout,
) -> FlagDefinition {
  { ..self, rollout: Some(rollout), }
}

///|
/// Validated immutable snapshot of named flag definitions.
pub struct Config {
  flags : Map[String, FlagDefinition]
}

///|
/// Validate definitions and create a lookup-ready configuration.
pub fn Config::new(
  definitions : Array[FlagDefinition],
) -> Result[Config, @moonfeature.EvaluationError] {
  let flags : Map[String, FlagDefinition] = Map([])
  for definition in definitions {
    if definition.key == "" {
      return Err(
        @moonfeature.EvaluationError::new(
          @moonfeature.ErrorCode::InvalidConfiguration,
          "flag key must not be empty",
        ),
      )
    }
    match flags.get(definition.key) {
      Some(_) =>
        return Err(
          @moonfeature.EvaluationError::new(
            @moonfeature.ErrorCode::InvalidConfiguration,
            "flag keys must be unique within a configuration",
          ),
        )
      None => ()
    }
    for rule in definition.rules {
      if rule.value.value_type() != definition.default_value.value_type() {
        return Err(
          @moonfeature.EvaluationError::new(
            @moonfeature.ErrorCode::TypeMismatch,
            "rule value type must match the flag fallback type",
          ),
        )
      }
      for condition in rule.conditions {
        if condition.attribute == "" {
          return Err(
            @moonfeature.EvaluationError::new(
              @moonfeature.ErrorCode::InvalidConfiguration,
              "condition attribute must not be empty",
            ),
          )
        }
      }
    }
    match definition.rollout {
      Some(rollout) => {
        if !(rollout.percentage >= 0.0 && rollout.percentage <= 100.0) {
          return Err(
            @moonfeature.EvaluationError::new(
              @moonfeature.ErrorCode::InvalidConfiguration,
              "rollout percentage must be between 0 and 100 inclusive",
            ),
          )
        }
        if rollout.value.value_type() != definition.default_value.value_type() {
          return Err(
            @moonfeature.EvaluationError::new(
              @moonfeature.ErrorCode::TypeMismatch,
              "rollout value type must match the flag fallback type",
            ),
          )
        }
      }
      None => ()
    }
    flags.set(definition.key, definition)
  }
  Ok({ flags, })
}

///|
/// Return the number of flags in this configuration.
pub fn Config::flag_count(self : Config) -> Int32 {
  self.flags.length()
}
