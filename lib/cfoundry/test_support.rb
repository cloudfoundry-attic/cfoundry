Dir[File.expand_path('../../../spec/{support}/**/*.rb', __FILE__)].each do |file|
  require file unless file =~ /factory_girl/
end
