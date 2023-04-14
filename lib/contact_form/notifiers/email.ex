defmodule ContactForm.Notifiers.Email do
  import Bamboo.Email

  alias ContactForm.Mailer

  @subject "New contact message received"
  @us Application.compile_env(:contact_form, :deliver_emails_to)

  defdelegate deliver_now(email), to: Mailer

  def new_contact_message(data_json) do
    new_email()
    |> to(@us)
    |> subject(@subject)
    |> from(Map.fetch!(data_json, "email"))
    |> text_body(message_body(data_json))
  end

  def subject, do: @subject

  defp message_body(data_json) do
    name = Map.fetch!(data_json, "name")
    email = Map.fetch!(data_json, "email")
    message = Map.fetch!(data_json, "message")

    """
    From: #{name} <#{email}>

    **** Message ****
    #{message}
    """
  end
end
