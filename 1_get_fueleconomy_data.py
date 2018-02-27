#########################################
#Download and unzip US EPA Fuel economy data from fueleconomy.gov 
#########################################
import urllib.request
import urllib.parse
import io
import os
import zipfile
#import shutil
import datetime

#####################################
# downloadAndExtract - Downloads a ZIP archive and extracts it to the specified folder
#####################################
def downloadAndExtract(url, dest) : #Download and extract ZIP archive
    
    #Request the URL    
    response = urllib.request.urlopen(url)

    print("\tExtracting data from archive...")
    #Convert the response to a file-like object
    zipFile = io.BytesIO()
    zipFile.write(response.read())

    #Convert zipFile to a ZipFile object
    archive = zipfile.ZipFile(zipFile, 'r')
        
    #Get list of zipFile contents
    archiveNameList = archive.namelist()

    #Extract all of the files in archive
    for fileName in archiveNameList :
        print("\tArchive File:", fileName)
        archive.extract(fileName, path=dest)

    #Clean up
    archive.close()
    zipFile.close()
    response.close()
    print("\tExtraction complete")
    
########################################################
##MAIN PROGRAM
########################################################
#Write data into a subfolder of the source data folder stamped with today's date
dataFolder = os.path.join("..", "data", "source", datetime.date.today().strftime("%Y%m%d"))

print("Creating data folder")
#Create the source data subfolder if it doesn't exist
if not os.path.isdir(dataFolder) :
    os.makedirs(dataFolder)

print("Downloading Fuel Economy Data")
#Download fuel economy data
downloadAndExtract("https://www.fueleconomy.gov/feg/epadata/vehicles.csv.zip", dataFolder)

print("Downloading Emissions Data")
#Download Emissions data
downloadAndExtract("https://www.fueleconomy.gov/feg/epadata/emissions.csv.zip", dataFolder)
       



    


    
