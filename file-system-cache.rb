require 'fileutils'

class FileSystemCache

  def initialize(path)
    @path = path
  end

  def get(key)
    key = normalize_key(key)
    begin
      IO.binread(File.join(@path, key))
    rescue
      nil
    end
  end

  def put(key, value)
    FileUtils.mkdir_p(@path) if !File.exists?(@path)
    key = normalize_key(key)
    File.open(File.join(@path, key), "wb") do |file|
      file.write(value)
    end
  end

  protected

  def normalize_key(key)
    key.gsub(/\//, "_")
  end

end
