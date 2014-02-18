require "spec_helper"

module CFoundry
  module V2
    describe User do
      let(:client) { build(:client) }
      subject { build(:user, client: client) }

      describe '#delete!' do
        describe 'when cloud controller was able to delete the user' do
          before do
            stub_request(:delete, /v2\/users\/.*/).to_return(:status => 200, :body => "", :headers => {})
            client.base.stub(:info).and_return({:authorization_endpoint => 'some_endpoint'})
          end

          it "also removes the user from uaa" do
            CFoundry::UAAClient.any_instance.should_receive(:delete_user)

            subject.delete!.should be_true
          end
        end

        describe "when cloud controller was unable to delete the user" do
          before do
            client.base.stub(:delete).and_raise(CFoundry::APIError)
          end

          it "allows the exception to bubble up" do
            expect{ subject.delete! }.to raise_error(CFoundry::APIError)
          end
        end
      end

      describe '#get_meta_from_uaa' do
        
        let(:api_target) { 'http://api.example.com' } 
        let(:login_target) { 'https://login.example.com' }
        let(:uaa_target) { 'https://uaa.example.com' }
        let(:user_email) { 'test-user@example.com' }
        let(:given_name) { 'John' }
        let(:family_name) { 'Doe' }
 
        before do

          stub_request(:get, "#{api_target}/info").to_return :status => 200,
          :headers => {'Content-Type' => 'application/json'},
          :body => <<EOF
            {
              "name": "vcap",
              "build": "2222",
              "support": "http://support.example.com",
              "version": 2,
              "description": "Cloud Foundry sponsored by Pivotal",
              "authorization_endpoint": "https://login.example.com",
              "token_endpoint": "https://uaa.example.com",
              "allow_debug": true,
              "user": "00000000-0000-0000-0000-000000000000",
              "limits": {
                "memory": 2048,
                "app_uris": 4,
                "services": 16,
                "apps": 20
              },
              "usage": {
                "memory": 896,
                "apps": 4,
                "services": 6
              }
            }
EOF

          stub_request(:get, "#{login_target}/login").to_return :status => 200,
          :headers => {'Content-Type' => 'application/json'},
          :body => <<EOF
            {
              "timestamp": "2013-06-12T22:32:57-0700",
              "app": {
                "artifact": "cloudfoundry-login-server",
                "description": "Cloud Foundry Login App",
                "name": "Cloud Foundry Login",
                "version": "1.2.3"
              },
              "links": {
                "register": "https://console.example.com/register",
                "passwd": "https://console.example.com/password_resets/new",
                "home": "https://console.example.com",
                "login": "https://login.example.com",
                "uaa": "https://uaa.example.com"
              },
              "analytics": {
                "code": "UA-00000000-00",
                "domain": "example.com"
              },
              "commit_id": "0000000",
              "prompts": {
                "username": [
                  "text",
                  "Email"
                ],
                "password": [
                  "password",
                  "Password"
                ]
              }
            }
EOF

          stub_request(:get, /#{uaa_target}\/Users\/user-guid-\d{1,2}/).to_return :status => 200,
          :headers => {'Content-Type' => 'application/json'},
          :body => <<EOF
          {
            "id": "00000000-0000-0000-0000-000000000000",
            "meta": {
              "version": 0,
              "created": "2013-06-24T13:44:38.000Z",
              "lastModified": "2013-06-24T13:44:38.000Z"
            },
            "userName": "#{user_email}",
            "name": {
              "familyName": "#{family_name}",
              "givenName": "#{given_name}"
            },
            "emails": [
              {
                "value": "#{user_email}"
              }
            ],
            "groups": [
              {
                "value": "00000000-0000-0000-0000-000000000000",
                "display": "password.write",
                "type": "DIRECT"
              },
              {
                "value": "00000000-0000-0000-0000-000000000000",
                "display": "openid",
                "type": "DIRECT"
              },
              {
                "value": "00000000-0000-0000-0000-000000000000",
                "display": "uaa.user",
                "type": "DIRECT"
              },
              {
                "value": "00000000-0000-0000-0000-000000000000",
                "display": "scim.userids",
                "type": "DIRECT"
              },
              {
                "value": "00000000-0000-0000-0000-000000000000",
                "display": "approvals.me",
                "type": "DIRECT"
              },
              {
                "value": "00000000-0000-0000-0000-000000000000",
                "display": "cloud_controller.write",
                "type": "DIRECT"
              },
              {
                "value": "00000000-0000-0000-0000-000000000000",
                "display": "scim.me",
                "type": "DIRECT"
              },
              {
                "value": "00000000-0000-0000-0000-000000000000",
                "display": "cloud_controller.read",
                "type": "DIRECT"
              }
            ],
            "approvals": [

            ],
            "active": true,
            "schemas": [
              "urn:scim:schemas:core:1.0"
            ]
          }
EOF
        end

        it "retrieves metadata from the UAA" do
          subject.email.should == user_email
          subject.given_name.should == given_name
          subject.family_name.should == family_name
          subject.full_name.should == "#{given_name} #{family_name}"
        end

        it "should be nil if user doesn't have permission to query uaa" do

          stub_request(:get, /#{uaa_target}\/Users\/user-guid-\d{1,2}/).to_return :status => 200,
          :headers => {'Content-Type' => 'application/json'},
          :body => <<EOF
          {
            "error": "access_denied",
            "error_description": "Access is denied"
          }
EOF
          subject.email.should == nil
          subject.given_name.should == nil
          subject.family_name.should == nil
        end

        it "should not fail to retrieve metadata from the UAA if name field is missing" do
          stub_request(:get, /#{uaa_target}\/Users\/user-guid-\d{1,2}/).to_return :status => 200,
          :headers => {'Content-Type' => 'application/json'},
          :body => <<EOF
          {
            "id": "00000000-0000-0000-0000-000000000000",
            "meta": {
              "version": 0,
              "created": "2013-06-24T13:44:38.000Z",
              "lastModified": "2013-06-24T13:44:38.000Z"
            },
            "userName": "#{user_email}",
            "emails": [
              {
                "value": "#{user_email}"
              }
            ],
            "groups": [
              {
                "value": "00000000-0000-0000-0000-000000000000",
                "display": "password.write",
                "type": "DIRECT"
              },
              {
                "value": "00000000-0000-0000-0000-000000000000",
                "display": "openid",
                "type": "DIRECT"
              },
              {
                "value": "00000000-0000-0000-0000-000000000000",
                "display": "uaa.user",
                "type": "DIRECT"
              },
              {
                "value": "00000000-0000-0000-0000-000000000000",
                "display": "scim.userids",
                "type": "DIRECT"
              },
              {
                "value": "00000000-0000-0000-0000-000000000000",
                "display": "approvals.me",
                "type": "DIRECT"
              },
              {
                "value": "00000000-0000-0000-0000-000000000000",
                "display": "cloud_controller.write",
                "type": "DIRECT"
              },
              {
                "value": "00000000-0000-0000-0000-000000000000",
                "display": "scim.me",
                "type": "DIRECT"
              },
              {
                "value": "00000000-0000-0000-0000-000000000000",
                "display": "cloud_controller.read",
                "type": "DIRECT"
              }
            ],
            "approvals": [

            ],
            "active": true,
            "schemas": [
              "urn:scim:schemas:core:1.0"
            ]
          }
EOF
          subject.email.should == user_email
          subject.given_name.should == nil
          subject.family_name.should == nil
          subject.full_name.should == nil
        end

      end
    end
  end
end