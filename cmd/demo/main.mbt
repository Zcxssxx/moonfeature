///|
fn build_config(
  checkout_percentage : Double,
) -> Result[@local.Config, @moonfeature.EvaluationError] {
  let checkout = @local.FlagDefinition::new(
    "checkout-redesign",
    @moonfeature.FlagValue::Boolean(false),
  ).with_rollout(
    @local.PercentageRollout::new(
      checkout_percentage,
      @moonfeature.FlagValue::Boolean(true),
    ).with_variant("checkout-canary"),
  )
  let accent = @local.FlagDefinition::new(
    "checkout-accent",
    @moonfeature.FlagValue::String("blue"),
  ).with_rule(
    @local.Rule::new(@moonfeature.FlagValue::String("teal"))
    .with_condition(
      @local.Condition::equals("country", @moonfeature.FlagValue::String("CA")),
    )
    .with_variant("canada-accent"),
  )
  @local.Config::new([checkout, accent])
}

///|
fn print_user(
  client : @moonfeature.Client,
  user : String,
  country : String,
) -> Unit {
  let context = @moonfeature.EvaluationContext::empty()
    .with_targeting_key(user)
    .with_attribute("country", @moonfeature.FlagValue::String(country))
  let checkout = client.get_boolean_details("checkout-redesign", false, context)
  let accent = client.get_string_details("checkout-accent", "blue", context)
  let checkout_variant = match checkout.variant() {
    Some(variant) => variant
    None => "-"
  }
  let accent_variant = match accent.variant() {
    Some(variant) => variant
    None => "-"
  }
  println(
    "user=" +
    user +
    " country=" +
    country +
    " checkout=" +
    checkout.value().to_repr().to_string() +
    " checkout_variant=" +
    checkout_variant +
    " accent=" +
    accent.value().to_repr().to_string() +
    " accent_variant=" +
    accent_variant,
  )
}

///|
fn main {
  let initial_config = match build_config(70.0) {
    Ok(config) => config
    Err(error) => {
      println("invalid initial configuration: " + error.message())
      return
    }
  }
  let provider = @local.LocalProvider::new(
    "demo-local-provider", initial_config,
  )
  let api = @moonfeature.Api::new()
  let provider_object : &@moonfeature.Provider = provider
    as &@moonfeature.Provider
  match api.set_provider(provider_object) {
    Ok(_) => ()
    Err(error) => {
      println("provider initialization failed: " + error.message())
      return
    }
  }
  let _ = api.add_event_handler(fn(event) {
    println("provider event: " + event.kind().to_repr().to_string())
    Ok(())
  })

  println("initial rollout and country targeting:")
  let client = api.client()
  print_user(client, "user-0", "CA")
  print_user(client, "alice", "US")

  println("caller replaces config to disable the rollout:")
  match build_config(0.0) {
    Ok(updated_config) => {
      provider.replace_config(updated_config)
      print_user(client, "user-0", "CA")
      print_user(client, "alice", "US")
    }
    Err(error) => println("invalid updated configuration: " + error.message())
  }
  let _ = api.shutdown()
}
