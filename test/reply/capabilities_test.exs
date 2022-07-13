defmodule ReplyCapabilityTest do
  use ExUnit.Case, async: true
  alias Jeff.Reply.Capabilities

  test "no capabilites" do
    assert Capabilities.decode(<<>>) == %{functions: []}
  end

  test "decode multiple capabilities" do
    caps = Capabilities.decode(<<8, 1, 1, 9, 1, 1>>)
    assert caps.functions == [8, 9]
    assert map_size(caps) == 3
  end

  describe "capability functions" do
    test "Contact Status Monitoring" do
      assert %{compliance: :unsupervised, inputs: 1} =
               Capabilities.decode(<<1, 1, 1>>).contact_status_monitoring

      assert %{compliance: :unsupervised_configurable, inputs: 1} =
               Capabilities.decode(<<1, 2, 1>>).contact_status_monitoring

      assert %{compliance: :supervised, inputs: 1} =
               Capabilities.decode(<<1, 3, 1>>).contact_status_monitoring

      assert %{compliance: :supervised_eol, inputs: 1} =
               Capabilities.decode(<<1, 4, 1>>).contact_status_monitoring
    end

    test "Output Control" do
      assert %{compliance: :direct, outputs: 1} = Capabilities.decode(<<2, 1, 1>>).output_control

      assert %{compliance: :direct_configurable, outputs: 1} =
               Capabilities.decode(<<2, 2, 1>>).output_control

      assert %{compliance: :timed, outputs: 1} = Capabilities.decode(<<2, 3, 1>>).output_control

      assert %{compliance: :timed_configurable, outputs: 1} =
               Capabilities.decode(<<2, 4, 1>>).output_control
    end

    test "Card Data Format" do
      assert Capabilities.decode(<<3, 1, 0>>).card_data_format == :bits
      assert Capabilities.decode(<<3, 2, 0>>).card_data_format == :bcd
      assert Capabilities.decode(<<3, 3, 0>>).card_data_format == :bits_or_bcd
    end

    test "Reader LED Control" do
      assert %{compliance: :on_off, leds_per_reader: 1} =
               Capabilities.decode(<<4, 1, 1>>).reader_led_control

      assert %{compliance: :timed, leds_per_reader: 1} =
               Capabilities.decode(<<4, 2, 1>>).reader_led_control

      assert %{compliance: :timed_bi_color, leds_per_reader: 1} =
               Capabilities.decode(<<4, 3, 1>>).reader_led_control

      assert %{compliance: :timed_tri_color, leds_per_reader: 1} =
               Capabilities.decode(<<4, 4, 1>>).reader_led_control
    end

    test "Reader Audible Control" do
      assert Capabilities.decode(<<5, 1, 0>>).reader_audible_control == :on_off
      assert Capabilities.decode(<<5, 2, 0>>).reader_audible_control == :timed
    end

    test "Reader Text Control" do
      assert %{displays_per_reader: 1, rows: 0, characters: 0, supported?: false} =
               Capabilities.decode(<<6, 0, 1>>).reader_text_control

      assert %{displays_per_reader: 1, rows: 1, characters: 16, supported?: true} =
               Capabilities.decode(<<6, 1, 1>>).reader_text_control

      assert %{displays_per_reader: 1, rows: 2, characters: 16, supported?: true} =
               Capabilities.decode(<<6, 2, 1>>).reader_text_control

      assert %{displays_per_reader: 1, rows: 4, characters: 16, supported?: true} =
               Capabilities.decode(<<6, 3, 1>>).reader_text_control

      assert %{displays_per_reader: 1, rows: 0, characters: 0, supported?: false} =
               Capabilities.decode(<<6, 5, 1>>).reader_text_control
    end

    test "Time Keeping" do
      assert Capabilities.decode(<<7, 0, 0>>).time_keeping == false
      assert Capabilities.decode(<<7, 1, 0>>).time_keeping == true
    end

    test "Check Character Support" do
      assert Capabilities.decode(<<8, 0, 0>>).check_character_support == :checksum
      assert Capabilities.decode(<<8, 1, 0>>).check_character_support == :crc
    end

    test "Communication Security" do
      assert %{aes128?: true, default_aes128_key?: false} =
               Capabilities.decode(<<9, 1, 0>>).communication_security

      assert %{aes128?: true, default_aes128_key?: true} =
               Capabilities.decode(<<9, 1, 1>>).communication_security

      assert %{aes128?: false, default_aes128_key?: false} =
               Capabilities.decode(<<9, 0, 0>>).communication_security
    end

    test "Receive BufferSize" do
      assert Capabilities.decode(<<10, 0, 2>>).receive_buffer_size == 512
      assert Capabilities.decode(<<10, 0, 1>>).receive_buffer_size == 256
    end

    test "Largest Combined Message Size" do
      assert Capabilities.decode(<<11, 0, 2>>).largest_combined_message_size == 512
      assert Capabilities.decode(<<11, 0, 1>>).largest_combined_message_size == 256
    end

    test "Smart Card Support" do
      assert %{extended_packet?: true, transparent_reader?: true} =
               Capabilities.decode(<<12, 3, 0>>).smart_card_support

      assert %{extended_packet?: true, transparent_reader?: false} =
               Capabilities.decode(<<12, 2, 0>>).smart_card_support

      assert %{extended_packet?: false, transparent_reader?: true} =
               Capabilities.decode(<<12, 1, 0>>).smart_card_support

      assert %{extended_packet?: false, transparent_reader?: false} =
               Capabilities.decode(<<12, 0, 0>>).smart_card_support
    end

    test "Readers" do
      for i <- 0..255 do
        assert Capabilities.decode(<<13, 0, i>>).readers == i
      end
    end

    test "Biometrics" do
      assert Capabilities.decode(<<14, 0, 0>>).biometrics == :none
      assert Capabilities.decode(<<14, 1, 0>>).biometrics == :fingerprint_template_1
      assert Capabilities.decode(<<14, 2, 0>>).biometrics == :fingerprint_template_2
      assert Capabilities.decode(<<14, 3, 0>>).biometrics == :iris_template_1
    end

    test "Secure Pin Entry Support" do
      assert Capabilities.decode(<<15, 0, 0>>).secure_pin_entry_support == false
      assert Capabilities.decode(<<15, 1, 0>>).secure_pin_entry_support == true
    end

    test "OSDP Version" do
      assert Capabilities.decode(<<16, 0, 0>>).osdp_version == :unspecified
      assert Capabilities.decode(<<16, 1, 0>>).osdp_version == :"IEC 60839-11-5"
      assert Capabilities.decode(<<16, 2, 0>>).osdp_version == :"SIA OSDP 2.2"
    end

    test "Reserved and Private OSDP Versions are still reported" do
      for i <- 0x3..0xFF do
        assert Capabilities.decode(<<16, i, 0>>).osdp_version == i
      end
    end
  end
end
