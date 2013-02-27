shared_examples_for 'a stubbed get request' do |*options|
  options = {:code => 200}.merge(options.first || {})

  it "stubs a get request" do
    subject
    response = Net::HTTP.get_response(URI.parse(url))
    check_response(response, options)
  end
end

shared_examples_for 'a stubbed post request' do |*options|
  options = {:code => 201, :params => {}}.merge(options.first || {})

  it "stubs a post request" do
    subject
    response = Net::HTTP.post_form(URI.parse(url), options[:params])
    check_response(response, options)
  end
end

shared_examples_for 'a stubbed put request' do |*options|
  options = {:code => 200, :params => {}}.merge(options.first || {})

  it "stubs a put request" do
    subject
    uri = URI.parse(url)
    Net::HTTP.start(uri.host, uri.port) do |http|
      request = Net::HTTP::Put.new(url, options[:params])
      response = http.request(request)
      check_response(response, options)
    end
  end
end

shared_examples_for 'a stubbed delete request' do |*options|
  options = {:code => 200, :ignore_response => true}.merge(options.first || {})

  it "stubs a delete request" do
    subject
    uri = URI.parse(url)
    Net::HTTP.start(uri.host, uri.port) do |http|
      request = Net::HTTP::Delete.new(url)
      response = http.request(request)
      check_response(response, options)
    end
  end
end

def check_response(response, options)
  response.code.should == options[:code].to_s

  unless options[:ignore_response]
    json = JSON.parse(response.body)
    json.should be_a(Hash)

    if options[:including_json]
      if Proc === options[:including_json]
        options[:including_json][json]
      else
        json.should deep_hash_include(options[:including_json])
      end
    end
  end
end

RSpec::Matchers.define :deep_hash_include do |expected|
  def deep_hash_include_rec(actual_hash, partial_hash)
    partial_hash.reduce(true) do |bool, (key, val)|
      actual_val = actual_hash[key]
      bool && ((Hash === actual_val) ?
        deep_hash_include_rec(actual_val, partial_hash[key]) :
        actual_val == val)
    end
  end

  match do |actual|
    deep_hash_include_rec(actual, expected)
  end
end