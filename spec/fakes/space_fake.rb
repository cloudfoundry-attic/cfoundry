class CFoundry::V2::Space
  def default_fakes
    super.merge :name => random_string(object_name)
  end
end