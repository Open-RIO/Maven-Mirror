require 'fileutils'
MAVENPATH = File.dirname(__FILE__) + '/m2'
LOCALTMP = File.dirname(__FILE__) + '/.tmp'
LICENSES = File.dirname(__FILE__) + '/licenses'

FileUtils.mkdir_p MAVENPATH
FileUtils.mkdir_p LOCALTMP
FileUtils.mkdir_p LICENSES

require 'zip'

module Zip
    class Entry
        def directory?
            ftype == :directory
        end

        def name_relative root
            Pathname.new(name).relative_path_from(Pathname.new(root)).to_s
        end
    end

    class File
        def subfiles root
            self
                .reject(&:directory?)
                .select { |e| e.name.include? root }
                .map { |h| [h, h.name_relative(root)] }
        end
    end

    def self.extract_group entries, dirroot
        entries.map do |e|
            outfile = "#{dirroot}/#{e.last}"
            FileUtils.mkdir_p(::File.dirname(outfile))
            e.first.extract(outfile)
            [e.first, e.last, outfile]
        end
    end
end

def maven_publish group, artifact, version, classifier, file
    cmd = [
        "mvn deploy:deploy-file",
        "-DgroupId='#{group}'",
        "-DartifactId='#{artifact}'",
        "-Dversion='#{version}'",
        "-Dfile='#{File.absolute_path(file)}'",
        "-Durl=file://#{File.absolute_path(MAVENPATH)}"
    ]
    cmd << "-Dclassifier=#{classifier}" unless classifier.nil?

    `#{cmd.join(" ")}`
end

require_relative 'ctre'