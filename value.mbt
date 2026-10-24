///|
/// Expected kind of a flag value.
pub(all) enum ValueType {
  Boolean
  Number
  String
  Json
} derive(Eq, Debug)

///|
pub extend ValueType with Eq::{equal, not_equal}

///|
pub extend ValueType with Debug::{to_repr}

///|
/// A typed value returned by a feature-flag provider.
pub(all) enum FlagValue {
  Boolean(Bool)
  Number(Double)
  String(String)
  Json(Json)
} derive(Eq, Debug)

///|
pub extend FlagValue with Eq::{equal, not_equal}

///|
pub extend FlagValue with Debug::{to_repr}

///|
fn clone_json(value : Json) -> Json {
  match value {
    Json::Null => Json::null()
    Json::True => Json::boolean(true)
    Json::False => Json::boolean(false)
    Json::Number(number, repr~) => Json::number(number, repr?)
    Json::String(value) => Json::string(value)
    Json::Array(values) => Json::array(values.map(clone_json))
    Json::Object(fields) => {
      let copy : Map[String, Json] = Map([])
      fields.each(fn(key, child) { copy.set(key, clone_json(child)) })
      Json::object(copy)
    }
  }
}

///|
fn FlagValue::snapshot(self : FlagValue) -> FlagValue {
  match self {
    Boolean(value) => Boolean(value)
    Number(value) => Number(value)
    String(value) => String(value)
    Json(value) => Json(clone_json(value))
  }
}

///|
/// Return the semantic type of this value.
pub fn FlagValue::value_type(self : FlagValue) -> ValueType {
  match self {
    Boolean(_) => ValueType::Boolean
    Number(_) => ValueType::Number
    String(_) => ValueType::String
    Json(_) => ValueType::Json
  }
}

///|
/// Return the Boolean payload when this value is Boolean.
pub fn FlagValue::as_boolean(self : FlagValue) -> Bool? {
  match self {
    Boolean(value) => Some(value)
    _ => None
  }
}

///|
/// Return the Number payload when this value is Number.
pub fn FlagValue::as_number(self : FlagValue) -> Double? {
  match self {
    Number(value) => Some(value)
    _ => None
  }
}

///|
/// Return the String payload when this value is String.
pub fn FlagValue::as_string(self : FlagValue) -> String? {
  match self {
    String(value) => Some(value)
    _ => None
  }
}

///|
/// Return a detached JSON value when this value is JSON.
pub fn FlagValue::as_json(self : FlagValue) -> Json? {
  match self {
    Json(value) => Some(clone_json(value))
    _ => None
  }
}
