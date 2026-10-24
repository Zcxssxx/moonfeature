///|
/// Immutable-by-interface OpenFeature evaluation context.
/// Each update returns a new context with its own attribute map.
pub struct EvaluationContext {
  targeting_key : String?
  attributes : Map[String, FlagValue]
}

///|
fn copy_attributes(source : Map[String, FlagValue]) -> Map[String, FlagValue] {
  let copy : Map[String, FlagValue] = Map([])
  source.each(fn(key, value) { copy.set(key, value.snapshot()) })
  copy
}

///|
/// Create an empty evaluation context.
pub fn EvaluationContext::empty() -> EvaluationContext {
  { targeting_key: None, attributes: {}, }
}

///|
/// Return a context with the supplied targeting key.
pub fn EvaluationContext::with_targeting_key(
  self : EvaluationContext,
  targeting_key : String,
) -> EvaluationContext {
  {
    targeting_key: Some(targeting_key),
    attributes: copy_attributes(self.attributes),
  }
}

///|
/// Return a context with one attribute added or replaced.
pub fn EvaluationContext::with_attribute(
  self : EvaluationContext,
  key : String,
  value : FlagValue,
) -> EvaluationContext {
  let attributes = copy_attributes(self.attributes)
  attributes.set(key, value.snapshot())
  { targeting_key: self.targeting_key, attributes, }
}

///|
/// Read the targeting key, if one was supplied.
pub fn EvaluationContext::targeting_key(self : EvaluationContext) -> String? {
  self.targeting_key
}

///|
/// Read one detached context attribute.
pub fn EvaluationContext::get_attribute(
  self : EvaluationContext,
  key : String,
) -> FlagValue? {
  match self.attributes.get(key) {
    Some(value) => Some(value.snapshot())
    None => None
  }
}

///|
/// Combine two contexts. Attributes from the overlay replace matching keys.
/// A missing overlay targeting key leaves the original targeting key unchanged.
pub fn EvaluationContext::merge(
  self : EvaluationContext,
  overlay : EvaluationContext,
) -> EvaluationContext {
  let attributes = copy_attributes(self.attributes)
  overlay.attributes.each(fn(key, value) {
    attributes.set(key, value.snapshot())
  })
  let targeting_key = match overlay.targeting_key {
    Some(key) => Some(key)
    None => self.targeting_key
  }
  { targeting_key, attributes, }
}
