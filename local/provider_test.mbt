///|
fn local_config_or_fail(
  flags : Array[@local.FlagDefinition],
) -> @local.Config raise {
  match @local.Config::new(flags) {
    Ok(config) => config
    Err(_) => fail("test configuration should be valid")
  }
}

///|
test "configuration rejects duplicate keys and incompatible variants" {
  let one = @local.FlagDefinition::new(
    "duplicate",
    @moonfeature.FlagValue::Boolean(false),
  )
  let two = @local.FlagDefinition::new(
    "duplicate",
    @moonfeature.FlagValue::Boolean(true),
  )
  assert_true(
    match @local.Config::new([one, two]) {
      Err(error) => error.code() == @moonfeature.ErrorCode::InvalidConfiguration
      Ok(_) => false
    },
  )

  let wrong_type = @local.FlagDefinition::new(
    "typed",
    @moonfeature.FlagValue::Boolean(false),
  ).with_rule(@local.Rule::new(@moonfeature.FlagValue::String("not-a-boolean")))
  assert_true(
    match @local.Config::new([wrong_type]) {
      Err(error) => error.code() == @moonfeature.ErrorCode::TypeMismatch
      Ok(_) => false
    },
  )

  let invalid_rollout = @local.FlagDefinition::new(
    "rollout",
    @moonfeature.FlagValue::Boolean(false),
  ).with_rollout(
    @local.PercentageRollout::new(100.1, @moonfeature.FlagValue::Boolean(true)),
  )
  assert_true(
    match @local.Config::new([invalid_rollout]) {
      Err(error) => error.code() == @moonfeature.ErrorCode::InvalidConfiguration
      Ok(_) => false
    },
  )
}

///|
test "rules are ordered and support equality and existence conditions" {
  let flag = @local.FlagDefinition::new(
      "checkout",
      @moonfeature.FlagValue::String("default"),
    )
    .with_rule(
      @local.Rule::new(@moonfeature.FlagValue::String("canada"))
      .with_condition(
        @local.Condition::equals(
          "country",
          @moonfeature.FlagValue::String("CA"),
        ),
      )
      .with_condition(
        @local.Condition::equals("plan", @moonfeature.FlagValue::String("plus")),
      )
      .with_variant("country-match"),
    )
    .with_rule(
      @local.Rule::new(@moonfeature.FlagValue::String("account-present"))
      .with_condition(@local.Condition::exists("account"))
      .with_variant("existence-match"),
    )
  let config = local_config_or_fail([flag])
  let provider = @local.LocalProvider::new("rules-precedence", config)
  let api = @moonfeature.Api::new()
  let provider_object : &@moonfeature.Provider = provider
    as &@moonfeature.Provider
  assert_eq(api.set_provider(provider_object), Ok(()))
  let client = api.client()
  let canada_and_account = @moonfeature.EvaluationContext::empty()
    .with_attribute("country", @moonfeature.FlagValue::String("CA"))
    .with_attribute("plan", @moonfeature.FlagValue::String("plus"))
    .with_attribute("account", @moonfeature.FlagValue::String("a-1"))
  let first = client.get_string_details(
    "checkout", "caller-default", canada_and_account,
  )
  assert_eq(first.value().as_string(), Some("canada"))
  assert_eq(first.variant(), Some("country-match"))
  let account_only = @moonfeature.EvaluationContext::empty().with_attribute(
    "account",
    @moonfeature.FlagValue::String("a-2"),
  )
  assert_eq(
    client.get_string_value("checkout", "caller-default", account_only),
    "account-present",
  )
  assert_eq(
    client.get_string_value(
      "checkout",
      "caller-default",
      @moonfeature.EvaluationContext::empty(),
    ),
    "default",
  )
}

///|
test "rollout uses frozen stable buckets and exact percentage boundaries" {
  assert_eq(@local.rollout_bucket("checkout", "user-0"), 65)
  assert_eq(@local.rollout_bucket("checkout", "alice"), 4341)
  assert_eq(@local.rollout_bucket("feature", "tenant-17"), 7732)
  assert_eq(@local.rollout_bucket("checkout", "user-42"), 8332)

  let context = @moonfeature.EvaluationContext::empty().with_targeting_key(
    "user-0",
  )
  let make_client = fn(percentage : Double, id : String) raise {
    let flag = @local.FlagDefinition::new(
      "checkout",
      @moonfeature.FlagValue::Boolean(false),
    ).with_rollout(
      @local.PercentageRollout::new(
        percentage,
        @moonfeature.FlagValue::Boolean(true),
      ),
    )
    let config = local_config_or_fail([flag])
    let provider = @local.LocalProvider::new(id, config)
    let api = @moonfeature.Api::new()
    let provider_object : &@moonfeature.Provider = provider
      as &@moonfeature.Provider
    let _ = api.set_provider(provider_object)
    api.client()
  }
  assert_eq(
    make_client(0.65, "rollout-below").get_boolean_value(
      "checkout", false, context,
    ),
    false,
  )
  assert_eq(
    make_client(0.66, "rollout-above").get_boolean_value(
      "checkout", false, context,
    ),
    true,
  )
  assert_eq(
    make_client(0.0, "rollout-zero").get_boolean_value(
      "checkout", false, context,
    ),
    false,
  )
  assert_eq(
    make_client(100.0, "rollout-full").get_boolean_value(
      "checkout", false, context,
    ),
    true,
  )
}

///|
test "rollout requires targeting identity and missing flags fail safely" {
  let flag = @local.FlagDefinition::new(
    "checkout",
    @moonfeature.FlagValue::Boolean(false),
  ).with_rollout(
    @local.PercentageRollout::new(50.0, @moonfeature.FlagValue::Boolean(true)),
  )
  let provider = @local.LocalProvider::new(
    "rollout-context-error",
    local_config_or_fail([flag]),
  )
  let api = @moonfeature.Api::new()
  let provider_object : &@moonfeature.Provider = provider
    as &@moonfeature.Provider
  assert_eq(api.set_provider(provider_object), Ok(()))
  let client = api.client()
  let no_key = client.get_boolean_details(
    "checkout",
    false,
    @moonfeature.EvaluationContext::empty(),
  )
  assert_eq(no_key.value().as_boolean(), Some(false))
  assert_eq(no_key.error_code(), Some(@moonfeature.ErrorCode::InvalidContext))
  let missing = client.get_boolean_details(
    "unknown",
    true,
    @moonfeature.EvaluationContext::empty(),
  )
  assert_eq(missing.value().as_boolean(), Some(true))
  assert_eq(missing.error_code(), Some(@moonfeature.ErrorCode::FlagNotFound))
}

///|
test "local provider preserves Boolean Number String and JSON flag types" {
  let config = local_config_or_fail([
    @local.FlagDefinition::new("enabled", @moonfeature.FlagValue::Boolean(true)),
    @local.FlagDefinition::new("limit", @moonfeature.FlagValue::Number(42.5)),
    @local.FlagDefinition::new("color", @moonfeature.FlagValue::String("blue")),
    @local.FlagDefinition::new(
      "settings",
      @moonfeature.FlagValue::Json(Json::object({ "mode": Json("safe") })),
    ),
  ])
  assert_eq(config.flag_count(), 4)
  let provider = @local.LocalProvider::new("typed-local-values", config)
  assert_eq(provider.provider_metadata().name(), "moonfeature-local")
  let api = @moonfeature.Api::new()
  let provider_object : &@moonfeature.Provider = provider
    as &@moonfeature.Provider
  assert_eq(api.set_provider(provider_object), Ok(()))
  let client = api.client()
  let context = @moonfeature.EvaluationContext::empty()
  assert_eq(client.get_boolean_value("enabled", false, context), true)
  assert_eq(client.get_number_value("limit", 0.0, context), 42.5)
  assert_eq(client.get_string_value("color", "red", context), "blue")
  assert_eq(
    client.get_json_value("settings", Json::null(), context),
    Json::object({ "mode": Json("safe") }),
  )
}

///|
test "configuration replacement updates evaluations and emits a change event" {
  let first = @local.FlagDefinition::new(
    "checkout",
    @moonfeature.FlagValue::String("old"),
  )
  let config = local_config_or_fail([first])
  let provider = @local.LocalProvider::new("config-replacement", config)
  let api = @moonfeature.Api::new()
  let provider_object : &@moonfeature.Provider = provider
    as &@moonfeature.Provider
  assert_eq(api.set_provider(provider_object), Ok(()))
  let events : @ref.Ref[Array[@moonfeature.ProviderEventKind]] = @ref.Ref([])
  let _ = api.add_event_handler(fn(event) {
    events.val.push(event.kind())
    Ok(())
  })
  let second = @local.FlagDefinition::new(
    "checkout",
    @moonfeature.FlagValue::String("new"),
  )
  provider.replace_config(local_config_or_fail([second]))
  assert_eq(
    api
    .client()
    .get_string_value(
      "checkout",
      "default",
      @moonfeature.EvaluationContext::empty(),
    ),
    "new",
  )
  assert_eq(events.val, [@moonfeature.ProviderEventKind::ConfigurationChanged])
}
