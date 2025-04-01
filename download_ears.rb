require 'open-uri'
require 'json'
require 'fileutils'

# Function to download a file
def download_file(url, filename)
  URI.open(url) do |data|
    File.open(filename, 'wb') { |file| file.write(data.read) }
  end
end

# Function to unzip a file
def unzip_file(zip_path, extract_to)
  FileUtils.mkdir_p(extract_to)
  system("unzip -o #{zip_path} -d #{extract_to}")
end

# Function to delete unused .wav files
def clean_wav_files(transcript_file)
  raise "transcripts not found!" unless File.exist?(transcript_file)
  
  data = JSON.parse(File.read(transcript_file))
  valid_files = data.keys.map { |key| "#{key}.wav" }

  pp valid_files
  
  Dir.glob("*.wav").each do |wav_file|
    File.delete(wav_file) unless valid_files.include?(wav_file)
  end
end

# Function to resample audio files that are not 44.1kHz Mono
def resample_audio(directory)
  Dir.glob("#{directory}/*.wav").each do |file|
    info = `ffprobe -v error -show_entries stream=channels,sample_rate -of default=noprint_wrappers=1 #{file}`
    sample_rate, channels = info.scan(/sample_rate=(\d+)|channels=(\d+)/).flatten.compact.map(&:to_i)
    
    if sample_rate != 44100 || channels != 1
      temp_file = "#{file}.temp.wav"
      system("ffmpeg -i #{file} -ar 44100 -ac 1 #{temp_file} -y")
      FileUtils.mv(temp_file, file)
    end
  end
end

# Main logic
speakers = ARGV[0]&.split(',')&.map(&:strip)&.map(&:to_i) || (1..107).to_a

speakers.each do |i|

  dir_name = "p%03d" % i

  if !File.exist?(dir_name)
    zip_file = "p%03d.zip" % i
    url = "https://github.com/facebookresearch/ears_dataset/releases/download/dataset/#{zip_file}"

    puts "Downloading #{zip_file}..."
    download_file(url, zip_file)
    
    puts "Extracting #{zip_file}..."
    unzip_file(zip_file, ".")
    File.delete(zip_file)
  end
  Dir.chdir(dir_name)
  
  puts "Cleaning up unused .wav files..."
  clean_wav_files("../transcripts.json")
  
  puts "Resampling audio files..."
  resample_audio(".")
  Dir.chdir("..")
end

puts "All downloads and processing completed!"