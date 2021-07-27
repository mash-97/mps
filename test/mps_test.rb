# frozen_string_literal: true

require "test_helper"
include MPS::Loader
class MPSTest < Minitest::Test

  def setup()
    FileUtils.remove_dir(File.join(__dir__, 'test_field'), true) if Dir.exist?(File.join(__dir__, 'test_field'))
    # MPS setup
    @mps_dir = File.join(__dir__, 'test_field', '.mps')
    @mps_config_file_path = File.join(__dir__, 'test_field', '.mps_config.yml')
    @mps = MPS::Loader.load_mps(@mps_dir, @mps_config_file_path)

    if not Dir.exist?(@mps_dir) then
      FileUtils.mkdir_p(@mps_dir)
    end


    # user setup
    @n = "mash"
    @p = "1234"
    @user = MPS::User.new(@n, @p)

    @test_field = File.join(__dir__, "test_field")

    @ms = File.join(@test_field, "mps")
    @rp = File.join(@ms, "records.txt")

    # FileUtils.remove_dir(@ms, true) if Dir.exist?(@ms)
    # File.delete(@rp) if File.exist?(@rp)

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

  def test_user_new_note
    @user.newNote("test", "this is a test")
    notes = @user.getNotes(Time.now)
    puts("notes: #{notes}")
    assert(File.readlines(notes[0][:note_path].strip).join.chomp == "this is a test")
  end

  def test_mps()
    assert(@mps.mps_dir == @mps_dir)
    assert(@mps.users.length==0)
    assert(@mps.user==nil)

    assert_raises(MPS::MPS::UserNameNotExist) do @mps.logIn(@n, @p) end
    @mps.users << @user
    assert_raises(MPS::MPS::UserNameExist) do @mps.signUp(@n, @p) end
    MPS::Loader.store_mps(@mps, @mps_config_file_path)
  end
end
