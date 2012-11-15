module CFoundry
  # Base class for CFoundry errors (not from the server).
  class Error < RuntimeError; end

  class Deprecated < Error; end

  class Mismatch < Error
    def initialize(expected, got)
      @expected = expected
      @got = got
    end

    def to_s
      "Invalid value type; expected #{@expected.inspect}, got #{@got.inspect}"
    end
  end

  class TargetRefused < Error
    # Error message.
    attr_reader :message

    # Message varies as this represents various network errors.
    def initialize(message)
      @message = message
    end

    # Exception message.
    def to_s
      "target refused connection (#@message)"
    end
  end


  # Exception representing errors returned by the API.
  class APIError < RuntimeError
    class << self
      def v2_classes
        @v2_classes ||= {}
      end

      def v1_classes
        @v1_classes ||= {}
      end
    end

    attr_reader :error_code, :description

    # Create an APIError with a given error code and description.
    def initialize(error_code = nil, description = nil)
      @error_code = error_code
      @description = description
    end

    # Exception message.
    def to_s
      if error_code
        "#{error_code}: #{description}"
      elsif description
        description
      else
        super
      end
    end
  end

  class NotFound < APIError; end

  class Denied < APIError; end

  class BadResponse < APIError; end


  def self.define_error(class_name, v2_code, v1_code = nil)
    base =
      case class_name
      when /NotFound$/
        NotFound
      else
        APIError
      end

    klass = Class.new(base)

    APIError.v1_classes[v1_code] = klass if v1_code
    APIError.v2_classes[v2_code] = klass if v2_code

    const_set(class_name, klass)
  end


  [
    ["InvalidAuthToken",     100],

    ["QuotaDeclined",        1000],
    ["MessageParseError",    1001],
    ["InvalidRelation",      1002],

    ["UserInvalid",          20001],
    ["UaaIdTaken",           20002],
    ["UserNotFound",         20003, 201],

    ["OrganizationInvalid",   30001],
    ["OrganizationNameTaken", 30002],
    ["OrganizationNotFound",  30003],

    ["SpaceInvalid",       40001],
    ["SpaceNameTaken",     40002],
    ["SpaceUserNotInOrg",  40003],
    ["SpaceNotFound",      40004],

    ["ServiceAuthTokenInvalid",    50001],
    ["ServiceAuthTokenLabelTaken", 50002],
    ["ServiceAuthTokenNotFound",   50003],

    ["ServiceInstanceNameInvalid", 60001],
    ["ServiceInstanceNameTaken",   60002],
    ["ServiceInstanceServiceBindingWrongSpace", 60003],
    ["ServiceInstanceInvalid",     60003],
    ["ServiceInstanceNotFound",    60004],

    ["RuntimeInvalid",   70001],
    ["RuntimeNameTaken", 70002],
    ["RuntimeNotFound",  70003],

    ["FrameworkInvalid",   80001],
    ["FrameworkNameTaken", 80002],
    ["FrameworkNotFound",  80003],

    ["ServiceBindingInvalid",            90001],
    ["ServiceBindingDifferentSpaces",    90002],
    ["ServiceBindingAppServiceTaken",    90003],
    ["ServiceBindingNotFound",           90004],

    ["AppInvalid",   100001, 300],
    ["AppNameTaken", 100002],
    ["AppNotFound",  100004, 301],

    ["ServicePlanInvalid",   110001],
    ["ServicePlanNameTaken", 110002],
    ["ServicePlanNotFound",  110003],

    ["ServiceInvalid",    120001],
    ["ServiceLabelTaken", 120002],
    ["ServiceNotFound",   120003, 500],

    ["DomainInvalid",   130001],
    ["DomainNotFound",  130002],
    ["DomainNameTaken", 130003],

    ["LegacyApiWithoutDefaultSpace", 140001],

    ["AppPackageInvalid",  150001],
    ["AppPackageNotFound", 150002],

    ["AppBitsUploadInvalid", 160001],

    ["StagingError", 170001],

    ["SnapshotNotFound",      180001],
    ["ServiceGatewayError",   180002, 503],
    ["ServiceNotImplemented", 180003],
    ["SDSNotAvailable",       180004],

    ["FileError",  190001],

    ["StatsError", 200001],

    ["RouteInvalid",   210001],
    ["RouteNotFound",  210002],
    ["RouteHostTaken", 210003],

    ["InstancesError", 220001],

    ["BillingEventQueryInvalid", 230001],

    # V1 Errors
    ["BadRequest",    nil, 100],
    ["DatabaseError", nil, 101],
    ["LockingError",  nil, 102],
    ["SystemError",   nil, 111],

    ["Forbidden",     nil, 200],
    ["HttpsRequired", nil, 202],

    ["AppNoResources",      nil, 302],
    ["AppFileNotFound",     nil, 303],
    ["AppInstanceNotFound", nil, 304],
    ["AppStopped",          nil, 305],
    ["AppFileError",        nil, 306],
    ["AppInvalidRuntime",   nil, 307],
    ["AppInvalidFramework", nil, 308],
    ["AppDebugDisallowed",  nil, 309],
    ["AppStagingError",     nil, 310],

    ["ResourcesUnknownPackageType", nil, 400],
    ["ResourcesMissingResource",    nil, 401],
    ["ResourcesPackagingFailed",    nil, 402],

    ["BindingNotFound",        nil, 501],
    ["TokenNotFound",          nil, 502],
    ["AccountTooManyServices", nil, 504],
    ["ExtensionNotImpl",       nil, 505],
    ["UnsupportedVersion",     nil, 506],
    ["SdsError",               nil, 507],
    ["SdsNotFound",            nil, 508],

    ["AccountNotEnoughMemory", nil, 600],
    ["AccountAppsTooMany",     nil, 601],
    ["AccountAppTooManyUris",  nil, 602],

    ["UriInvalid",      nil, 700],
    ["UriAlreadyTaken", nil, 701],
    ["UriNotAllowed",   nil, 702],
    ["StagingTimedOut", nil, 800],
    ["StagingFailed",   nil, 801]
  ].each do |args|
    define_error(*args)
  end
end
