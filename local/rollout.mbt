///|
/// Compute a stable bucket in [0, 10000) from UTF-8 bytes.
///
/// The rolling hash starts at 2166136261 mod 2147483647 and applies
/// h = (h * 16777619 + byte) mod 2147483647 to flag, NUL, and identity bytes.
pub fn rollout_bucket(flag_key : String, targeting_key : String) -> Int32 {
  let bytes = @utf8.encode(flag_key + "\u{0}" + targeting_key)
  let modulus = 2147483647L
  let mut hash : Int64 = 2166136261L % modulus
  for byte in bytes.to_array() {
    hash = (hash * 16777619L + Int64::from_int(byte.to_int())) % modulus
  }
  (hash % 10000L).to_int()
}

///|
fn rollout_matches(
  flag_key : String,
  targeting_key : String,
  percentage : Double,
) -> Bool {
  rollout_bucket(flag_key, targeting_key).to_double() < percentage * 100.0
}
