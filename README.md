# Without Test Helper

Multi-role controller tests and other helpful assertions

## Installation

Add without_test_helper to your Gemfile and run <pre>bundle install</pre>

## Additional Assertions

### assert_invalid_because_of

    test "make sure my_model validation fails on condition" do
      model = my_models(:one) # my_models(:one) must be valid
      assert_invalid_because_of model, :some_attribute, failing_value
    end

Assertion will fail if:

1. model fails sanity check (was not initially valid)
2. model.valid? is true after model.some_attribute = failing_value assignment

### assert_all_valid

Note: this requires then FactoryGirl gem

    test "make sure valid models created" do
      assert_all_valid :factory_name, :test_attribute, [value1, value2, value3...]
    end

Assertion will fail if your new object is invalid when test_attribute equals any of value1, value2, value3...

### assert_all_invalid

This is the reverse of assert_all_valid. It requires the FactoryGirl gem.

    test "make sure no valid models created" do
      assert_all_invalid :factory_name, :test_attribute, [value1, value2, value3...]
    end

Assertion will fail if your new object is valid when test_attribute equals any of value1, valu2, value3...

### assert_matching_arrays

Unsorted array comparison. Use this to ensure an array or set of objects includes exactly the elements in the array or set you provide.

    test "response has the right values" do
      assert_matching_arrays [value1, value2, value3], Class.where(attribute: value)
    end

Assertion will pass if all elements from one array and found in the other and the reverse, regardless of order. Will fail if one array contains an element not found in the other.

This is great for testing model scopes.

### assert_scopes_out

    test "modified value is excluded from scope" do
      model = relation.scope_name.find(id)
      assert_scopes_out relation.scope_name, model do
        model.update_attributes value: new_value
      end
    end

Assertion will fail if:

1. model fails sanity check (model was not initially found in relation.scope_name)
2. model is still found in relation.scope_name after block completes

### assert_destroyed

    # in a controller test
    test "model has been destroyed" do
      model = my_models(:one)
      assert_difference('MyModel.count', -1) do
        delete :destroy, id: model.to_param
      end
      assert_destroyed model
      assert_redirected_to my_models_path
    end

This is most commonly used to test that the correct model was destroyed in a controller's destroy action. One can never be too careful.

Assertion will fail if the model has not been destroyed.

### assert_attributes

    # in a controller test
    test "model attributes were assigned" do
      new_attributes = {attribute1: value1, attribute2: value2}
      model = my_model(:one)
      assert_difference('MyModel.count', 0) do
        put :update, id: model.to_param, my_model: new_attributes
      end
      assert_attributes(model, new_attributes)
    end

Typically used to test create and update controller actions to ensure attributes are set appropriately. Can merge in additional constant values if it is expected that some attributes are to be ignored, eg: assert_attributes model, new_attributes.merge(attribute2: old_value)

### assert_json

Confirm the format of a JSON response. Typically used to ensure API output includes the correct attributes.

    EXPECTED_JSON = [
      :id,
      :attribute1,
      :attribute2,
      {
        belongs_to: [
          :id,
          :attribute1
        ]
      },
      {
        has_many: [
          [
            :id,
            :attribute1
          ]
        ]
      }
    ]

    test "api returns correct json" do
      model = my_models(:one)
      get :show, id: model, format: :json
      assert_json response.body, EXPECTED_JSON
    end

Assertion will fail if the format of the JSON response is not as expected.

Defining expectations:

Pass an array of expected attributes. A symbol indicates an expected name. A hash indicates an object with its own attributes. An array indicates an array of whatever's inside. In the example above, the model is expected to return a model with five attributes: id, attribute1, attribute2, belongs_to and has_many. The belongs_to object has attributes of its own (id and attribute1). The has_many object is an array in which each element has two expected attributes (id and attribute1).

### Multi-role controller test helpers

For each HTTP verb of GET, POST, PUT, DELETE, create a test for each role you define.

    class UserTest < ActionController::TestCase
      include WithoutTestHelper

      def self.role_names
        [:user, sysadmin]
      end

      def login_as_user
        logout_user
        auto_login users(:user)
      end

      def login_as_sysadmin
        logout_user
        auto_login users(:sysadmin)
      end

      get_test "only sysadmin can see user index", :index do
        setup: -> do
          # setup code here
        end,
        params: -> do
          # optional params here -- needed for resource member tests eg :show, :update
        end,
        difference: {expr: 'User.count', difference: {user: 0, sysadmin: 0}},
        assertions: ->(role_name) do
          case role_name
          when :sysadmin then assert_response :success
          else assert_require_login
        end
      end
    end

Analogous post_test, put_test, delete_test exist as well.

Perform your assertions inside the assertions block. One test will be created for when no user is logged in and then one for each role. The setup code will be run then the controller request will be performed (inside an assert_difference block if you include difference values) and finally the assertions block will be executed. All blocks are executed by the test itself so you have access to all the usual assertions plus the @controller object.
