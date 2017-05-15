module Without
  module TestCase
    def assert_invalid_because_of(model, attribute, invalid_value = nil)
      puts model.errors unless model.valid?
      assert model.valid?, "sanity test failed: model #{model.class.name} invalid"
      attribute, invalid_value = [attribute], [invalid_value] unless attribute.respond_to? :each
      attribute.each_with_index do |attrib, i|
        valid_value = model.send("#{attrib.to_s}")
        model.send("#{attrib.to_s}=", invalid_value.try(:[], i))
        assert model.invalid?, "changing #{attrib} did not invalidate model #{model.class.name}"
        assert model.errors[attrib]
        model.send("#{attrib.to_s}=", valid_value)
      end
    end

    def assert_all_valid(factory, attribute, value_array)
      value_array.each {|value| assert FactoryGirl.build(factory, attribute => value).valid? }
    end

    def assert_all_invalid(factory, attribute, value_array)
      value_array.each {|value| assert_invalid_because_of(FactoryGirl.build(factory), attribute, value) }
    end

    def assert_matching_arrays(reference_array, test_array, failure_message = 'arrays did not match')
      assert_equal reference_array.length, test_array.length, failure_message
      reference_array.each_with_index {|o, i| assert_equal o, test_array[i], "#{failure_message}\n#{reference_array.inspect} expected but was\n#{test_array.inspect}\nmismatch at index #{i}" }
    end

    def assert_matching_arrays_unsorted(reference_array, test_array, failure_message = 'arrays did not match')
      assert_equal reference_array.length, test_array.length, failure_message
      reference_array.each {|o| assert test_array.include?(o), "#{failure_message}\n#{reference_array.inspect} expected but was\n#{test_array.inspect}\nmissing #{o.inspect}" }
    end

    def assert_scopes_out(scoped_class, obj)
      assert scoped_class.include?(obj), "sanity check: scoped_class doesn't include #{obj.inspect}"
      yield obj
      assert !scoped_class.reload.include?(obj), "scoped_class did not exclude #{obj.inspect}"
    end

    def assert_destroyed(objects)
      objects = [objects] unless objects.respond_to? :each
      objects.each {|object| assert_raises(ActiveRecord::RecordNotFound) { object.reload } }
    end

    def assert_attributes(expected_attributes, model)
      expected_attributes.each {|k, v| assert_equal v, model.send(k) }
    end

    def assert_json(required_attributes, obj)
      obj = JSON.parse obj if obj.is_a? String
      required_attributes.each do |attrib|
        case
#{required_attributes.to_sentence}"
          when attrib.is_a?(Hash) then
            attrib.each do |key, value|
              (key.is_a?(Array) ? obj.map{|el| el[key.first.to_s]} : [obj[key.to_s]]).each do |o|
                assert_json(value, o)
              end
            end
          when attrib.is_a?(Array) then
            obj.each {|o| assert_json(attrib, o) }
          else assert obj && obj.keys.include?(attrib.to_s), "expected element #{attrib} not found in #{obj.inspect}"
        end
      end
      if obj.is_a?(Hash)
        obj.keys.each do |attrib|
          found = false
          required_attributes.each do |el|
            found = (el.is_a?(Hash) ? el.keys.first : el) == attrib.to_sym
            break if found
          end
          assert found, "unexpected element #{attrib} found in #{obj.inspect}, expecting #{required_attributes}"
        end
      end
    end
  end

  module Controller
    module ClassMethods
      def request_all(test_name, verb, action, params = {})
        procs = block_given? ? yield : nil
        (show_request_all_docs; assert false) unless procs
        ([nil] + role_names).each do |login_method|
          test "#{test_name} #{login_method}" do
            if setup_block = procs[:setup]
              instance_exec login_method, &setup_block
            else
              send("login_as_#{login_method}") if login_method
            end
            params = if params_block = procs[:params]
              instance_exec &params_block
            end || {}
            if procs[:difference]
              assert_difference(procs[:difference][:expr], procs[:difference][:difference].try(:[], login_method || :none) || 0, login_method || :none) do
                execute_request login_method, verb, action, params
              end
            else
              execute_request login_method, verb, action, params
            end
            assertions = if assertions_block = procs[:assertions]
              instance_exec login_method, &assertions_block
            end
            unless assertions
              if login_method
                assert_response 401, "assert_response(401) not satisfied in default #{login_method} handler"
              else
                assert_require_login('require_login expected when not logged in')
              end
            end
          end
        end
      end

      [:get, :post, :put, :delete].each do |verb|
        define_method "#{verb}_test" do |test_name, action, &block|
          request_all test_name, verb, action, &block
        end
      end
    end

    def self.included(klass)
      klass.extend ClassMethods
    end

    def assert_require_login(message = nil)
      message ? assert_redirected_to(login_path, message) : assert_redirected_to(login_path)
    end

    def post_all(action, params = {}, &block)
      request_all :post, action, params, &block
    end

    def put_all(action, params = {}, &block)
      request_all :put, action, params, &block
    end

    def delete_all(action, params = {}, &block)
      request_all :delete, action, params, &block
    end

    def execute_request(login_method, verb, action, params)
      begin
        if params[:format].try(:to_sym) == :js
          xhr verb, action, params
        else
          send verb, action, params
        end
      rescue StandardError => e
        puts "Exception encountered during request for #{login_method || 'no role'}: #{e.message}"
        puts e.backtrace
        raise e
      end
    end

    def show_request_all_docs
      puts "usage: (get/post/put/delete)_all :method_name, parameters = {} do ..."
      puts
      puts "your block must return a hash"
      puts
      puts "return options:"
      puts
      puts "  show_role_names: show role names in test log output"
      puts "  setup: procedure to run before each role. The proc is passed the current role name. NB: you must take care of logging in if you use this. EG:"
      puts "    setup: Proc.new do |role_name|"
      puts "      # do setup here"
      puts "      send(\"login_as_\#{role_name}\") if role_name"
      puts "    end"
      puts "  difference: hash indicating expression and differences by role. Default difference is 0. Use :none as role name for when user not logged in. EG:"
      puts "    difference: {expr: 'User.count', difference: {none: 0, admin: 1}}"
      puts "  assertions: procedure to run after logging in and performing the request. The proc is passed the role name. EG:"
      puts "    assertions: Proc.new do |role_name|"
      puts "      case role_name"
      puts "      when :admin then"
      puts "        assert_response :success"
      puts "      end"
      puts "    end"
      puts "    # your block must return true or equivalent or the x_all method will attempt the fallback assertion (usually assert_response 401)"
    end
  end
end
