class CFoundry::V2::Route
  def default_fakes
		super.merge :host => random_string(object_name)
  end
end