FactoryGirl.define do
  factory :app_usage_event, :class => CFoundry::V2::AppUsageEvent do
    sequence(:guid) { |n| "app-usage-event-guid-#{n}" }
    created_at '2013-01-01T12:00:00+00:00'
    state 'STARTED'
    memory_in_mb_per_instance 512
    instance_count 1
    app_guid 'app-guid-1'
    app_name 'app-name-1'
    space_guid 'space-guid-1'
    space_name 'space-name-1'
    org_guid 'org-guid-1'

    initialize_with do
      new(guid, build(:client), {
        metadata: {
          created_at: created_at
        },
        entity: {
          state: state,
          memory_in_mb_per_instance: memory_in_mb_per_instance,
          instance_count: instance_count,
          app_guid: app_guid,
          app_name: app_name,
          space_guid: space_guid,
          space_name: space_name,
          org_guid: org_guid
        }
      })
    end
  end
end
