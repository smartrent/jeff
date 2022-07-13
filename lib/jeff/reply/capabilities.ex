defmodule Jeff.Reply.Capabilities do
  @moduledoc """
  Peripheral Device Capabilities Report

  OSDP v2.2 Specification Reference: 7.5

  See OSDP v2.2 Specification Annex B for capability function definitions
  """

  @type contact_status_monitoring :: %{
          inputs: non_neg_integer(),
          compliance: :unsupervised | :unsupervised_configurable | :supervised | :supervised_eol
        }
  @type output_control :: %{
          outputs: non_neg_integer(),
          compliance: :direct | :direct_configurable | :timed | :timed_configurable
        }
  @type card_data_format :: :bits | :bcd | :bits_or_bcd
  @type reader_led_control :: %{
          leds_per_reader: non_neg_integer(),
          compliance: :on_off | :timed | :timed_bi_color | :timed_tri_color
        }
  @type reader_audible_control :: :on_off | :timed
  @type reader_text_control :: %{
          displays_per_reader: non_neg_integer(),
          supported?: boolean(),
          rows: non_neg_integer(),
          characters: non_neg_integer()
        }
  @type check_character_support :: :crc | :checksum
  @type communication_security :: %{aes128?: boolean(), default_aes128_key?: boolean()}
  @type smart_card_support :: %{extended_packet?: boolean(), transparent_reader?: boolean()}
  @type biometrics :: :none | :fingerprint_template_1 | :fingerprint_template_2 | :iris_template_1
  @type osdp_version :: :unspecified | :"IEC 60839-11-5" | :"SIA OSDP 2.2" | byte()

  @type t :: %{
          :functions => [pos_integer()],
          optional(:contact_status_monitoring) => contact_status_monitoring(),
          optional(:output_control) => output_control(),
          optional(:card_data_format) => card_data_format(),
          optional(:reader_led_control) => reader_led_control(),
          optional(:reader_audible_control) => reader_audible_control(),
          optional(:reader_text_control) => reader_text_control(),
          optional(:time_keeping) => boolean(),
          optional(:check_character_support) => check_character_support(),
          optional(:communication_security) => communication_security(),
          optional(:receive_buffer_size) => non_neg_integer(),
          optional(:largest_combined_message_size) => non_neg_integer(),
          optional(:smart_card_support) => smart_card_support(),
          optional(:readers) => non_neg_integer(),
          optional(:biometrics) => biometrics(),
          optional(:secure_pin_entry_support) => boolean(),
          optional(:osdp_version) => osdp_version()
        }

  @spec decode(binary()) :: t()
  def decode(data), do: decode(data, [], [])

  defp decode(<<>>, caps, funcs) do
    Map.new(caps)
    |> Map.put(:functions, Enum.reverse(funcs))
  end

  defp decode(<<1, comp_num, num, rest::binary>>, caps, funcs) do
    comp =
      case comp_num do
        1 -> :unsupervised
        2 -> :unsupervised_configurable
        3 -> :supervised
        4 -> :supervised_eol
      end

    conf = %{inputs: num, compliance: comp}
    decode(rest, [{:contact_status_monitoring, conf} | caps], [1 | funcs])
  end

  defp decode(<<2, comp_num, num, rest::binary>>, caps, funcs) do
    comp =
      case comp_num do
        1 -> :direct
        2 -> :direct_configurable
        3 -> :timed
        4 -> :timed_configurable
      end

    conf = %{outputs: num, compliance: comp}
    decode(rest, [{:output_control, conf} | caps], [2 | funcs])
  end

  defp decode(<<3, comp_num, _num, rest::binary>>, caps, funcs) do
    comp =
      case comp_num do
        1 -> :bits
        2 -> :bcd
        3 -> :bits_or_bcd
      end

    decode(rest, [{:card_data_format, comp} | caps], [3 | funcs])
  end

  defp decode(<<4, comp_num, num, rest::binary>>, caps, funcs) do
    comp =
      case comp_num do
        1 -> :on_off
        2 -> :timed
        3 -> :timed_bi_color
        4 -> :timed_tri_color
      end

    conf = %{leds_per_reader: num, compliance: comp}
    decode(rest, [{:reader_led_control, conf} | caps], [4 | funcs])
  end

  defp decode(<<5, comp_num, _num, rest::binary>>, caps, funcs) do
    comp =
      case comp_num do
        1 -> :on_off
        2 -> :timed
      end

    decode(rest, [{:reader_audible_control, comp} | caps], [5 | funcs])
  end

  defp decode(<<6, comp_num, num, rest::binary>>, caps, funcs) do
    {rows, chars} =
      case comp_num do
        0 -> {0, 0}
        1 -> {1, 16}
        2 -> {2, 16}
        3 -> {4, 16}
        _ -> {0, 0}
      end

    conf = %{displays_per_reader: num, rows: rows, characters: chars, supported?: rows > 0}
    decode(rest, [{:reader_text_control, conf} | caps], [6 | funcs])
  end

  defp decode(<<7, comp_num, _num, rest::binary>>, caps, funcs) do
    # OSDP v2.2 Specification Reference: Annex B.8 stats this is technically
    # deprecated, but we'll attempt to support it for now incase the message
    # still comes up
    decode(rest, [{:time_keeping, comp_num > 0} | caps], [7 | funcs])
  end

  defp decode(<<8, comp_num, _num, rest::binary>>, caps, funcs) do
    comp = if comp_num > 0, do: :crc, else: :checksum
    decode(rest, [{:check_character_support, comp} | caps], [8 | funcs])
  end

  defp decode(<<9, <<_::7, aes::1>>, <<_::7, key::1>>, rest::binary>>, caps, funcs) do
    conf = %{aes128?: aes == 1, default_aes128_key?: key == 1}
    decode(rest, [{:communication_security, conf} | caps], [9 | funcs])
  end

  defp decode(<<10, buff::16-little, rest::binary>>, caps, funcs) do
    decode(rest, [{:receive_buffer_size, buff} | caps], [10 | funcs])
  end

  defp decode(<<11, buff::16-little, rest::binary>>, caps, funcs) do
    decode(rest, [{:largest_combined_message_size, buff} | caps], [11 | funcs])
  end

  defp decode(<<12, _::6, ext::1, trans::1, _num, rest::binary>>, caps, funcs) do
    conf = %{extended_packet?: ext == 1, transparent_reader?: trans == 1}
    decode(rest, [{:smart_card_support, conf} | caps], [12 | funcs])
  end

  defp decode(<<13, _compliance, num, rest::binary>>, caps, funcs) do
    decode(rest, [{:readers, num} | caps], [13 | funcs])
  end

  defp decode(<<14, comp_num, _num, rest::binary>>, caps, funcs) do
    comp =
      case comp_num do
        0 -> :none
        1 -> :fingerprint_template_1
        2 -> :fingerprint_template_2
        3 -> :iris_template_1
      end

    decode(rest, [{:biometrics, comp} | caps], [14 | funcs])
  end

  defp decode(<<15, comp_num, _num, rest::binary>>, caps, funcs) do
    decode(rest, [{:secure_pin_entry_support, comp_num > 0} | caps], [15 | funcs])
  end

  defp decode(<<16, comp_num, _num, rest::binary>>, caps, funcs) do
    ver =
      case comp_num do
        0 -> :unspecified
        1 -> :"IEC 60839-11-5"
        2 -> :"SIA OSDP 2.2"
        # 3..0x7F is reserved for future use
        # 0x80..0xFF is reserved for private use
        # If we see them, we'll still report the digit
        c -> c
      end

    decode(rest, [{:osdp_version, ver} | caps], [16 | funcs])
  end
end
