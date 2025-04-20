require "test_helper"

class TextMappingsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get text_mappings_index_url
    assert_response :success
  end

  test "should get new" do
    get text_mappings_new_url
    assert_response :success
  end

  test "should get create" do
    get text_mappings_create_url
    assert_response :success
  end

  test "should get edit" do
    get text_mappings_edit_url
    assert_response :success
  end

  test "should get update" do
    get text_mappings_update_url
    assert_response :success
  end

  test "should get destroy" do
    get text_mappings_destroy_url
    assert_response :success
  end

  test "should get import" do
    get text_mappings_import_url
    assert_response :success
  end
end
