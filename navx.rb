require 'open-uri'
require 'zip'
require 'digest'
require 'pathname'

NAVX_URL = "https://www.kauailabs.com/public_files/navx-mxp/navx-mxp-libs.zip"

NAVX_GROUP = "openrio.mirror.third.kauailabs"
NAVX_ARTIFACT_JAVA = "navx-java"
NAVX_ARTIFACT_NATIVE = "navx-cpp"

puts "Fetching NavX Libs..."
tmpfile = "#{LOCALTMP}/navx.zip"

puts "-> Downloading..." 
open(NAVX_URL, "rb") do |rf_zip|
    open(tmpfile, "wb") do |tmp|
        tmp.write(rf_zip.read)
    end
end

libhash = Digest::MD5.file(tmpfile) 
tmpfolder = "#{LOCALTMP}/#{libhash}"
FileUtils.mkdir_p tmpfolder
FileUtils.mv(tmpfile, "#{LOCALTMP}/#{libhash}.zip")
tmpfile = "#{LOCALTMP}/#{libhash}.zip"

extractfile = "#{tmpfolder}/EXTRACT_SUCCESS_MARKER"
FileUtils.rm_rf tmpfolder if File.exists?(tmpfolder) && !File.exists?(extractfile)
FileUtils.mkdir_p tmpfolder

publishfile = "#{tmpfolder}/PUBLISH_SUCCESS_MARKER"

headersdir = "#{tmpfolder}/headers"
cppdir = "#{tmpfolder}/cpp"
javadir = "#{tmpfolder}/java"

unless File.exists?(extractfile)
    puts "-> Unzipping..."
    Zip::File.open(tmpfile) do |zip|
        version_notes = zip.select { |x| x.name.include? "version.txt" }.first
        unless version_notes.nil?
            vers = version_notes.get_input_stream.read
            puts "\t-> NavX Version: #{vers}"
            File.write("#{tmpfolder}/VERSION", vers.strip)

            # TODO: NavX doesn't have a license in the dist
            # TODO: NavX also doesn't have javadocs

            puts "\t->> Headers"
            # [ entry, relative, outfile ]
            headerout = Zip::extract_group zip.subfiles("roborio/cpp/include/"), headersdir
            puts "\t->>> Compressing..."
            Zip::File.open("#{headersdir}/NavX-headers.zip", Zip::File::CREATE) do |outzip|
                headerout.each do |ho|
                    outzip.add(ho[1], ho[2])
                end
            end

            puts "\t->> C++"
            # [ entry, relative, outfile ]
            cppout = Zip::extract_group zip.subfiles("roborio/cpp/lib/"), cppdir
            puts "\t->>> Compressing..."
            Zip::File.open("#{cppdir}/NavX-cpp.zip", Zip::File::CREATE) do |outzip|
                cppout.each do |co|
                    outzip.add(co[1], co[2])
                end
            end

            puts "\t->> Java"
            Zip::extract_group zip.subfiles("roborio/java/lib/"), javadir
            srcout = Zip::extract_group zip.subfiles("roborio/java/src/"), javadir
            puts "\t->>> Compressing..."
            Zip::File.open("#{javadir}/NavX-java-sources.jar", Zip::File::CREATE) do |outzip|
                srcout.each do |co|
                    outzip.add(co[1], co[2])
                end
            end
        end
    end
    File.write extractfile, "SUCCESS"
end

unless File.exists?(publishfile)
    puts "-> Publishing..."
    puts "\t->> Headers"
    maven_publish(
        NAVX_GROUP,
        NAVX_ARTIFACT_NATIVE,
        File.read("#{tmpfolder}/VERSION"),
        "headers",
        "#{tmpfolder}/headers/NavX-headers.zip"
    )

    puts "\t->> C++"
    maven_publish(
        NAVX_GROUP,
        NAVX_ARTIFACT_NATIVE,
        File.read("#{tmpfolder}/VERSION"),
        nil,
        "#{tmpfolder}/cpp/NavX-cpp.zip"
    )

    puts "\t->> Java"
    maven_publish(
        NAVX_GROUP,
        NAVX_ARTIFACT_JAVA,
        File.read("#{tmpfolder}/VERSION"),
        nil,
        "#{tmpfolder}/java/navx_frc.jar"
    )

    maven_publish(
        NAVX_GROUP,
        NAVX_ARTIFACT_JAVA,
        File.read("#{tmpfolder}/VERSION"),
        "sources",
        "#{tmpfolder}/java/NavX-java-sources.jar"
    )
end