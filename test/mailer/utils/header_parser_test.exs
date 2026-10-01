defmodule Test.Rivet.Mailer.Utils.HeaderParserTest do
  use ExUnit.Case, async: true

  alias Rivet.Mailer.Utils.HeaderParser

  describe "extract/1" do
    test "parses basic headers" do
      message = """
      From: bob@example.com
      To: alice@example.com
      To: narf@example.com
      Some-Thing: with a long
        continuation value
      Subject: Hello world
      \tlonger tab

      This is the body.
      """

      assert {:ok,
              %HeaderParser{
                headers: %{
                  "from" => ["bob@example.com"],
                  "to" => ["alice@example.com", "narf@example.com"],
                  "some-thing" => ["with a long continuation value"],
                  "subject" => ["Hello world longer tab"]
                },
                body: "This is the body.\n"
              }} = HeaderParser.extract(message)
    end

    test "handles CRLF line endings and mbox envelope" do
      message =
        "From MAILER-DAEMON Sat Sep 20 06:12:34 2026\r\n" <>
          "From: bob@example.com\r\n" <>
          "Subject: Hello\r\n" <>
          "\r\n" <>
          "Body\r\nwith CRLF\r\n"

      assert {:ok,
              %HeaderParser{
                headers: %{
                  "from" => ["bob@example.com"],
                  "subject" => ["Hello"]
                },
                body: "Body\r\nwith CRLF\r\n"
              }} = HeaderParser.extract(message)
    end

    test "strips an mbox From_ separator" do
      message =
        "From MAILER-DAEMON Sat Sep 20 06:12:34 2026\n" <>
          "From: bob@example.com\n" <>
          "Subject: Hello\n" <>
          "\n" <>
          "body"

      assert {:ok,
              %HeaderParser{
                headers: %{
                  "from" => ["bob@example.com"],
                  "subject" => ["Hello"]
                },
                body: "body"
              }} = HeaderParser.extract(message)
    end

    test "returns an error for a continuation without a preceding header" do
      message = "  orphan continuation\nSubject: Hello\n\nbody"
      assert {:error, :unexpected_continuation} = HeaderParser.extract(message)
    end

    test "returns an error for a header without a colon" do
      message = "From: bob@example.com\nThis Is Not A Header\n\nbody"

      assert {:error, :malformed_header} = HeaderParser.extract(message)
    end

    test "returns an error for an empty header name" do
      message = ": some value\n\nbody"

      assert {:error, :empty_header_name} = HeaderParser.extract(message)
    end

    test "handles headers with no body separator at EOF and various forms of 'only'" do
      message = "From: bob@example.com\nSubject: Hello"

      assert {:ok, %HeaderParser{headers, body: ""}} = HeaderParser.extract(message, only: "from")
      assert %{"from" => ["bob@example.com"]} == headers

      assert {:ok, %HeaderParser{headers, body: ""}} =
               HeaderParser.extract(message, only: ["subject"])

      assert %{"subject" => ["Hello"]} == headers
    end

    test "handles an empty message" do
      assert {:ok, %HeaderParser{body: ""}} = HeaderParser.extract("")
    end

    test "handles a message with no headers" do
      assert {:ok, %HeaderParser{body: "body"}} = HeaderParser.extract("\nbody")
    end

    test "handles only" do
    end
  end

  describe "parse_params" do
    test "various" do
      assert {"text/plain", %{"nope" => ""}} = HeaderParser.parse_params("text/plain; nope")

      assert {"text/plain", %{"charset" => "utf-8"}} =
               HeaderParser.parse_params(~s(text/plain; charset="utf-8"))

      assert {"multipart/report",
              %{"boundary" => "----=_Part_507676", "report-type" => "delivery-status"}} =
               HeaderParser.parse_params(
                 ~s(multipart/report; boundary="----=_Part_507676"; report-type=delivery-status)
               )

      assert {"attachment", %{"filename" => "Quarterly; Report.pdf"}} =
               HeaderParser.parse_params(~s(attachment; filename="Quarterly; Report.pdf"))

      assert {"", %{}} = HeaderParser.parse_params("")
    end
  end
end
