require "test_helper"

class ProgramsControllerTest < ActionDispatch::IntegrationTest
  setup do
    post login_url
  end

  test "should get index" do
    get programs_url
    assert_response :success
  end
end
