Maven Mirror
===
This is the repository that puts third-party vendor libraries for FRC into a maven repository that can be understood by build systems.

This repo currently services the following vendor libraries:
- CrossTheRoadElectronics
    - CTRE Phoenix Framework (since v5.0.4.0)
- KauaiLabs
    - NavX driver software (since v3.0.342)

# Usage
Clone the repository and run the following (assumes ruby and rubygems are installed):   
`bundle install`

You also have to install maven command line tools. On debian, this is  
`apt-get install maven`

Now, run `ruby main.rb`. The first run will be the longest, but subsequent runs will not redownload/extract/publish cached libraries.

# Using the maven
You can connect to the maven repository through the following URL:
`https://raw.githubusercontent.com/Open-RIO/Maven-Mirror/master/m2`

# Licensing
The code for this repository (that is, the source files written and maintained by OpenRIO) is licensed under the MIT License.

The code for the individual mirrors we host are licensed to their respective vendors. Licenses can be found under the `licenses/` directory.
