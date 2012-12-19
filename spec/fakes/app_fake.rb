class CFoundry::V2::App
  def default_fakes
    super.merge :name => random_string(object_name)
  end
end