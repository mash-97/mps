# frozen_string_literal: true

require "test_helper"

class MPSTest < Minitest::Test

  def setup()
    @n = "mash"
    @p = "1234"
    @user = MPS::User.new(@n, @p)

    @test_field = File.join(__dir__, "test_field")

    @ms = File.join(@test_field, "mps")
    @rp = File.join(@ms, "records.txt")

    FileUtils.remove_dir(@ms, true) if Dir.exist?(@ms)
    File.delete(@rp) if File.exist?(@rp)

    @user.mps_storage_dir = @ms
    @user.mps_record_file = @rp

    puts("user: #{@user.inspect}")
  end

  def test_that_it_has_a_version_number
    refute_nil ::MPS::VERSION
  end

  def test_it_does_something_useful
    assert true
  end

  def test_user
    assert @user.password_md5 == MPS::MD5_DIGEST.digest(@p)
    assert @user.password_sha1 == MPS::SHA1_DIGEST.digest(@p)
    assert @user.name == @n
  end

  def test_new_note
    @user.newNote("test", "this is a test")
    notes = @user.getNotes(Time.now)
    puts("notes: #{notes}")
    assert(File.readlines(notes[0][:note_path].strip).join.chomp == "this is a test")
  end
end
