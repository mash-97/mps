require('yaml')
require_relative('mps')
require_relative('constants')

module MPS
  module Loader
    def store_mps(mps_obj, file_path)
      File.open(file_path, "w+") do |file|
        file.puts(YAML.dump(mps_obj))
      end
    end

    def fetch_mps(file_path)
      obj = YAML.load_file(file_path)
      return obj.class == MPS ? obj : nil
    end

    def init_mps(mps_dir, mps_config_file_path)
      mps = MPS.new(mps_dir)
      store_mps(mps, mps_config_file_path)
      mps = fetch_mps(mps_config_file_path)
      raise("MPS can't be loaded into/from the file_path: #{mps_config_file_path}!") if not mps
      return mps
    end

    def load_mps(mps_dir, mps_config_file_path)
      if File.exist?(mps_config_file_path) then
        mps = fetch_mps(mps_config_file_path)
        if not mps then
          return init_mps(mps_dir, mps_config_file_path)
        end
      end
      return init_mps(mps_dir, mps_config_file_path)
    end
  end
end
