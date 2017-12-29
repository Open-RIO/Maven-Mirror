require 'open-uri'
require 'zip'
require 'digest'
require 'pathname'

URL = "http://www.ctr-electronics.com/downloads/lib/"
LIBREGEX = /href=\"(CTRE_Phoenix_FRCLibs_NON-WINDOWS(_[a-zA-Z0-9\.]+)?\.zip)\"/

GROUP = "openrio.mirror.third.ctre"
ARTIFACT_JAVA = "CTRE-phoenix-java"
ARTIFACT_NATIVE = "CTRE-phoenix-cpp"

puts "Fetching CTRE Phoenix Libs..."

open(URL, "rb") do |readfile|
    licenseroot = "#{LICENSES}/CTRE/Phoenix"
    FileUtils.mkdir_p licenseroot
    
    libs = readfile
                .read
                .scan(LIBREGEX)
                .reject { |x| x.last.nil? }
                .map(&:first)

    libs.each do |lib|
        liburl = "#{URL}#{lib}"
        libhash = Digest::MD5.hexdigest(liburl)
        tmpfile = "#{LOCALTMP}/#{libhash}.zip"
        tmpfolder = "#{LOCALTMP}/#{libhash}"
        puts "#{liburl} (#{libhash})"

        extractfile = "#{tmpfolder}/EXTRACT_SUCCESS_MARKER"
        FileUtils.rm_rf tmpfolder if File.exists?(tmpfolder) && !File.exists?(extractfile)
        FileUtils.mkdir_p tmpfolder

        publishfile = "#{tmpfolder}/PUBLISH_SUCCESS_MARKER"

        headersdir = "#{tmpfolder}/headers"
        cppdir = "#{tmpfolder}/cpp"
        javadir = "#{tmpfolder}/java"

        unless File.exists?(tmpfile)
            puts "-> Downloading..." 
            open(liburl, "rb") do |rf_zip|
                open(tmpfile, "wb") do |tmp|
                    tmp.write(rf_zip.read)
                end
            end
        else
            puts "-> Already Downloaded!"
        end

        unless File.exists?(extractfile)
            puts "-> Unzipping..."
            Zip::File.open(tmpfile) do |zip|
                version_notes = zip.select { |x| x.name.include? "VERSION_NOTES" }.first
                unless version_notes.nil?
                    vers_content = version_notes.get_input_stream.read
                    vers = (vers_content.match(/CTRE Phoenix Framework: ([0-9\.a-zA-Z_\-]*)/) || vers_content.match(/CTRE Toolsuite: ([0-9\.a-zA-Z_\-]*)/))[1]
                    puts "\t-> CTRE Version: #{vers}"
                    File.write("#{tmpfolder}/VERSION", vers)
                    
                    licensefolder = "#{licenseroot}/#{vers}"
                    FileUtils.mkdir_p licensefolder
                    zip.select { |x| x.name.include? "Software License" }.each do |license|
                        license.extract("#{licensefolder}/#{File.basename(license.name)}")
                    end

                    puts "\t->> Headers"
                    # [ entry, relative, outfile ]
                    headerout = Zip::extract_group zip.subfiles("cpp/include/"), headersdir
                    puts "\t->>> Compressing..."
                    Zip::File.open("#{headersdir}/CTRE_Phoenix-headers.zip", Zip::File::CREATE) do |outzip|
                        headerout.each do |ho|
                            outzip.add(ho[1], ho[2])
                        end
                    end

                    puts "\t->> C++"
                    # [ entry, relative, outfile ]
                    cppout = Zip::extract_group zip.subfiles("cpp/lib/"), cppdir
                    puts "\t->>> Compressing..."
                    Zip::File.open("#{cppdir}/CTRE_Phoenix-cpp.zip", Zip::File::CREATE) do |outzip|
                        cppout.each do |co|
                            outzip.add(co[1], co[2])
                        end
                    end

                    puts "\t->> Java"
                    Zip::extract_group zip.subfiles("java/docs/"), javadir
                    Zip::extract_group zip.subfiles("java/lib/"), javadir
                    puts "\t->>> Compressing..."
                    Zip::File.open("#{javadir}/CTRE_Phoenix-java-native.zip", Zip::File::CREATE) do |outzip|
                        outzip.add("libCTRE_PhoenixCCI.so", "#{javadir}/libCTRE_PhoenixCCI.so")
                    end
                end
            end
            File.write extractfile, "SUCCESS"
        else
            puts "-> Already extracted!"
        end

        unless File.exists?(publishfile)
            puts "-> Publishing..."

            puts "\t->> Headers"
            maven_publish(
                GROUP,
                ARTIFACT_NATIVE,
                File.read("#{tmpfolder}/VERSION"),
                "headers",
                "#{tmpfolder}/headers/CTRE_Phoenix-headers.zip"
            )

            puts "\t->> C++"
            maven_publish(
                GROUP,
                ARTIFACT_NATIVE,
                File.read("#{tmpfolder}/VERSION"),
                nil,
                "#{tmpfolder}/cpp/CTRE_Phoenix-cpp.zip"
            )

            puts "\t->> Java"
            deployJava = Proc.new do |classifier, file|
                maven_publish(
                    GROUP,
                    ARTIFACT_JAVA,
                    File.read("#{tmpfolder}/VERSION"),
                    classifier,
                    "#{tmpfolder}/java/#{file}"
                )
            end
            deployJava.call nil, "CTRE_Phoenix.jar"
            deployJava.call "sources", "CTRE_Phoenix-sources.jar"
            deployJava.call "javadoc", "CTRE_Phoenix-javadoc.jar"
            deployJava.call "native", "CTRE_Phoenix-java-native.zip"

            File.write publishfile, "SUCCESS"
        else
            puts "-> Already published!"
        end
    end
end