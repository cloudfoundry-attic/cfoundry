class CFoundry::V2::User
  def default_fakes
    super.merge :admin => false
  end
end