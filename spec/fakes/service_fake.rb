class CFoundry::V2::Service
  def default_fakes
    super.merge :label => random_string(object_name)
  end
end