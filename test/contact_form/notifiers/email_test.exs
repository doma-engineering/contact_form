defmodule ContactForm.Notifiers.EmailTest do
  use ExUnit.Case, async: true
  use Bamboo.Test

  alias ContactForm.Notifiers.Email

  @expected_receiver Application.compile_env(:contact_form, :deliver_emails_to)
  @subject Email.subject()

  describe "new_contact_message/1" do
    setup do
      data_json = %{
        "name" => "John Doe",
        "email" => "john@doe.com",
        "message" => "Hello, world!"
      }

      valid_email = Email.new_contact_message(data_json)

      {:ok, data_json: data_json, email: valid_email}
    end

    test "actually delivers an email", %{email: email} do
      assert {:ok, _} = Email.deliver(email)

      assert_delivered_email(email)
    end

    test "with valid data_json structure - adds correct fields", %{data_json: valid_data_json, email: email} do
      expected_from = valid_data_json["email"]

      assert email.to == @expected_receiver
      assert email.subject == @subject
      assert ^expected_from = email.from
    end

    test "user-filled data always visible in the email body", %{data_json: valid_data_json, email: email} do
      assert email.text_body =~ valid_data_json["email"]
      assert email.text_body =~ valid_data_json["name"]
      assert email.text_body =~ valid_data_json["message"]
    end

    test "raise when any data_json field is missing", %{data_json: valid_data_json} do
      for {key, _} <- valid_data_json do
        invalid_data_json = Map.delete(valid_data_json, key)

        assert_raise KeyError, fn ->
          Email.new_contact_message(invalid_data_json)
        end
      end
    end
  end
end
