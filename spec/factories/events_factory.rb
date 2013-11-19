FactoryGirl.define do
  factory :event, :class => CFoundry::V2::Event do
    sequence(:guid) { |n| "event-guid-#{n}" }
    timestamp '2013-01-01T12:00:00+00:00'
    actee 'app-guid-1'
    actee_type 'app'
    actor 'actor-guid-1'
    actor_type 'user'
    organization_guid 'organization-guid-1'
    space_guid 'space-guid-1'
    type ''
    metadata {}

    initialize_with do
      new(guid, build(:client), {
        entity: {
          type: type,
          actee: actee,
          actee_type: actee_type,
          actor: actor,
          actor_type: actor_type,
          organization_guid: organization_guid,
          space_guid: space_guid,
          timestamp: timestamp,
          metadata: metadata
        }
      })
    end

    trait :app_update do
      type 'audit.app.update'

      changes do
        {state: 'STARTED'}
      end

      metadata do
        {
          request: changes,
          desired_memory: 128,
          desired_instances: 1
        }
      end
    end

    trait :app_delete do
      type 'audit.app.delete'
    end
  end
end
