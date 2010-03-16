require 'abstract_unit'

module AbstractController
  module Testing
  
    # Test basic dispatching.
    # ====
    # * Call process
    # * Test that the response_body is set correctly
    class SimpleController < AbstractController::Base
    end
    
    class Me < SimpleController
      def index
        self.response_body = "Hello world"
        "Something else"
      end      
    end
    
    class TestBasic < ActiveSupport::TestCase
      test "dispatching works" do
        controller = Me.new
        controller.process(:index)
        assert_equal "Hello world", controller.response_body
      end
    end
    
    # Test Render mixin
    # ====
    class RenderingController < AbstractController::Base
      include ::AbstractController::Rendering

      def _prefix() end

      def render(options = {})
        if options.is_a?(String)
          options = {:_template_name => options}
        end
        
        options[:_prefix] = _prefix
        super
      end

      append_view_path File.expand_path(File.join(File.dirname(__FILE__), "views"))
    end
    
    class Me2 < RenderingController
      def index
        render "index.erb"
      end
      
      def action_with_ivars
        @my_ivar = "Hello"
        render "action_with_ivars.erb"
      end
      
      def naked_render
        render
      end

      def rendering_to_body
        self.response_body = render_to_body :template => "naked_render.erb"
      end

      def rendering_to_string
        self.response_body = render_to_string :template => "naked_render.erb"
      end
    end

    class TestRenderingController < ActiveSupport::TestCase
      def setup
        @controller = Me2.new
      end

      test "rendering templates works" do
        @controller.process(:index)
        assert_equal "Hello from index.erb", @controller.response_body
      end
      
      test "rendering passes ivars to the view" do
        @controller.process(:action_with_ivars)
        assert_equal "Hello from index_with_ivars.erb", @controller.response_body
      end
      
      test "rendering with no template name" do
        @controller.process(:naked_render)
        assert_equal "Hello from naked_render.erb", @controller.response_body
      end

      test "rendering to a rack body" do
        @controller.process(:rendering_to_body)
        assert_equal "Hello from naked_render.erb", @controller.response_body
      end

      test "rendering to a string" do
        @controller.process(:rendering_to_string)
        assert_equal "Hello from naked_render.erb", @controller.response_body
      end
    end
    
    # Test rendering with prefixes
    # ====
    # * self._prefix is used when defined
    class PrefixedViews < RenderingController
      private
      def self.prefix
        name.underscore
      end
      
      def _prefix
        self.class.prefix
      end
    end
    
    class Me3 < PrefixedViews
      def index
        render
      end
      
      def formatted
        self.formats = [:html]
        render
      end
    end
    
    class TestPrefixedViews < ActiveSupport::TestCase
      def setup
        @controller = Me3.new
      end

      test "templates are located inside their 'prefix' folder" do
        @controller.process(:index)
        assert_equal "Hello from me3/index.erb", @controller.response_body
      end

      test "templates included their format" do
        @controller.process(:formatted)
        assert_equal "Hello from me3/formatted.html.erb", @controller.response_body
      end
    end
    
    # Test rendering with layouts
    # ====
    # self._layout is used when defined
    class WithLayouts < PrefixedViews
      include Layouts
      
      private
      def self.layout(formats)
        begin
          find_template(name.underscore, {:formats => formats}, :_prefix => "layouts")
        rescue ActionView::MissingTemplate
          begin
            find_template("application", {:formats => formats}, :_prefix => "layouts")
          rescue ActionView::MissingTemplate
          end
        end
      end

      def render_to_body(options = {})
        options[:_layout] = options[:layout] || _default_layout({})
        super
      end  
    end
    
    class Me4 < WithLayouts
      def index
        render
      end
    end
    
    class Me5 < WithLayouts
      def index
        render
      end
    end
    
    class TestLayouts < ActiveSupport::TestCase
      test "layouts are included" do
        controller = Me4.new
        result = controller.process(:index)
        assert_equal "Me4 Enter : Hello from me4/index.erb : Exit", controller.response_body
      end
    end
    
    # respond_to_action?(action_name)
    # ====
    # * A method can be used as an action only if this method
    #   returns true when passed the method name as an argument
    # * Defaults to true in AbstractController
    class DefaultRespondToActionController < AbstractController::Base
      def index() self.response_body = "success" end
    end
    
    class ActionMissingRespondToActionController < AbstractController::Base
      # No actions
    private
      def action_missing(action_name)
        self.response_body = "success"
      end
    end
    
    class RespondToActionController < AbstractController::Base;
      def index() self.response_body = "success" end
        
      def fail()  self.response_body = "fail"    end
        
    private

      def method_for_action(action_name)
        action_name.to_s != "fail" && action_name
      end
    end
    
    class TestRespondToAction < ActiveSupport::TestCase

      def assert_dispatch(klass, body = "success", action = :index)
        controller = klass.new
        controller.process(action)
        assert_equal body, controller.response_body
      end
      
      test "an arbitrary method is available as an action by default" do
        assert_dispatch DefaultRespondToActionController, "success", :index
      end
      
      test "raises ActionNotFound when method does not exist and action_missing is not defined" do
        assert_raise(ActionNotFound) { DefaultRespondToActionController.new.process(:fail) }
      end
      
      test "dispatches to action_missing when method does not exist and action_missing is defined" do
        assert_dispatch ActionMissingRespondToActionController, "success", :ohai
      end
      
      test "a method is available as an action if respond_to_action? returns true" do
        assert_dispatch RespondToActionController, "success", :index
      end
      
      test "raises ActionNotFound if method is defined but respond_to_action? returns false" do
        assert_raise(ActionNotFound) { RespondToActionController.new.process(:fail) }
      end
    end
    
  end
end
