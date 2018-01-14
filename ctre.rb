require 'open-uri'
require 'zip'
require 'digest'
require 'pathname'

CTRE_URL = "http://www.ctr-electronics.com/downloads/lib/"
CTRE_LIBREGEX = /href=\"(CTRE(_Phoenix)?_FRCLibs_NON-WINDOWS(_[a-zA-Z0-9\._]+)?\.zip)\"/

CTRE_GROUP = "openrio.mirror.third.ctre"
CTRE_TOOLSUITE_ARTIFACT_JAVA = "CTRE-toolsuite-java"
CTRE_TOOLSUITE_ARTIFACT_NATIVE = "CTRE-toolsuite-cpp"
CTRE_PHOENIX_ARTIFACT_JAVA = "CTRE-phoenix-java"
CTRE_PHOENIX_ARTIFACT_NATIVE = "CTRE-phoenix-cpp"

puts "Fetching CTRE Phoenix Libs..."

open(CTRE_URL, "rb") do |readfile|
    licenseroot = "#{LICENSES}/CTRE/Phoenix"
    FileUtils.mkdir_p licenseroot
    
    libs = readfile
                .read
                .scan(CTRE_LIBREGEX)
                .reject { |x| x.last.nil? }

    libs.each do |lib|
        liburl = "#{CTRE_URL}#{lib.first}"
        isPhoenix = !lib[1].nil? && lib[1] == '_Phoenix'
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
                rootprefix = zip.select { |x| x.name.start_with?("FRC/") }.size > 0 ? "FRC/" : ""

                version_notes = zip.select { |x| x.name.include? "VERSION_NOTES" }.first
                unless version_notes.nil?
                    vers_content = version_notes.get_input_stream.read
                    vers = (vers_content.match(/CTRE Phoenix Framework: ([0-9\.a-zA-Z_\-]*)/) || vers_content.match(/CTRE Toolsuite: ([0-9\.a-zA-Z_\-]*)/))[1]
                    puts "\t-> CTRE Version: #{vers}"
                    File.write("#{tmpfolder}/VERSION", vers)

                    licensefolder = "#{licenseroot}/#{vers}"
                    FileUtils.mkdir_p licensefolder
                    zip.select { |x| x.name.include? "Software License" }.each do |license|
                        lfile = "#{licensefolder}/#{File.basename(license.name)}"
                        license.extract(lfile) unless File.exists?(lfile)
                    end

                    puts "\t->> Headers"
                    # [ entry, relative, outfile ]
                    headerout = Zip::extract_group zip.subfiles("#{rootprefix}cpp/include/"), headersdir
                    puts "\t->>> Compressing..."
                    Zip::File.open("#{headersdir}/CTRE-headers.zip", Zip::File::CREATE) do |outzip|
                        headerout.each do |ho|
                            outzip.add(ho[1], ho[2])
                        end
                    end

                    puts "\t->> C++"
                    # [ entry, relative, outfile ]
                    cppout = Zip::extract_group zip.subfiles("#{rootprefix}cpp/lib/"), cppdir
                    puts "\t->>> Compressing..."
                    Zip::File.open("#{cppdir}/CTRE-cpp.zip", Zip::File::CREATE) do |outzip|
                        cppout.each do |co|
                            outzip.add(co[1], co[2])
                        end
                    end

                    puts "\t->> Java"
                    Zip::extract_group zip.subfiles("#{rootprefix}java/docs/"), javadir
                    Zip::extract_group zip.subfiles("#{rootprefix}java/lib/"), javadir
                    puts "\t->>> Compressing..."
                    Zip::File.open("#{javadir}/CTRE-java-native.zip", Zip::File::CREATE) do |outzip|
                        if isPhoenix
                            outzip.add("libCTRE_PhoenixCCI.so", "#{javadir}/libCTRE_PhoenixCCI.so")
                        else
                            outzip.add("libCTRLibDriver.so", "#{javadir}/libCTRLibDriver.so")
                        end
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
                CTRE_GROUP,
                isPhoenix ? CTRE_PHOENIX_ARTIFACT_NATIVE : CTRE_TOOLSUITE_ARTIFACT_NATIVE,
                File.read("#{tmpfolder}/VERSION"),
                "headers",
                "#{tmpfolder}/headers/CTRE-headers.zip"
            )

            puts "\t->> C++"
            maven_publish(
                CTRE_GROUP,
                isPhoenix ? CTRE_PHOENIX_ARTIFACT_NATIVE : CTRE_TOOLSUITE_ARTIFACT_NATIVE,
                File.read("#{tmpfolder}/VERSION"),
                nil,
                "#{tmpfolder}/cpp/CTRE-cpp.zip"
            )

            puts "\t->> Java"
            deployJava = Proc.new do |classifier, file|
                maven_publish(
                    CTRE_GROUP,
                    isPhoenix ? CTRE_PHOENIX_ARTIFACT_JAVA : CTRE_TOOLSUITE_ARTIFACT_JAVA,
                    File.read("#{tmpfolder}/VERSION"),
                    classifier,
                    "#{tmpfolder}/java/#{file}"
                )
            end
            if isPhoenix
                deployJava.call nil, "CTRE_Phoenix.jar"
                deployJava.call "sources", "CTRE_Phoenix-sources.jar"
                deployJava.call "javadoc", "CTRE_Phoenix-javadoc.jar"
            else
                deployJava.call nil, "CTRLib.jar"
                # Toolsuite doesn't have a sources jar
                deployJava.call "javadoc", "CTRLib-javadoc.jar"
            end
            deployJava.call "native", "CTRE-java-native.zip"

            File.write publishfile, "SUCCESS"
        else
            puts "-> Already published!"
        end
    end
end