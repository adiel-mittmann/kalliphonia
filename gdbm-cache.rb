require 'gdbm'

class GdbmCache

  def initialize(path)
    @gdbm = GDBM.new(path)
  end

  def import_directory(base_path)
    Dir.foreach(base_path) do |file|
      full_path = File.join(base_path, file)
      if File.file?(full_path)
        content = ""
        File.open(full_path, "rb") do |io|
          content = io.read
        end
        @gdbm[file] = content
      end
    end
  end

  def get(key)
    @gdbm[key]
  end

  def put(key, value)
    @gdbm[key] = value
  end

  def delete(&block)
    keys = @gdbm.keys
    keys.each do |key|
      if yield(key)
        @gdbm.delete(key)
      end
    end
    @gdbm.sync
    @gdbm.reorganize
    @gdbm.sync
  end

end
