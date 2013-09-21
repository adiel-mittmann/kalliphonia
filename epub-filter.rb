require 'html-filter.rb'

require 'zip'

class EpubFilter

  def initialize(converter)
    @html_filter = HtmlFilter.new(converter)
  end

  def run(epub_in_path, epub_out_path)
    zip_in = Zip::File.open(epub_in_path, nil)

    buffer = Zip::OutputStream.write_buffer do |out|
      zip_in.entries.each do |entry|
        out.put_next_entry(entry.name)
        if !entry.directory?
         contents = entry.get_input_stream.read()
          if entry.name =~ /\.html$/
            contents = @html_filter.run(contents.force_encoding('utf-8'))
          end
          out.write contents
        end
      end
    end

    File.open(epub_out_path, "wb") do |out|
      out.write(buffer.string)
    end
  end

end
