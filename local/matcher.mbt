///|
/// Check one context attribute condition.
fn Condition::matches(
  self : Condition,
  context : @moonfeature.EvaluationContext,
) -> Bool {
  match (self.expected, context.get_attribute(self.attribute)) {
    (Some(expected), Some(actual)) => expected == actual
    (Some(_), None) => false
    (None, Some(_)) => self.exists_only
    (None, None) => false
  }
}

///|
/// A rule matches when each of its conditions matches.
fn Rule::matches(self : Rule, context : @moonfeature.EvaluationContext) -> Bool {
  let mut matched = true
  for condition in self.conditions {
    if matched && !condition.matches(context) {
      matched = false
    }
  }
  matched
}
