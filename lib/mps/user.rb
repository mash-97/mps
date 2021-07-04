require_relative("constants")

module MPS
  class User
    class NoteExist < StandardError
      def initailze
        super("Note already exist!")
      end
    end

    attr_accessor :name
    attr_accessor :password_md5
    attr_accessor :password_sha1
    attr_accessor :mps_storage_dir
    attr_accessor :mps_record_file
    attr_accessor :authorized

    def initialize(name, plain_password)
      @name = name
      @password_md5 = MD5_DIGEST.digest(plain_password)
      @password_sha1 = SHA1_DIGEST.digest(plain_password)
      @mps_storage_dir = User.get_default_user_mps_storage_dir(@name)
      @mps_record_file = User.get_user_mps_record_file(@mps_storage_dir)
      @authorized = false
    end

    def authorize(plain_password)
      @authorized = (@password_sha1==SHA1_DIGEST.digest(plain_password))
      return @authorized
    end

    def unauthorize()
      @authorized = false
    end

    def update_mps_storage_dir(mps_storage_dir)
      @mps_storage_dir = mps_storage_dir
      @mps_record_file = User.get_user_mps_record_file(@mps_storage_dir)
    end


    def newNote(note_name, content)
      current_time = TIME_CLIPPER.call(Time.now)
      folder_path = getFormattedFolderPath(current_time)

      FileUtils.mkdir_p(folder_path) if not Dir.exist?(folder_path)


      file_path = File.join(folder_path, note_name+"."+MPS_EXT)
      if not File.exist?(file_path) then
        File.open(file_path, "w"){|file|
          file.puts(content)
        }
        RECORD_LOGGER.call(@mps_record_file, current_time, note_name, file_path)
      else
        raise(NoteExist)
      end
    end

    def noteNameExist?(time, note_name)
      getNotes(time).each do |note|
        return true if note[:note_name]==note_name
      end
      return false
    end

    def getNotes(stime=Time.new(2000, 1, 1), etime=Time.new(stime.year, stime.month, stime.day+1))
      stime = TIME_CLIPPER.call(stime)
      etime = TIME_CLIPPER.call(etime)
      notes = []

      if File.exist?(@mps_record_file) then
        puts("reading record file...")
        File.readlines(@mps_record_file).each do |record|
          puts("record-> #{record}")
          record_data =  RECORD_DATA_CLIPPER.call(record.chomp)
          next if not record_data
          time = Time.new(record_data[:year], record_data[:month], record_data[:day])
          notes << record_data if time>=stime and time<etime
          puts("-------> after record: #{record}: #{notes.to_s}")
        end
      end

      return notes
    end

    private
    def getFormattedFolderPath(time)
      return File.join( @mps_storage_dir, [time.year, time.month, time.day].map(&:to_s).join("-"))
    end

    def self.get_default_user_mps_storage_dir(username)
      File.join(DEFAULT_MPS_DIR, username)
    end

    def self.get_user_mps_record_file(mps_storage_dir)
      File.join(mps_storage_dir, ".mps_records.txt")
    end
  end
end
