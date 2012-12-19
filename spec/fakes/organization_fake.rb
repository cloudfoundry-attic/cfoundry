class CFoundry::V2::Organization
  def default_fakes
    super.merge :name => random_string(object_name)
  end
end